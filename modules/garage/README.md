# garage

S3 storage on Garage, one bucket per consumer: the bucket, a key of the same name with full
control of it, and that key in OpenBao, where the consumer's ExternalSecret reads it.

## Inputs

```hcl
module "garage" {
  source = "git::https://github.com/aeglanee/tofu-modules.git//modules/garage?ref=v0.1.0"

  buckets = {
    harbor = { bucket = "harbor-registry" }
  }
}
```

| Input | Default | Notes |
|---|---|---|
| `buckets` | | key = consumer; `bucket` (the global alias, also the key's name), `kv_path` (see below) |
| `kv_mount` | `kv` | the keys go to `<kv_mount>/<kv_path>` as `{accessKey, secretKey}` |

Output: `kv_paths` (path per consumer).

## Conventions

| Convention | Default | Override | Change with it |
|---|---|---|---|
| where a consumer's key goes | `providers/garage-<consumer>` | `buckets[*].kv_path` | the consumer's ExternalSecret, and the policy of the root's CI role in [openbao-ci](../openbao-ci/) |

## The calling root

- **Declare the provider as `jkossis/garage`.** The source address must match this module's, or
  the root configures a different provider than the one the module uses.
- **Configure the providers:** `garage` (a node's admin API endpoint, which isn't on the ClusterIP
  service, and the admin token) and `vault` (a token that may write each `<kv_mount>/<kv_path>`).
- **Encrypt the state.** Garage's secret keys are in it, and so are the OpenBao copies.

## Tests

`tofu test` (offline, all providers mocked) checks the buckets, the keys' permissions, what is
written to OpenBao and where, and the input validation.
