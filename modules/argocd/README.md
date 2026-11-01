# argocd

API tokens for Argo CD's read-only local accounts (a dashboard widget, a GitOps viewer), each
written to OpenBao at `apps/<account>/argocd`, where the consumer's ExternalSecret reads it. The
accounts themselves are declared in Argo CD's own config; only their tokens are minted here.

## Inputs

```hcl
module "argocd" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/argocd?ref=v0.1.0"

  readonly_accounts = {
    homepage = {}
    radar    = {}
  }
}
```

| Input | Default | Notes |
|---|---|---|
| `readonly_accounts` | | key = account; each must exist in Argo CD (`accounts.<name>: apiKey` and a read-only role); `kv_path` (see below) |
| `kv_mount` | `kv` | tokens at `<kv_mount>/<kv_path>` as `{token}` |

Output: `kv_paths` (path per account).

## Conventions

| Convention | Default | Override | Change with it |
|---|---|---|---|
| where an account's token goes | `apps/<account>/argocd` | `readonly_accounts[*].kv_path` | the consumer's ExternalSecret, and the policy of the root's CI role in [openbao-ci](../openbao-ci/) |

## Rotation

Once a token is a year old (`renew_after`), the next apply replaces it: the old token is deleted in
Argo CD, so the consumer fails until it reads the new one from OpenBao and restarts. To get a new
token while the old one stays valid, remove it from the state instead
(`tofu state rm 'module.argocd.argocd_account_token.readonly["<account>"]'`); the next apply mints
one and leaves the old one in Argo CD's list.

## The calling root

- **Configure the providers:** `argocd` (the server address and a login that may update accounts;
  the built-in admin is the only one that can without a token first) and `vault` (a token that
  may write each `<kv_mount>/<kv_path>`).
- **Encrypt the state.** The tokens are in it.

## Tests

`tofu test` (offline, all providers mocked) checks the tokens, where they are written and the input
validation.
