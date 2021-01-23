#!/bin/bash

#set -x

debug=0
allow_overwrite=0

github_user=""
github_token=""

tmp_dir="$(mktemp -d /tmp/github-downloader.XXXXXXX)"
tmp_dl_dir="$tmp_dir/dl"
request_log="$tmp_dir/request-header.log"

dl_dest_dir="/usr/local/bin"

if [ ! -w "$dl_dest_dir" ]; then
  echo "$dl_dest_dir not writable"
  exit 1
fi

if [ -z "$(which jq)" ] ; then
  echo "Missing jq binary"
  exit 1
fi

logMsg () {
  local status="$1"
  local msg="$2"

  if [ "$debug" = "1" ] && [ "$status" = "debug" ] ; then
    echo -e "[$status] - $msg\n" 
  fi

  if [ "$status" = "info" ]; then
    echo -e "[$status] - $msg" 
  fi 

  if [ "$status" = "warning" ]; then
    echo -e "[$status] - $msg\n" 
  fi 
  
  if [ "$status" = "error" ]; then
    echo -e "[$status] - $msg\n\nexiting ..." 
    exit 1
  fi 
}

checkRequest () {
if ! grep -q 'HTTP/2 200' "$request_log" ; then
  # -- check rate limiting
  if grep -q 'x-ratelimit-remaining: 0' "$request_log" ; then
    logMsg "error" "Ratelimiting blocked request"
    exit 1
  else
    logMsg "error" "Http status not 200\nRequest headers:\n$(cat "$request_log")" 
    exit 1
  fi 
fi 
}

_curlGithubApi () {
  local github_api="https://api.github.com/repos"
  local url="$1"

  if [ -n "$github_user" ] && [ -n "$github_token" ] ; then
    local auth="-u $github_user:$github_token"
    # -> Requests are slower with auth token
    #local auth="-H 'Authorization: token $github_token'"
  fi
 
  curl "$auth" -sL "$github_api/$url" -D "$request_log"
}

# -- Snippet from stackoverflow, author unknown
extract () {
  if [ -f "$1" ] ; then
    case $1 in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       rar x "$1"       ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           return 1         ;;
    esac
  else
    logMsg "error" "$1 is not a valid file"
  fi
}

