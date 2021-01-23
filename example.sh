#!/bin/bash

source dl-github-binary.sh

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

