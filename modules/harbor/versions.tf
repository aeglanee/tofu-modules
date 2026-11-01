terraform {
  required_version = ">= 1.11"

  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.10"
    }
  }
}