getGithubRelease() {
  # Get tag from release URL
  local repo="$1"
  local desired_tag="$2"
  local desired_name="$3"
  local custom_url="$4"

  local dl_url result_releases result_tag result_assets result_body custom_latest_tag 

  local filter_tag="rc\|edge"
  local filter_archives="\.tar\.gz$\|\.tar$\|\.bz2$\|\.tgz$\|\.zip$\|\.gz$\|\.rar$\|\.tar$\|\.tgz$"
  local filter_sig="\.asc$\|.sha256"

  local allow_overwrite_msg="set allow_overwrite=1 to enable overwriting existing binary files"

  logMsg "debug" "repo:\t\t$repo\ntag_filter:\t$desired_tag\ndesired_name:\t$desired_name"

  # -- Fetch tags
  result_releases="$(_curlGithubApi "$repo/releases")"
  checkRequest
  available_tags="$(jq -r '.[].tag_name' <<< "$result_releases")"
  logMsg "debug" "avaiable tags: \n$available_tags"

  # -- Filter tags
  filtered_tags="$(grep "^$desired_tag" <<< "$available_tags" | grep -v "$filter_tag" )"
  logMsg "debug" "filtered tags: \n$filtered_tags"
  clean_latest_tag="$( head -n 1 <<< "$filtered_tags" )"

  if [ -z "$clean_latest_tag" ]; then
   logMsg "warning" "$repo - no tags selected, skipping release"
  else
    logMsg "info" "$repo tag: $clean_latest_tag"

    # -- Custom url is used for dl
    # -- TODO: Refactor
    if [ -n "$custom_url" ] ; then
      logMsg "debug" "custom URL is used for dl: $custom_url"
      dl_url="$( sed "s/GITHUB_TAG/$clean_latest_tag/g" <<< "$custom_url")"
      if ! curl -I -f -s "$dl_url" > /dev/null ; then
        logMsg "debug" "$dl_url not status 200, try removing letter 'v' from tag"
        custom_latest_tag="$( tr -d 'v' <<< $clean_latest_tag )"
        dl_url="$( sed "s/GITHUB_TAG/$custom_latest_tag/g" <<< "$4")"
        if ! curl -I -f -s "$dl_url" > /dev/null ; then
          logMsg "debug" "$dl_url not status 200, unset dl_url" 
          unset dl_url
        fi
      fi
    fi
    # -- Fetch assets
    result_tag="$(_curlGithubApi "$repo/releases/tags/$clean_latest_tag")"
    checkRequest

    # -- Scan assets for download_urls
    result_assets="$(jq -r '.assets[].browser_download_url' <<< "$result_tag" )"
    logMsg "debug" "avaiable assets: \n$result_assets"
    # -- Select correct assets url
    # 1) linux_amd64.archive
    [ -z "$dl_url" ] && dl_url="$(echo "$result_assets" | grep -i "$(uname)" | grep -i "amd64\|x86_64" | grep -i "$filter_archives")"
    # 2) tag.archive
    [ -z "$dl_url" ] && dl_url="$(echo "$result_assets" | grep -i "$clean_latest_tag" | grep -i "$filter_archives")"
    # 3) amd64.archive
    [ -z "$dl_url" ] && dl_url="$(echo "$result_assets" | grep -i "amd64\|x86_64" | grep -i "$filter_archives")"
    # 4) linux.archive
    [ -z "$dl_url" ] && dl_url="$(echo "$result_assets" | grep -i "$(uname)" | grep -i "$filter_archives")"
    # 5) linux_amd6
    [ -z "$dl_url" ] && dl_url="$(echo "$result_assets" | grep -i "$(uname)" | grep -i "amd64\|x86_64" | grep -v "$filter_sig")"

    # -- Is the download url hidden in body :) ? 
    if [ -z "$dl_url" ] ; then
      logMsg "debug" "Scanning body for download urls"
      result_body="$(jq -r '.body' <<< "$result_tag")"
      [ -z "$dl_url" ] && dl_url="$(echo "$result_body" | grep -oi "(https://.*$clean_latest_tag.*$(uname).*amd64.*tar.gz)" | tr -d '()')"
      [ -z "$dl_url" ] && dl_url="$(echo "$result_body" | grep -oi "(https://.*$clean_latest_tag.*$(uname).*x86_64.*tar.gz)"| tr -d '()')"
      [ -z "$dl_url" ] && logMsg "warning" "$repo - Download url not found"
    fi
    

    if [ -n "$dl_url" ] ; then
      logMsg "info" "downloading: $repo - $dl_url"

      if [ ! -d "$tmp_dl_dir" ] ; then mkdir "$tmp_dl_dir" ; fi
      if [ ! -d "$dl_dest_dir" ] ; then logMsg "error" "destination dir $dl_dest_dir doesn't exist" ; fi
   
      cd "$tmp_dl_dir" || logMsg "error" "Couldn't cd to $tmp_dl_dir" 
      curl -sLO "$dl_url" 
      dl_file="$(find "$tmp_dl_dir" -type f)"

      # -- If downloaded file is archive, try to move one more binaries to $dl_dest_dir 
      if extract "$dl_file" ; then  
        rm -f "$dl_file"
        binary_files=$(find "$tmp_dl_dir" -type f -exec grep -IL . "{}" \;)
	      for i in $binary_files ; do
          # -- Check if dl binary matches with the desired name
          if grep -qi "$desired_name" <<< "$(basename "$i")" || \
            grep -qi "$(basename "$i")" <<< "$desired_name" ; then
            if [ ! -f "$dl_dest_dir/$desired_name" ] || [ "$allow_overwrite" = "1" ] ; then
              mv "$i" "$dl_dest_dir/$desired_name" && chmod +x "$dl_dest_dir/$desired_name"
              logMsg "info" "Installed $dl_dest_dir/$desired_name"
            else
              logMsg "error" "File exists : mv $i to $dl_dest_dir/$desired_name\n$allow_overwrite_msg"
            fi
          # -- Move other binaries 
          else
            if [ ! -f "$dl_dest_dir/$(basename "$i")" ] || [ "$allow_overwrite" -eq 1 ] ; then
              mv "$i" "$dl_dest_dir" && chmod +x "$dl_dest_dir/$(basename "$i")"
              logMsg "info" "Installed $dl_dest_dir/$(basename "$i")"
            else
              logMsg "error" "File exists : mv $i to $dl_dest_dir\n$allow_overwrite_msg"
            fi
          fi
        done
      else
        # -- If file is not an archive, move binary to $dl_dest_dir
        if grep -IL "." "$dl_file" > /dev/null ; then
          if [ ! -f "$dl_dest_dir/$desired_name" ] || [ "$allow_overwrite" = "1" ] ; then
            mv "$dl_file" "$dl_dest_dir/$desired_name"  && chmod +x "$dl_dest_dir/$desired_name" 
            logMsg "info" "Installed $dl_dest_dir/$desired_name"
          else
            logMsg "error" "File exists : mv $dl_file to $dl_dest_dir/$desired_name\n$allow_overwrite_msg"
          fi
        fi
      fi

      # -- clean up
      logMsg "debug" "running cleanup on dir $tmp_dl_dir" 
      rm -rf "${tmp_dl_dir:?}"
    else
      logMsg "warning" "Couldn't find DL url for $repo"
    fi

  fi

}

