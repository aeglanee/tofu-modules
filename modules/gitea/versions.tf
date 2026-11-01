terraform {
  required_version = ">= 1.11"

  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "~> 0.8"
    }
    # Mints the bot tokens through Gitea's API; see README for the provider settings it needs.
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
