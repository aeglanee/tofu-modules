# Offline: Argo CD and OpenBao are mocked, so this checks what the module would ask for, not that
# they accept it.
mock_provider "argocd" {
  mock_resource "argocd_account_token" {
    defaults = { jwt = "jwt" }
  }
}
mock_provider "vault" {}

variables {
  readonly_accounts = ["homepage", "radar"]
}

run "tokens" {
  command = apply

  assert {
    condition     = argocd_account_token.readonly["radar"].account == "radar" && argocd_account_token.readonly["radar"].renew_after == "8760h"
    error_message = "a yearly-renewed token per account"
  }
  assert {
    condition     = output.kv_paths == { homepage = "apps/homepage/argocd", radar = "apps/radar/argocd" }
    error_message = "each token goes to apps/<account>/argocd"
  }
  assert {
    condition     = jsondecode(vault_kv_secret_v2.token["homepage"].data_json) == { token = "jwt" } && vault_kv_secret_v2.token["homepage"].mount == "kv"
    error_message = "OpenBao gets {token} on the kv mount"
  }
}
