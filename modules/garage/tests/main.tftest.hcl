# Offline: Garage and OpenBao are mocked, so this checks what the module would ask for, not that
# they accept it.
mock_provider "garage" {
  mock_resource "garage_key" {
    defaults = { id = "GK123", secret_access_key = "secret" }
  }
}
mock_provider "vault" {}

run "harbor_bucket" {
  command = apply

  assert {
    condition     = garage_bucket_permission.harbor.bucket_id == garage_bucket.harbor_registry.id && garage_bucket_permission.harbor.access_key_id == "GK123"
    error_message = "Harbor's key gets the harbor-registry bucket"
  }
  assert {
    condition     = garage_bucket_permission.harbor.read && garage_bucket_permission.harbor.write && garage_bucket_permission.harbor.owner
    error_message = "the key has full control of its bucket"
  }
  assert {
    condition     = vault_kv_secret_v2.harbor.mount == "kv" && output.kv_path == "providers/garage-harbor"
    error_message = "the key goes to kv/providers/garage-harbor"
  }
  assert {
    condition     = jsondecode(vault_kv_secret_v2.harbor.data_json) == { accessKey = "GK123", secretKey = "secret" }
    error_message = "OpenBao gets {accessKey, secretKey}"
  }
}
