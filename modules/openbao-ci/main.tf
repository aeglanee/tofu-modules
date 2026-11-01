# CI → OpenBao: a Gitea Actions job with `permissions: id-token: write` trades its OIDC ID token
# (audience var.audience) for a short-lived OpenBao token with one role's policy. Nothing is stored
# in Gitea. Only jobs of var.repository on var.ref may log in, and only while that ref is protected:
# Gitea computes ref_protected from the branch protection rules when it signs the token.

locals {
  issuer = "${trimsuffix(var.gitea_url, "/")}/api/actions/oidc"

  # One policy per role, named after it: a path rule per entry, under var.kv_mount.
  policies = { for role, paths in var.policies : role => join("", [
    for path, caps in paths : "path ${jsonencode("${var.kv_mount}/${path}")} { capabilities = ${jsonencode(caps)} }\n"
  ]) }
}

resource "vault_jwt_auth_backend" "gitea" {
  path               = var.auth_path
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
  bound_audiences = [var.audience]
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
