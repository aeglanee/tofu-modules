# tofu-modules

Reusable OpenTofu modules for the homelab clusters. Each cluster's root modules and inputs live in
its instance repo (for irkalla: `homelab/terraform/`); this repo holds only what several roots can
share.

| Module | Does |
|---|---|
| [authentik-sso](modules/authentik-sso/) | Every SSO client in Authentik (OIDC and proxy), their groups and login gates, and the client secrets in OpenBao |

## Using a module

Pin a tag, as for any versioned dependency:

```hcl
module "sso" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/authentik-sso?ref=v0.1.0"
}
```

## Development

```sh
nix develop -c pre-commit install    # once; hooks then run on every commit
nix develop -c tofu -chdir=modules/authentik-sso test
```

`tofu test` mocks every provider, so it runs offline and checks what a module would ask for, not
that the API accepts it.
