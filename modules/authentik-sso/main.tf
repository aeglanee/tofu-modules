locals {
  oidc  = { for k, c in var.clients : k => c if c.mode == "oidc" }
  proxy = { for k, c in var.clients : k => c if c.mode == "proxy" }
  urls  = { for k, c in var.clients : k => "https://${coalesce(c.host, k)}.${var.domain}" }
  # Where each oidc client's secret goes under var.kv_mount.
  kv_paths = { for k, c in local.oidc : k => coalesce(c.kv_path, "${var.kv_prefix}/${k}/oidc") }

  app_groups = toset(flatten([for c in var.clients : c.groups]))
  # One login gate per client and group; the order is the group's place in the client's list.
  bindings = merge([for k, c in var.clients : { for i, g in c.groups : "${k}/${g}" => { client = k, group = g, order = i } }]...)
}

# --- What Authentik ships: read, never created ----------------------------------------------------

data "authentik_flow" "authorization" {
  slug = var.authorization_flow
}

data "authentik_flow" "invalidation" {
  slug = var.invalidation_flow
}

data "authentik_certificate_key_pair" "signing" {
  name = var.signing_key
  # Only the id is needed; this keeps the private key out of the state.
  fetch_key         = false
  fetch_certificate = false
}

data "authentik_property_mapping_provider_scope" "base" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-offline_access",
  ]
}

data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

# The groups claim (var.groups_claim), which apps map to their own roles. all_groups() includes the
# groups a group inherits from, which var.admin_group relies on.
resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "SSO groups claim"
  scope_name = "groups"
  expression = <<-EOT
    return {
        ${jsonencode(var.groups_claim)}: [group.name for group in request.user.all_groups()]
    }
  EOT
}

# --- Groups -----------------------------------------------------------------------------------------

resource "authentik_group" "app" {
  for_each = local.app_groups
  name     = each.key
}

resource "authentik_group" "superuser" {
  name         = var.superuser_group
  is_superuser = true
}

data "authentik_users" "admins" {
  for_each = toset(var.admin_users)
  username = each.value
}

resource "authentik_group" "admin" {
  name    = var.admin_group
  parents = concat([authentik_group.superuser.id], [for g in sort(tolist(local.app_groups)) : authentik_group.app[g].id])
  # Sorted numerically, so the plan is stable (sort() is lexicographic on strings).
  users = [for s in sort([for p in flatten([for d in data.authentik_users.admins : [for u in d.users : u.pk]]) : format("%012d", p)]) : tonumber(s)]
}

# --- OIDC clients -----------------------------------------------------------------------------------

resource "random_password" "oidc" {
  for_each = local.oidc
  length   = 64
  special  = false
}

resource "authentik_provider_oauth2" "app" {
  for_each = local.oidc

  name               = each.key
  client_id          = each.key
  client_secret      = random_password.oidc[each.key].result
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
  signing_key        = data.authentik_certificate_key_pair.signing.id
  # Without it Authentik rejects the auth-code flow ("Invalid grant_type for provider").
  grant_types = ["authorization_code", "refresh_token"]

  # redirect_uri_type is what Authentik returns for a login callback; without it every plan shows a
  # change (seen against Authentik 2026.8.5).
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "${local.urls[each.key]}${each.value.redirect_path}"
    }
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.base.ids,
    [authentik_property_mapping_provider_scope.groups.id],
    each.value.email ? [data.authentik_property_mapping_provider_scope.email.id] : [],
  )
}

# What the OpenBao copy says besides the secret; a change to it must rewrite that copy.
resource "terraform_data" "oidc_identity" {
  for_each = local.oidc
  input    = { client_id = each.key, issuer = "https://${var.authentik_host}.${var.domain}/application/o/${each.key}/" }
}

# The client secret for the app's ExternalSecret. Write-only, so it isn't stored a second time in
# the state (the provider above keeps its copy there), and Tofu can't see it drift: it is rewritten
# when the secret or the identity changes, or when var.secret_version is bumped.
resource "vault_kv_secret_v2" "oidc" {
  for_each = local.oidc

  mount = var.kv_mount
  name  = local.kv_paths[each.key]
  data_json_wo = jsonencode({
    clientId     = each.key
    clientSecret = random_password.oidc[each.key].result
    issuer       = "https://${var.authentik_host}.${var.domain}/application/o/${each.key}/"
  })
  data_json_wo_version = var.secret_version

  lifecycle {
    replace_triggered_by = [random_password.oidc[each.key], terraform_data.oidc_identity[each.key]]
  }
}

# --- Proxy apps -------------------------------------------------------------------------------------

resource "authentik_provider_proxy" "app" {
  for_each = local.proxy

  name               = each.key
  mode               = "proxy"
  external_host      = local.urls[each.key]
  internal_host      = each.value.internal_host
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
}

# --- Applications and their login gates -------------------------------------------------------------

resource "authentik_application" "app" {
  for_each = var.clients

  slug              = each.key
  name              = coalesce(each.value.display_name, each.key)
  meta_launch_url   = local.urls[each.key]
  protocol_provider = each.value.mode == "oidc" ? authentik_provider_oauth2.app[each.key].id : authentik_provider_proxy.app[each.key].id
}

resource "authentik_policy_binding" "login" {
  for_each = local.bindings

  target = authentik_application.app[each.value.client].uuid
  group  = authentik_group.app[each.value.group].id
  order  = each.value.order
}
