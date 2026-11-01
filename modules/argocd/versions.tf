terraform {
  required_version = ">= 1.11"

  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.17"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
