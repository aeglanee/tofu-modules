# Offline: every provider is mocked, so this checks what the module would ask Gitea and OpenBao
# for, not that they accept it. The restapi provider's schema is still the real one: run with
# API_DATA_IS_SENSITIVE=true (the dev shell sets it), or the module's own guard fails every run.
mock_provider "gitea" {
  mock_data "gitea_user" {
    defaults = { username = "admin" }
  }
  mock_resource "gitea_token" {
    defaults = { token = "state-token" }
  }
}
mock_provider "restapi" {
  # What Gitea answers to POST /api/v1/users/<bot>/tokens.
  mock_resource "restapi_object" {
    defaults = { id = "1", create_response = "{\"id\":1,\"name\":\"tofu\",\"sha1\":\"bot-token\",\"token_last_eight\":\"ot-token\",\"scopes\":[\"read:repository\"]}" }
  }
}
mock_provider "vault" {}
mock_provider "random" {}

variables {
  org    = "example"
  repos  = ["homelab", "gitops"]
  domain = "example.com"
  bots = {
    argocd = { access = "read", repos = ["homelab", "gitops"], scopes = ["read:repository"] }
    sync   = { access = "write", repos = ["homelab"], scopes = ["write:repository"] }
  }
  mirrors_org = "mirrors"
  mirrors     = { gateway-api = "https://github.com/kubernetes-sigs/gateway-api" }
}

# Plan only: the repositories are prevent_destroy, so an applied run couldn't clean up.
run "repos" {
  command = plan

  assert {
    condition     = alltrue([for r in gitea_repository.repo : r.private && !r.auto_init && r.username == "example" && r.mirror != true])
    error_message = "repos are created empty and private under var.org"
  }
  assert {
    condition     = alltrue([for p in gitea_repository_branch_protection.main : p.rule_name == "main" && p.enable_push]) && length(gitea_repository_branch_protection.main) == 2
    error_message = "every repo's main is protected, with pushes still allowed"
  }
  assert {
    condition     = keys(gitea_repository_collaborator.bot) == ["argocd/gitops", "argocd/homelab", "sync/homelab"] && gitea_repository_collaborator.bot["argocd/gitops"].permission == "read"
    error_message = "one collaborator per bot and listed repo, with the bot's access"
  }
}

# Without repositories, so the run can be applied and destroyed.
run "bots_and_mirrors" {
  command = apply
  variables {
    repos = []
    bots = {
      argocd = { access = "read", repos = [], scopes = ["read:repository"] }
      sync   = { access = "write", repos = [], scopes = ["write:repository"] }
    }
  }

  assert {
    condition     = gitea_user.bot["sync"].email == "sync@example.com" && !gitea_user.bot["sync"].must_change_password && gitea_user.bot["sync"].prohibit_login != true
    error_message = "bots are normal users that may log in, at <bot>@<domain>"
  }
  assert {
    condition     = restapi_object.bot_token["sync"].path == "/api/v1/users/sync/tokens" && jsondecode(restapi_object.bot_token["sync"].data) == { name = "tofu", scopes = ["write:repository"] }
    error_message = "the admin mints each bot's token at /api/v1/users/<bot>/tokens"
  }
  assert {
    condition     = jsondecode(vault_kv_secret_v2.bot["argocd"].data_json) == { username = "argocd", token = "bot-token" }
    error_message = "the token from the create response goes to OpenBao with the username"
  }
  assert {
    condition     = jsondecode(vault_kv_secret_v2.tofu_state.data_json) == { username = "admin", token = "state-token" } && gitea_token.tofu_state.scopes == toset(["write:package"])
    error_message = "the admin's write:package token goes to providers/gitea-tofu-state"
  }
  assert {
    condition     = output.kv_paths == { argocd = "providers/gitea-argocd", sync = "providers/gitea-sync", tofu-state = "providers/gitea-tofu-state" }
    error_message = "kv paths per bot plus the state token"
  }
  assert {
    condition     = gitea_org.mirrors.visibility == "public" && !gitea_repository.mirror["gateway-api"].private && gitea_repository.mirror["gateway-api"].mirror
    error_message = "mirrors are public pull mirrors in a public org"
  }
  assert {
    condition     = gitea_repository.mirror["gateway-api"].migration_clone_address == "https://github.com/kubernetes-sigs/gateway-api" && gitea_repository.mirror["gateway-api"].migration_service == "git"
    error_message = "a mirror clones its upstream as plain git"
  }
}

run "access_is_read_write_or_admin" {
  command = plan
  variables {
    bots = { x = { access = "owner", repos = [], scopes = ["read:repository"] } }
  }
  expect_failures = [var.bots]
}

run "bot_repos_must_exist" {
  command = plan
  variables {
    bots = { x = { access = "read", repos = ["elsewhere"], scopes = ["read:repository"] } }
  }
  expect_failures = [var.bots]
}

run "no_bot_called_tofu_state" {
  command = plan
  variables {
    bots = { tofu-state = { access = "read", repos = [], scopes = ["read:repository"] } }
  }
  expect_failures = [var.bots]
}
