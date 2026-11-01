# tofu-modules

Reusable OpenTofu modules for the homelab clusters. The logic lives here; each cluster's instance
repo keeps only thin roots: the backend, the provider configuration, one module call and the
cluster's inputs.

| Module | Does |
|---|---|
| [argocd](modules/argocd/) | API tokens for Argo CD's read-only local accounts, in OpenBao |
| [authentik-sso](modules/authentik-sso/) | Every SSO client in Authentik (OIDC and proxy), their groups and login gates, and the client secrets in OpenBao |
| [garage](modules/garage/) | Harbor's bucket and S3 key on Garage, and the key in OpenBao |
| [gitea](modules/gitea/) | Gitea's content as its admin: an org of empty private repositories, bot users with their tokens in OpenBao, the admin's state token, and public pull mirrors |
| [harbor](modules/harbor/) | Harbor's proxy caches: a registry endpoint and a public `<key>-proxy` project per upstream registry, and the `helm-charts` push target |
| [openbao-ci](modules/openbao-ci/) | OpenBao's login for Gitea Actions jobs (OIDC ID tokens at `auth/gitea-jwt`) and a role and policy per job type |

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
```

`tofu test` mocks every provider, so it runs offline and checks what a module would ask for, not
that the API accepts it.
