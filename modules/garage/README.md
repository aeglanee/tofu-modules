# garage

Harbor's registry storage on Garage: the `harbor-registry` bucket, a `harbor-registry` key with
full control of it, and that key in OpenBao at `providers/garage-harbor`, where Harbor's
ExternalSecret reads it.

## Inputs

```hcl
module "garage" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/garage?ref=v0.1.0"
}
```

| Input | Default | Notes |
|---|---|---|
| `kv_mount` | `kv` | the key goes to `<kv_mount>/providers/garage-harbor` as `{accessKey, secretKey}` |

Output: `kv_path` (`providers/garage-harbor`).

## The calling root

- **Declare the provider as `jkossis/garage`.** The source address must match this module's, or
  the root configures a different provider than the one the module uses.
- **Configure the providers:** `garage` (a node's admin API endpoint, which isn't on the ClusterIP
  service, and the admin token) and `vault` (a token that may write
  `<kv_mount>/providers/garage-*`).
- **Encrypt the state.** Garage's secret key is in it, and so is the OpenBao copy.

## Tests

`tofu test` (offline, all providers mocked) checks the bucket permission and what is written to
OpenBao.
