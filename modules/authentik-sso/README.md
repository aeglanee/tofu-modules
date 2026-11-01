# authentik-sso

Every SSO client of a cluster in Authentik: OIDC providers and proxy apps, their applications,
their groups and login gates, and each OIDC client's secret in OpenBao, where the app's
ExternalSecret reads it. The calling root attaches the proxy apps to Authentik's embedded outpost. Design:
`homelab/docs/design/fleet/findings/sso.md`.

## Inputs

One map, one entry per client, in the shape of an app's `sso.yaml` (snake_case here):

```hcl
module "sso" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/authentik-sso?ref=v0.1.0"

  domain          = "example.com"
  superuser_group = "authentik-admin"
  admin_group     = "full-admin"
  admin_users     = ["karmok"]
  clients = {
    grafana = {
      redirect_path = "/login/generic_oauth"
      groups        = ["grafana-admin", "grafana-viewer"]
      display_name  = "Grafana"
      email         = true # Grafana, Harbor and Forgejo key their users on it
    }
    victoria-logs = {
      mode          = "proxy"
      host          = "logs"
      internal_host = "http://victoria-logs-server.monitoring.svc:9428"
      groups        = ["logs-viewer"]
    }
  }
}
```

| Input | Default | Notes |
|---|---|---|
| `clients` | | key = client name = client ID = slug; `mode` (`oidc`/`proxy`), `host`, `redirect_path`, `internal_host`, `groups`, `display_name`, `email` |
| `domain` | | apps at `https://<host>.<domain>` |
| `authentik_host` | `authentik` | for the issuer URL |
| `admin_users` | `[]` | members of `admin_group`; authoritative |
| `admin_group` / `superuser_group` | | created; `admin_group` inherits the superuser group and every app group |
| `kv_mount` / `kv_prefix` | `kv` / `apps` | secrets at `<kv_mount>/<kv_prefix>/<client>/oidc` |
| `secret_version` | `1` | bump to rewrite the secrets in OpenBao |
| `authorization_flow`, `invalidation_flow`, `signing_key` | Authentik's defaults | |

Outputs: `issuers` (per OIDC client), `proxy_provider_ids` (for the outpost) and `groups` (id per
name).

## What it creates

| Per | Resources |
|---|---|
| client | an application; an OAuth2 provider (`oidc`) or a proxy provider (`proxy`) |
| OIDC client | a random secret, written to OpenBao as `{clientId, clientSecret, issuer}` |
| client and group | a policy binding: only members of the listed groups can log in; no groups = any user |
| group named by a client | a group |
| once | the superuser and admin groups, a `groups` scope mapping |

Every OIDC client gets the `openid`, `profile`, `offline_access` and `groups` scopes, plus `email`
when `email = true`; strict redirect matching; and the authorization code and refresh token grants.

## The calling root

- **Attach the proxy apps to the embedded outpost.** Authentik creates the outpost itself, so the
  root adopts it with an import block (only a root module can import) and protects it: deleting it
  would stop every proxy app. `config` is optional and computed, so Authentik's own outpost
  settings stay as they are.

  ```hcl
  data "authentik_outpost" "embedded" {
    name = "authentik Embedded Outpost"
  }

  import {
    to = authentik_outpost.embedded
    id = data.authentik_outpost.embedded.id
  }

  resource "authentik_outpost" "embedded" {
    name               = "authentik Embedded Outpost"
    type               = "proxy"
    protocol_providers = module.sso.proxy_provider_ids
    lifecycle {
      prevent_destroy = true
    }
  }
  ```

  To let go of it, replace the resource with `removed { from = authentik_outpost.embedded
  lifecycle { destroy = false } }`.
- **Nothing else may manage these objects.** Today's in-cluster blueprint (gitops, the authentik
  wrapper) creates the same providers, applications and groups: its client, proxy and group
  entries must go before the first apply, or the apply fails on taken slugs and names, and if
  imported, the two keep overwriting each other.

- **Configure the providers:** `authentik` (URL and an API token) and `vault` (a token that may
  write `<kv_mount>/<kv_prefix>/*`).
- **Encrypt the state.** The OAuth2 provider keeps each client secret in the state; the OpenBao
  copy is write-only and isn't stored. Use OpenTofu's state encryption.

## Tests

`tofu test` (offline, all providers mocked) checks the URLs, scopes, bindings, secrets and the
input validation. A live run against Authentik 2026.8.5 on 2026-10-31 (test-only names, without
the outpost and OpenBao) applied cleanly, planned no changes afterwards, removed a client when its
entry went, and destroyed cleanly.
