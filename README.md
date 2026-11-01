# tofu-modules

Reusable OpenTofu modules for the homelab clusters. The logic lives here; each cluster's instance
repo keeps only thin roots: the backend, the provider configuration, one module call and the
cluster's inputs.

| Module | Does |
|---|---|
| [authentik-sso](modules/authentik-sso/) | Every SSO client in Authentik (OIDC and proxy), their groups and login gates, and the client secrets in OpenBao |
| [garage](modules/garage/) | Harbor's bucket and S3 key on Garage, and the key in OpenBao |
| [harbor](modules/harbor/) | Harbor's proxy caches: a registry endpoint and a public `<key>-proxy` project per upstream registry, and the `helm-charts` push target |

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
