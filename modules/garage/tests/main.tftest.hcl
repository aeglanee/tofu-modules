# Offline: Garage and OpenBao are mocked, so this checks what the module would ask for, not that
# they accept it.
mock_provider "garage" {
  mock_resource "garage_key" {
    defaults = { id = "GK123", secret_access_key = "secret" }
  }
}
mock_provider "vault" {}

variables {
  buckets = {
    harbor = { bucket = "harbor-registry" }
    cnpg   = { bucket = "cnpg-backups", kv_path = "apps/cnpg/s3" }
  }
}

run "buckets" {
  command = apply

  assert {
    condition     = garage_bucket.consumer["harbor"].global_alias == "harbor-registry" && garage_key.consumer["harbor"].name == "harbor-registry"
    error_message = "a consumer gets its bucket and a key named the same"
  }
  assert {
    condition     = garage_bucket_permission.consumer["harbor"].bucket_id == garage_bucket.consumer["harbor"].id && garage_bucket_permission.consumer["harbor"].access_key_id == "GK123"
    error_message = "a consumer's key gets its bucket"
  }
  assert {
    condition     = alltrue([for p in garage_bucket_permission.consumer : p.read && p.write && p.owner])
    error_message = "the key has full control of its bucket"
  }
  assert {
    condition     = output.kv_paths == { harbor = "providers/garage-harbor", cnpg = "apps/cnpg/s3" }
    error_message = "the key goes to providers/garage-<consumer> unless kv_path says otherwise"
  }
  assert {
    condition     = vault_kv_secret_v2.consumer["harbor"].mount == "kv" && jsondecode(vault_kv_secret_v2.consumer["harbor"].data_json) == { accessKey = "GK123", secretKey = "secret" }
    error_message = "OpenBao gets {accessKey, secretKey} on the kv mount"
  }
}

run "kv_paths_are_distinct" {
  command = plan
  variables {
    buckets = {
      harbor = { bucket = "harbor-registry" }
      other  = { bucket = "other", kv_path = "providers/garage-harbor" }
    }
  }
  expect_failures = [var.buckets]
}
