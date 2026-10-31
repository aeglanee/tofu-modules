# Offline: every provider is mocked, so this checks what the module would ask Authentik and
# OpenBao for, not that they accept it.
mock_provider "authentik" {
  mock_data "authentik_flow" {
    defaults = { id = "flow" }
  }
  mock_data "authentik_certificate_key_pair" {
    defaults = { id = "key" }
  }
  mock_data "authentik_property_mapping_provider_scope" {
    defaults = { id = "scope-email", ids = ["scope-openid", "scope-profile", "scope-offline"] }
  }
  mock_data "authentik_users" {
    defaults = {
      users = [{
        pk         = 7, username = "karmok", uuid = "u", uid = "u", name = "", email = "", path = "", type = "internal",
        avatar     = "", attributes = "{}", groups = [], is_active = true, is_superuser = false, date_joined = "",
        last_login = "",
      }]
    }
  }
  # Provider ids are numbers in Authentik; the mock's default random strings aren't.
  mock_resource "authentik_provider_oauth2" {
    defaults = { id = "1" }
  }
  mock_resource "authentik_provider_proxy" {
    defaults = { id = "2" }
  }
}
mock_provider "vault" {}
mock_provider "random" {}

variables {
  domain = "example.com"
  clients = {
    grafana = {
      redirect_path = "/login/generic_oauth"
      groups        = ["grafana-admin", "grafana-viewer"]
      display_name  = "Grafana"
    }
    forgejo = {
      redirect_path = "/user/oauth2/authentik/callback"
      groups        = ["forgejo-admin"]
      email         = true
    }
    headlamp = {
      redirect_path = "/oidc-callback"
    }
    victoria-logs = {
      mode          = "proxy"
      host          = "logs"
      internal_host = "http://victoria-logs-server.monitoring.svc:9428"
      groups        = ["logs-viewer"]
    }
  }
  admin_users = ["karmok"]
}

run "clients" {
  command = apply

  assert {
    condition     = authentik_provider_oauth2.app["grafana"].allowed_redirect_uris[0].url == "https://grafana.example.com/login/generic_oauth"
    error_message = "redirect URL is https://<host>.<domain><redirect_path>"
  }
  assert {
    condition     = authentik_provider_proxy.app["victoria-logs"].external_host == "https://logs.example.com"
    error_message = "host overrides the client name"
  }
  assert {
    condition     = authentik_application.app["headlamp"].name == "headlamp" && authentik_application.app["grafana"].name == "Grafana"
    error_message = "display_name defaults to the key"
  }
  assert {
    condition     = contains(authentik_provider_oauth2.app["forgejo"].property_mappings, "scope-email") && !contains(authentik_provider_oauth2.app["grafana"].property_mappings, "scope-email")
    error_message = "only clients with email = true get the email scope"
  }
  assert {
    condition     = length(authentik_policy_binding.login) == 4 && authentik_policy_binding.login["grafana/grafana-viewer"].order == 1
    error_message = "one login gate per client and group, ordered as listed; none for a client without groups"
  }
  assert {
    condition     = keys(vault_kv_secret_v2.oidc) == ["forgejo", "grafana", "headlamp"] && vault_kv_secret_v2.oidc["grafana"].name == "apps/grafana/oidc"
    error_message = "a secret per oidc client at apps/<client>/oidc, none for proxies"
  }
  assert {
    condition     = length(output.proxy_provider_ids) == 1
    error_message = "one provider id per proxy client, for the embedded outpost"
  }
  assert {
    condition     = length(authentik_group.admin.parents) == 5 && authentik_group.admin.users == tolist([7])
    error_message = "the admin group inherits the superuser group and every app group, and holds the admin users"
  }
  assert {
    condition     = output.issuers["grafana"] == "https://authentik.example.com/application/o/grafana/" && !contains(keys(output.issuers), "victoria-logs")
    error_message = "issuer per oidc client"
  }
}

run "oidc_needs_redirect" {
  command = plan
  variables {
    clients = { x = {} }
  }
  expect_failures = [var.clients]
}

run "proxy_needs_internal_host" {
  command = plan
  variables {
    clients = { x = { mode = "proxy" } }
  }
  expect_failures = [var.clients]
}

run "mode_is_oidc_or_proxy" {
  command = plan
  variables {
    clients = { x = { mode = "saml", redirect_path = "/" } }
  }
  expect_failures = [var.clients]
}

run "group_listed_twice" {
  command = plan
  variables {
    clients = { x = { redirect_path = "/", groups = ["a", "a"] } }
  }
  expect_failures = [var.clients]
}

run "client_cant_list_the_admin_group" {
  command = plan
  variables {
    clients = { x = { redirect_path = "/", groups = ["full-admin"] } }
  }
  expect_failures = [var.clients]
}

run "secret_rewritten_with_its_identity" {
  command = apply
  variables {
    authentik_host = "sso"
  }
  assert {
    condition     = terraform_data.oidc_identity["grafana"].input.issuer == "https://sso.example.com/application/o/grafana/"
    error_message = "the OpenBao copy follows the issuer"
  }
}
