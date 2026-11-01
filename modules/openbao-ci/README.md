# openbao-ci

What CI needs from OpenBao: a JWT auth backend at `auth/gitea-jwt` that trusts Gitea Actions' OIDC
ID tokens, and one role per job type, each with a policy of the same name. A job trades its
short-lived ID token for an OpenBao token that lives 30 minutes and can't be renewed past that;
nothing is stored in Gitea.

Everything else in OpenBao (the KV mount, Kubernetes auth, the External Secrets roles) is
OpenBao's own declarative self-init, not this module.

## Inputs

```hcl
module "openbao_ci" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/openbao-ci?ref=v0.1.0"

  gitea_url  = "https://gitea.example.com"
  repository = "example/homelab"
}
```

| Input | Default | Notes |
|---|---|---|
| `gitea_url` | | Gitea's `ROOT_URL`; the issuer is `<gitea_url>/api/actions/oidc` |
| `repository` | | `<owner>/<name>`, the only repository whose jobs may log in |
| `ref` | `refs/heads/main` | the only ref whose jobs may log in; must be a protected branch |
| `kv_mount` | `kv` | the KV v2 mount the policies cover |

Outputs: `issuer`, `login_path` (`auth/gitea-jwt/login`) and `roles`.

## Roles

Every role is bound to `repository`, `ref`, `ref_protected = "true"` and the audience `openbao`.
Paths are under `<kv_mount>/data/` (and `metadata/` where Tofu manages the secret).

| Role | May |
|---|---|
| `ci` | read `providers/github-sync`, `providers/gitea-sync`, `providers/gitea-tofu-state` |
| `terraform-gitea` | read `providers/gitea`; create, update, read, delete `providers/gitea-*` |
| `terraform-harbor` | read `providers/harbor` |
| `terraform-garage` | read `providers/garage`; create, update, read, delete `providers/garage-*` |
| `terraform-argocd` | create, update, read, delete `apps/+/argocd` |

`ref_protected` is what Gitea computes from the branch protection rules when it signs the token, so
removing `main`'s protection locks CI out rather than opening it up. Pull request runs carry
`refs/pull/<n>/merge` and never match.

## A job logging in

The job asks for the ID token with `permissions: id-token: write` (default permissions never grant
it). The runner then sets `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN`; the
URL ends in `?`, and the audience is the `audience` query parameter:

```yaml
permissions:
  contents: read
  id-token: write
steps:
  - run: |
      jwt=$(curl -fsS -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
        "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r .value)
      curl -fsS -X POST -d "{\"role\": \"ci\", \"jwt\": \"$jwt\"}" \
        "$VAULT_ADDR/v1/auth/gitea-jwt/login" | jq -r .auth.client_token
```

The ID token lives 5 minutes. Its `sub` is `repo:<owner>@<owner id>/<repo>@<repo id>:ref:<ref>`
and becomes the OpenBao entity alias.

## The calling root

- **Run it once Gitea is up.** Writing the backend makes OpenBao fetch
  `<gitea_url>/api/actions/oidc/.well-known/openid-configuration`.
- **Configure the provider:** `vault` with a token that may manage auth methods and policies.
- **Gitea version.** Actions OIDC is new in Gitea 29.0.0 (go-gitea/gitea#39052). Gitea Runner
  v5.2.4 sets the two variables (earlier versions not checked).

## Tests

`tofu test` (offline, OpenBao mocked) checks the issuer, the role bindings, the policy paths and
the input validation.

A live run on 2026-11-01 against an OpenBao 2.7.2 dev server applied cleanly and planned no
changes afterwards. A local stand-in issuer signed tokens shaped like Gitea's (`aud` and
`ref_protected` as strings, Gitea's `sub`). A token from the repository's protected `main` logged
in. Tokens with `ref_protected = "false"`, Gitea's default audience, a pull request ref or another
repository were refused. `ci` could read `providers/gitea-tofu-state` but not another bot's token,
and renewing its token for 24h was capped at 30 minutes.
