# harbor

Harbor's proxy caches: one registry endpoint and one public `<key>-proxy` project per upstream
registry, plus a public `helm-charts` project as the push target for charts that only exist in HTTP
Helm repositories (Harbor 2.x proxies OCI only).

## Inputs

```hcl
module "harbor" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/harbor?ref=v0.1.0"

  registries = {
    dockerhub = { provider_name = "docker-hub", endpoint_url = "https://hub.docker.com" }
    ghcr      = { provider_name = "github", endpoint_url = "https://ghcr.io" }
    # Harbor's proxy cache rejects the "quay" type; the generic one works.
    quay = { provider_name = "docker-registry", endpoint_url = "https://quay.io" }
    # A plain-HTTP in-cluster endpoint, such as an HTTP-to-OCI Helm shim.
    shim = { provider_name = "docker-registry", endpoint_url = "http://chart-proxy.chart-proxy.svc:9000", insecure = true }
  }
}
```

| Input | Default | Notes |
|---|---|---|
| `registries` | | key = endpoint name, project `<key>-proxy`; `provider_name`, `endpoint_url`, `insecure` (`false`) |

Output: `proxy_projects` (project name per key). Images pull as
`harbor.<domain>/<key>-proxy/<repo>:<tag>`; whatever points nodes or charts at those paths (a
containerd mirror config, for example) must use the same keys.

## The calling root

- **Configure the provider:** `harbor` with Harbor's URL and the built-in `admin` account.
- Harbor creates the `library` project itself; it isn't managed here.

## Tests

`tofu test` (offline, Harbor mocked) checks the project names, the registry each one caches and the
`insecure` default.
