# Offline: OpenBao is mocked, so this checks what the module would ask for, not that OpenBao accepts
# it (or that it can reach the issuer).
mock_provider "vault" {}

variables {
  gitea_url  = "https://gitea.example.com/"
  repository = "example/homelab"
}

run "backend_and_roles" {
  command = apply

  assert {
    condition     = vault_jwt_auth_backend.gitea.path == "gitea-jwt" && output.login_path == "auth/gitea-jwt/login"
    error_message = "the backend is at auth/gitea-jwt"
  }
  assert {
    condition     = vault_jwt_auth_backend.gitea.oidc_discovery_url == "https://gitea.example.com/api/actions/oidc" && vault_jwt_auth_backend.gitea.bound_issuer == output.issuer
    error_message = "the issuer is <ROOT_URL>/api/actions/oidc, without a doubled slash"
  }
  assert {
    condition     = output.roles == tolist(["ci", "terraform-argocd", "terraform-garage", "terraform-gitea", "terraform-harbor"])
    error_message = "one role per policy"
  }
  assert {
    condition = alltrue([for r in vault_jwt_auth_backend_role.role : r.bound_claims == tomap({
      repository = "example/homelab", ref = "refs/heads/main", ref_protected = "true"
    }) && r.bound_audiences == toset(["openbao"]) && r.token_ttl == 1800 && r.token_max_ttl == 1800])
    error_message = "every role is bound to the repository's protected main, audience openbao, 30-minute tokens"
  }
  assert {
    condition     = vault_jwt_auth_backend_role.role["terraform-gitea"].token_policies == toset(["terraform-gitea"])
    error_message = "a role gets the policy of its name"
  }
  assert {
    condition     = strcontains(vault_policy.role["ci"].policy, "\"kv/data/providers/gitea-tofu-state\"") && !strcontains(vault_policy.role["ci"].policy, "update")
    error_message = "ci reads the state token and nothing more"
  }
  assert {
    condition     = strcontains(vault_policy.role["terraform-gitea"].policy, "path \"kv/data/providers/gitea-*\"     { capabilities = [\"create\", \"update\", \"read\", \"delete\"] }")
    error_message = "terraform-gitea writes providers/gitea-*"
  }
}

run "other_ref_and_mount" {
  command = plan
  variables {
    ref      = "refs/heads/release"
    kv_mount = "secret"
  }
  assert {
    condition     = vault_jwt_auth_backend_role.role["ci"].bound_claims["ref"] == "refs/heads/release"
    error_message = "ref is configurable"
  }
  assert {
    condition     = strcontains(vault_policy.role["terraform-harbor"].policy, "\"secret/data/providers/harbor\"")
    error_message = "the policies follow kv_mount"
  }
}

run "repository_needs_owner" {
  command = plan
  variables {
    repository = "homelab"
  }
  expect_failures = [var.repository]
}

run "repository_needs_a_name" {
  command = plan
  variables {
    repository = "example/"
  }
  expect_failures = [var.repository]
}
