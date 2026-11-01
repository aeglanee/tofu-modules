# tofu-modules

Reusable OpenTofu modules for the homelab clusters. The logic lives here; each cluster's instance
repo keeps only thin roots: the backend, the provider configuration, one module call and the
cluster's inputs.

| Module | Does |
|---|---|
| [argocd](modules/argocd/) | API tokens for Argo CD's read-only local accounts, in OpenBao |
| [authentik-sso](modules/authentik-sso/) | Every SSO client in Authentik (OIDC and proxy), their groups and login gates, and the client secrets in OpenBao |
| [garage](modules/garage/) | A bucket and an S3 key per consumer on Garage, and each key in OpenBao |
| [gitea](modules/gitea/) | Gitea's content as its admin: an org of empty private repositories, bot users with their tokens in OpenBao, the admin's state token, and public pull mirrors |
| [harbor](modules/harbor/) | Harbor's proxy caches: a registry endpoint and a public `<key>-proxy` project per upstream registry, and public push-target projects |
| [openbao-ci](modules/openbao-ci/) | OpenBao's login for Gitea Actions jobs (OIDC ID tokens at `auth/gitea-jwt`) and a role and policy per job type |

## Rules for modules

A module holds the *how*; every value lives in the calling root's `<cluster>.tfvars`.

1. **A module never holds definitions.** Only resources, typed variables (validated where it
   helps), outputs, and a README with a minimal example call. Nothing site-specific.
2. **Which things exist is a definition** (buckets, projects, policies, roles, accounts, groups,
   repositories, bots): a required input with no default.
3. **A convention stays a default, with an override.** A name pattern or path that other systems
   read is the module's default, and each one gets an optional field (`optional(...)`, the
   convention as the fallback via `coalesce` or the optional default). The module's README lists
   each convention, its override, and what else must change with it (an openbao-ci policy, a
   gitops ExternalSecret).
4. **Defaults only for conventions, product facts** (Authentik's built-in flow names) **and
   plumbing** (`kv_mount = "kv"`).
5. **Roots keep the state and secrets out of variables.** The backend comes from `TF_HTTP_*`,
   OpenBao from `VAULT_ADDR`/`VAULT_TOKEN`, provider credentials from `ephemeral` reads.

The test for a new input: would another cluster want a different value because of what it runs?
Then it is a required input. Only because of naming taste? Then it is a convention with an
optional override.

## Using a module

Pin a tag or a commit, as for any versioned dependency:

```hcl
module "sso" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/authentik-sso?ref=v0.1.0"
}
```

## Development

```sh
nix develop -c pre-commit install    # once; hooks then run on every commit
nix develop -c tofu -chdir=modules/<module> test
nix develop -c tflint --recursive --config "$PWD/.tflint.hcl"
```

`tofu test` mocks every provider, so it runs offline and checks what a module would ask for, not
that the API accepts it. CI (`.gitea/workflows/validate.yml`, in Gitea, on every push) runs the
same: the pre-commit hooks, gitleaks, `renovate.json`, `tofu fmt`/`validate`/`test` for every module,
and tflint. Renovate auto-merges a pull request only once all of it passed.
