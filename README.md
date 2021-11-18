![Shellcheck](https://github.com/sebastiaankok/dl-github-binary/workflows/Shellcheck/badge.svg)

# dl-github-binary
Script for downloading amd64 binary releases from Github that works with and without a personal github access token.
Maintainers have different approaches to releasing binaries. 
Sometimes binaries are not uploaded as assets in Github, but are available on external URL's hidden in release notes.
There are some other solutions out there, but I needed something that could handle the extraction of archives, as well as handling some of the edge cases.

### Usage

```
Usage: ./dl-github-binary.sh --repo helm/helm --filter v2 --save-as helm2 --dir /usr/local/bin

This script searches the Github api for the latest release tag or release tags based on a filter.
amd64 binaries are fetched from the uploaded assets, or custom download urls are searched in release notes.

 Options:
  -r, --repo          Github repository to download from <owner>/<project> e.g. helm/helm
  -f, --filter        Filter tag version. For version v2.0.1+ , use -f v2
  -s, --save-as       Save binary file with specific name
  -d, --dir           Write binary to specific directory
  -o, --overwrite     Overwrite existing binaries
  -c, --custom-url    Use custom url for download. Replaces GITHUB_TAG with tag found on Github
  -u, --user          Use Github user and token to prevent rate limiting
  -t, --token         Github personal token
  -v, --verbose       Print debug log
  -h, --help          Prints options
```

### Rate limiting

If the script throws a ratelimiting error, set the --user and --token arguments.
* [Github create access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)

### Example script usage

```bash
#!/bin/bash

default_dir="$(echo ~/bin)"

## repo, version, save-as, dir (optional)
packages="
helm/helm,v2,helm2
helm/helm,v3,helm
wercker/stern,1,stern
derailed/k9s,v0,k9s
linkerd/linkerd,1,linkerd
linkerd/linkerd2,stable-2,linkerd2
argoproj/argo-cd,v2,argocd
FairwindsOps/pluto,v5,pluto
vmware-tanzu/velero,v1,velero
terraform-docs/terraform-docs,v0,terraform-docs
"

while IFS=, read -r repo version save_as dir; do
  if [ -z "$repo" ]; then continue ; fi
  if [ -z "$dir" ]; then dir="$default_dir" ; fi

  dl-github-binary --repo $repo --filter $version --save-as $save_as --dir "$dir"

done <<< $packages
```

### Custom URLs (experimental)

It's possible to set an custom URL for downloading a release. Github is searched for the latest, or a specific tag.
This tag is then replaced with string GITHUB_TAG in the custom URL.

* Example: https://releases.hashicorp.com/vault/GITHUB_TAG/vault_GITHUB_TAG_linux_amd64.zip"

`./dl-github-binary.sh --dir /home/dev/bin --repo hashicorp/vault --filter v1 --save-as vault --custom-url "https://releases.hashicorp.com/vault/GITHUB_TAG/vault_GITHUB_TAG_linux_amd64.zip"`

