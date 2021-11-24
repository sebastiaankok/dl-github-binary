#!/bin/bash

default_dir="$(readlink -f ~/bin)"

## repo, version, save-as, dir
packages="
helm/helm,v2,helm2
helm/helm,v3,helm
wercker/stern,1,stern
derailed/k9s,v0,k9s
restic/restic,v0,restic
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

  dl-github-binary --repo "$repo" --filter "$version" --save-as "$save_as" --dir "$dir"

done <<< "$packages"
