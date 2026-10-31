terraform {
  # Write-only attributes (vault_kv_secret_v2.data_json_wo) need OpenTofu 1.11.
  required_version = ">= 1.11"

  required_providers {
    # The provider's version follows Authentik's; keep it on the server's minor.
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
