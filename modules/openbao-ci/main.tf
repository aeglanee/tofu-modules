# CI → OpenBao: a Gitea Actions job with `permissions: id-token: write` trades its OIDC ID token
# (audience "openbao") for a short-lived OpenBao token with one role's policy. Nothing is stored in
# Gitea. Only jobs of var.repository on var.ref may log in, and only while that ref is protected:
# Gitea computes ref_protected from the branch protection rules when it signs the token.

locals {
  issuer = "${trimsuffix(var.gitea_url, "/")}/api/actions/oidc"

  # One policy per role, named after it.
  policies = {
    # Every job: the Tofu state token and the two sync tokens. Read-only.
    ci = <<-EOT
      path "${var.kv_mount}/data/providers/github-sync"      { capabilities = ["read"] }
      path "${var.kv_mount}/data/providers/gitea-sync"       { capabilities = ["read"] }
      path "${var.kv_mount}/data/providers/gitea-tofu-state" { capabilities = ["read"] }
    EOT

    # The gitea module: reads the admin login; writes the bot and state tokens. delete: removing a
    # bot destroys its record.
    terraform-gitea = <<-EOT
      path "${var.kv_mount}/data/providers/gitea"       { capabilities = ["read"] }
      path "${var.kv_mount}/metadata/providers/gitea"   { capabilities = ["read"] }
      path "${var.kv_mount}/data/providers/gitea-*"     { capabilities = ["create", "update", "read", "delete"] }
      path "${var.kv_mount}/metadata/providers/gitea-*" { capabilities = ["read", "delete"] }
    EOT

    # The harbor module: reads the Harbor admin login.
    terraform-harbor = <<-EOT
      path "${var.kv_mount}/data/providers/harbor"     { capabilities = ["read"] }
      path "${var.kv_mount}/metadata/providers/harbor" { capabilities = ["read"] }
    EOT

    # The garage module: reads the admin token; writes each consumer's S3 key to
    # providers/garage-<consumer>. delete: removing a consumer destroys its key record.
    terraform-garage = <<-EOT
      path "${var.kv_mount}/data/providers/garage"       { capabilities = ["read"] }
      path "${var.kv_mount}/metadata/providers/garage"   { capabilities = ["read"] }
      path "${var.kv_mount}/data/providers/garage-*"     { capabilities = ["create", "update", "read", "delete"] }
      path "${var.kv_mount}/metadata/providers/garage-*" { capabilities = ["read", "delete"] }
    EOT

    # The argocd module: writes the minted account tokens to apps/<account>/argocd.
    terraform-argocd = <<-EOT
      path "${var.kv_mount}/data/apps/+/argocd"     { capabilities = ["create", "update", "read", "delete"] }
      path "${var.kv_mount}/metadata/apps/+/argocd" { capabilities = ["read", "delete"] }
    EOT
  }
}

resource "vault_jwt_auth_backend" "gitea" {
  path               = "gitea-jwt"
  description        = "Gitea Actions OIDC ID tokens (${local.issuer})"
  oidc_discovery_url = local.issuer
  bound_issuer       = local.issuer
}

resource "vault_policy" "role" {
  for_each = local.policies
  name     = each.key
  policy   = each.value
}

resource "vault_jwt_auth_backend_role" "role" {
  for_each = local.policies

  backend         = vault_jwt_auth_backend.gitea.path
  role_name       = each.key
  role_type       = "jwt"
  user_claim      = "sub" # repo:<owner>@<owner id>/<repo>@<repo id>:ref:<ref>
  bound_audiences = ["openbao"]
  # Gitea sends every claim as a string, ref_protected too ("true"/"false").
  bound_claims = {
    repository    = var.repository
    ref           = var.ref
    ref_protected = "true"
  }
  token_policies = [vault_policy.role[each.key].name]
  # Not renewable past 30 minutes either: a leaked token dies with the job.
  token_ttl     = 1800
  token_max_ttl = 1800
}
