locals {
  # One collaborator per bot and repository.
  collaborators = merge([for b, c in var.bots : { for r in c.repos : "${b}/${r}" => { bot = b, repo = r, access = c.access } }]...)
}

# --- Repositories ---------------------------------------------------------------------------------

resource "gitea_org" "main" {
  name = var.org
}

# Empty: the sync job pushes the history in, so this needs no credential for the source.
resource "gitea_repository" "repo" {
  for_each = toset(var.repos)

  username  = gitea_org.main.name
  name      = each.key
  private   = true
  auto_init = false
  # Gitea's own values. The provider's defaults (true, 8h0m0s for a repository that isn't a
  # mirror) would show as changes on the next plan.
  ignore_whitespace_conflicts = false
  migration_mirror_interval   = ""

  # Dropping or renaming an entry would delete the repository and its history; see README.
  lifecycle {
    prevent_destroy = true
  }
}

# Not to restrict pushes (anyone with write may still push, so Renovate and the sync keep working)
# but to refuse force-pushes and deletion of main, which the fast-forward-only sync relies on. It
# also makes Gitea Actions ID tokens from main carry ref_protected = "true".
resource "gitea_repository_branch_protection" "main" {
  for_each = toset(var.repos)

  username    = gitea_org.main.name
  name        = gitea_repository.repo[each.key].name
  rule_name   = "main"
  enable_push = true
}

# --- Bots -----------------------------------------------------------------------------------------

# The provider requires a password; nobody uses it.
resource "random_password" "bot" {
  for_each = var.bots
  length   = 64
  special  = false
}

# Normal users, not prohibit_login: Gitea refuses git over HTTP and package access to a user that
# can't log in, token or not.
resource "gitea_user" "bot" {
  for_each = var.bots

  username             = each.key
  login_name           = each.key
  email                = "${each.key}@${var.domain}"
  password             = random_password.bot[each.key].result
  must_change_password = false
  send_notification    = false
}

resource "gitea_repository_collaborator" "bot" {
  for_each = local.collaborators

  owner      = gitea_org.main.name
  repo       = gitea_repository.repo[each.value.repo].name
  username   = gitea_user.bot[each.value.bot].username
  permission = each.value.access
}

# gitea_token can only mint for the user the provider is logged in as, so the admin mints each
# bot's token through POST /api/v1/users/<bot>/tokens. Gitea returns the token (sha1) only in that
# response, which the restapi provider keeps as create_response (create_returns_object = true on
# the provider). There is no GET for one token: it is read back from the user's token list by id,
# and DELETE /api/v1/users/<bot>/tokens/<id> revokes it.
resource "restapi_object" "bot_token" {
  for_each = var.bots

  path         = "/api/v1/users/${gitea_user.bot[each.key].username}/tokens"
  data         = jsonencode({ name = "tofu", scopes = each.value.scopes })
  id_attribute = "id"
  read_search = {
    search_key   = "id"
    search_value = "{id}"
  }
  # The list adds id, token_last_eight and timestamps (last_used_at changes with every use); only
  # what was sent is compared.
  ignore_server_additions = true
  # Gitea can't edit a token: other scopes need a new one.
  force_new = ["scopes"]

  lifecycle {
    # The provider marks its attributes sensitive only with API_DATA_IS_SENSITIVE=true in its
    # environment. Without it, a plan that replaces or destroys a token prints the token
    # (create_response). data is checked because it is known at plan time.
    postcondition {
      condition     = issensitive(self.data)
      error_message = "Set API_DATA_IS_SENSITIVE=true in OpenTofu's environment, or plans print the bot tokens."
    }
  }
}

resource "vault_kv_secret_v2" "bot" {
  for_each = var.bots

  mount = var.kv_mount
  name  = "providers/gitea-${each.key}"
  data_json = jsonencode({
    username = gitea_user.bot[each.key].username
    token    = jsondecode(restapi_object.bot_token[each.key].create_response).sha1
  })
}

# --- The admin's state token ----------------------------------------------------------------------

# Every Tofu state is a Gitea package owned by the admin; CI reads this token to reach them.
data "gitea_user" "admin" {}

resource "gitea_token" "tofu_state" {
  name   = "tofu-state"
  scopes = ["write:package"]
}

resource "vault_kv_secret_v2" "tofu_state" {
  mount = var.kv_mount
  name  = "providers/gitea-tofu-state"
  data_json = jsonencode({
    username = data.gitea_user.admin.username
    token    = gitea_token.tofu_state.token
  })
}

# --- Mirrors --------------------------------------------------------------------------------------

resource "gitea_org" "mirrors" {
  name       = var.mirrors_org
  visibility = "public"
}

resource "gitea_repository" "mirror" {
  for_each = var.mirrors

  username                = gitea_org.mirrors.name
  name                    = each.key
  private                 = false
  mirror                  = true
  migration_clone_address = each.value
  migration_service       = "git"

  # What Gitea gives a mirror; the provider's defaults would show as changes on every plan. Its
  # units (DEFAULT_MIRROR_REPO_UNITS) have no pull requests, so no merge settings either.
  has_pull_requests           = false
  allow_merge_commits         = false
  allow_rebase                = false
  allow_rebase_explicit       = false
  allow_squash_merge          = false
  ignore_whitespace_conflicts = false

  lifecycle {
    # The upstream's default branch.
    ignore_changes = [default_branch]
  }
}
