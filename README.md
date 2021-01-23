# dl-github-binary
Script for downloading binary releases from Github that works with/without personal github access token.
Can be used to download new releases, or update existing binaries.
There are some other solutions but none that fully suited my use case.

Works with edge cases like: 
* Download url is hidden in release body instead of assets
* Custom download url 

### Usage

Script can be sourced and used to download releases

See: `example.sh`
```
#!/bin/bash 
source dl-github-binary

#getGithubRelease <repo> <filter_tag> <binary_name> <custom_url>
getGithubRelease "helm/helm" "v2" "helm2"
getGithubRelease "helm/helm" "v3" "helm"
getGithubRelease "wercker/stern" "1" "stern"
getGithubRelease "derailed/k9s" "v0" "k9s"
getGithubRelease "linkerd/linkerd" "1" "linkerd"
getGithubRelease "linkerd/linkerd2" "stable-2" "linkerd2"
getGithubRelease "argoproj/argo-cd" "v1.8" "argocd"
getGithubRelease "FairwindsOps/pluto" "v4" "pluto"
getGithubRelease "vmware-tanzu/velero" "v1" "velero"
getGithubRelease "terraform-docs/terraform-docs" "v0" "terraform-docs"
getGithubRelease "hashicorp/terraform" "v0.13" "terraform" "https://releases.hashicorp.com/terraform/GITHUB_TAG/terraform_GITHUB_TAG_linux_amd64.zip"
getGithubRelease "hashicorp/vault" "v1" "vault" "https://releases.hashicorp.com/vault/GITHUB_TAG/vault_GITHUB_TAG_linux_amd64.zip"
```
