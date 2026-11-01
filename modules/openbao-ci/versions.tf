terraform {
  required_version = ">= 1.11"

  required_providers {
    # OpenBao speaks Vault's API.
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
