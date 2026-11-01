terraform {
  required_version = ">= 1.11"

  required_providers {
    # The calling root must use the same source address, or it configures a different provider.
    garage = {
      source  = "jkossis/garage"
      version = "~> 1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}
