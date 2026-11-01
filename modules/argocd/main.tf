# API tokens for read-only local accounts that in-cluster consumers use against the Argo CD API.
#
# Rotation: once a token is older than renew_after, the next apply replaces it, and replacing
# deletes the old token in Argo CD (the provider's delete revokes it). A consumer that read its
# token at start fails until it picks up the new one from OpenBao and restarts.
resource "argocd_account_token" "readonly" {
  for_each = var.readonly_accounts

  account     = each.key
  renew_after = "8760h" # 1y; long-lived by design (no expires_in)
}

# Same path shape as the OIDC client secrets (apps/<app>/oidc).
resource "vault_kv_secret_v2" "token" {
  for_each = var.readonly_accounts

  mount = var.kv_mount
  name  = "apps/${each.key}/argocd"
  data_json = jsonencode({
    token = argocd_account_token.readonly[each.key].jwt
  })
}
