# gitea

A Gitea instance's content, managed as its admin: an organisation with empty private
repositories, bot users with their tokens in OpenBao, the admin's token for the Tofu states, and a
public organisation of pull mirrors.

## Inputs

```hcl
module "gitea" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/gitea?ref=v0.1.0"

  org    = "example"
  repos  = ["homelab", "gitops", "tofu-modules"]
  domain = "example.com"
  bots = {
    argocd   = { access = "read", repos = ["homelab", "gitops", "tofu-modules"], scopes = ["read:repository"] }
    renovate = { access = "write", repos = ["homelab", "gitops", "tofu-modules"], scopes = ["write:repository", "write:issue", "read:user", "read:organization"] }
    sync     = { access = "write", repos = ["homelab", "gitops", "tofu-modules"], scopes = ["write:repository"] }
  }
  mirrors_org = "mirrors"
  mirrors = {
    gateway-api = "https://github.com/kubernetes-sigs/gateway-api"
  }
}
```

| Input | Default | Notes |
|---|---|---|
| `org` | | created; owns `repos` |
| `repos` | | created empty and private (a sync job fills them); `protected_branch` refuses force-push and deletion, anyone with write may still push |
| `bots` | | key = username; `access` (`read`/`write`/`admin`) on each of its `repos` (a subset of `repos`), token `scopes`; `kv_path`, `token_name` (see below) |
| `domain` | | bot emails `<bot>@<domain>` |
| `mirrors_org` | | created, public |
| `mirrors` | | name => upstream clone URL; public pull mirrors, synced every 8h |
| `protected_branch`, `state_token_name`, `state_token_kv_path` | see below | |
| `kv_mount` | `kv` | KV v2 mount for the tokens |

Outputs: `bot_usernames` and `kv_paths` (per bot, plus the state token under the key `tofu-state`).

## Conventions

| Convention | Default | Override | Change with it |
|---|---|---|---|
| where a bot's token goes | `providers/gitea-<bot>` | `bots[*].kv_path` | whatever reads the token (an ExternalSecret, a workflow), and the policies in [openbao-ci](../openbao-ci/) |
| a bot token's name in Gitea | `tofu` | `bots[*].token_name` | nothing reads it; a new name replaces the token |
| the state token's name in Gitea | `tofu-state` | `state_token_name` | nothing reads it |
| where the state token goes | `providers/gitea-tofu-state` | `state_token_kv_path` | whatever opens the Tofu states with it (CI, a laptop task), and the policies in openbao-ci |
| the protected branch | `main` | `protected_branch` | openbao-ci's `ref` (`refs/heads/<branch>`): it only trusts a protected ref; and whatever relies on the branch refusing force-pushes (a fast-forward-only sync) |

## What it creates

| Per | Resources |
|---|---|
| repo | a private, empty repository; protection on `protected_branch` |
| bot | a user (random password nobody uses, may log in); a collaborator entry per repo; a token, written to `<kv_mount>/<kv_path>` as `{username, token}` |
| once | the two orgs; the admin's state token (`write:package`) at `<kv_mount>/<state_token_kv_path>` as `{username, token}` |
| mirror | a public pull mirror under `mirrors_org` |

The repositories can't be destroyed through Tofu (`prevent_destroy`): dropping or renaming an entry
in `repos` fails the plan instead of deleting the history. To really drop one, remove it from the
state (`tofu state rm 'module.gitea.gitea_repository.repo["<name>"]'` and its
`gitea_repository_branch_protection.main` entry), then delete it in Gitea.

Bots aren't `prohibit_login`: Gitea then refuses git over HTTP and package access with
"Your account is disabled.", token or not. Branch protection on `protected_branch` also makes Gitea
Actions ID tokens from that branch carry `ref_protected = "true"`, which
[openbao-ci](../openbao-ci/) binds to.

## Bot tokens

The gitea provider's `gitea_token` mints only for the user it is logged in as, so each bot's token
is minted by the admin through Gitea's API (`POST /api/v1/users/<bot>/tokens`) with the restapi
provider. Gitea returns the token only in that response; the restapi provider keeps it in the state
(`create_response`) and the module copies it to OpenBao. Later runs read the token back from the
bot's token list and change nothing.

- **New scopes or a new name replace the token**: the old one is revoked, the new one written to
  OpenBao.
- **Removing a bot** revokes its token, deletes its OpenBao record, its collaborator entries and
  the user.
- **A token deleted by hand** makes every later refresh fail with `cannot read an object unless
  the ID has been set` (a restapi provider limit). Remove it from the state and apply to mint a new
  one: `tofu state rm 'module.gitea.restapi_object.bot_token["<bot>"]'`.

## The calling root

- **Configure the providers**, all as the Gitea admin (who must not use two-factor
  authentication: the token endpoints need basic auth):

  ```hcl
  provider "gitea" {
    base_url = "https://gitea.example.com"
    username = "gitea-admin"
    password = local.admin_password
  }

  provider "restapi" {
    uri                   = "https://gitea.example.com"
    username              = "gitea-admin"
    password              = local.admin_password
    create_returns_object = true # without it the provider never sees the token, and won't create
  }
  ```

  plus `vault` (a token that may write `<kv_mount>/providers/gitea-*`) and `random`.
- **Run OpenTofu with `API_DATA_IS_SENSITIVE=true`** in its environment. Only then does the
  restapi provider mark its attributes sensitive; without it a plan that replaces or destroys a
  token prints the token. The module fails every plan without it.
- **Don't use the state token for this root's own backend.** Replacing that token revokes
  it before the run saves its state, which then fails and keeps the lock. Use the admin password
  for this root's backend.
- **Encrypt the state.** The bot tokens, the state token and the bots' passwords are in it.

## Tests

`tofu test` (offline, all providers mocked; the dev shell sets `API_DATA_IS_SENSITIVE`) checks the
repositories, the bots and their access, the token requests, what is written to OpenBao and where,
the mirrors, the overrides and the input validation.

A live run on 2026-11-01 against a throwaway Gitea 28.2.0 and an OpenBao 2.7.2 dev server applied
cleanly and planned no changes afterwards (twice), from an empty instance and after changes. The
bot tokens cloned and pushed over HTTP, a read bot couldn't push, force-pushing `main` was refused,
and the state token wrote a Terraform state package. A scope change replaced only that token (the
old one stopped working); removing a bot left nothing behind, and so did destroying everything
(run before the repositories became `prevent_destroy`).
