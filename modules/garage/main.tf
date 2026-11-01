# Harbor's registry storage: a dedicated bucket and a key that owns it.
resource "garage_bucket" "harbor_registry" {
  global_alias = "harbor-registry"
}

resource "garage_key" "harbor" {
  name = "harbor-registry"
}

resource "garage_bucket_permission" "harbor" {
  bucket_id     = garage_bucket.harbor_registry.id
  access_key_id = garage_key.harbor.id
  read          = true
  write         = true
  owner         = true # a dedicated bucket: Harbor gets full control (multipart cleanup, lifecycle)
}

# Garage generates the key; Harbor's ExternalSecret reads this copy.
resource "vault_kv_secret_v2" "harbor" {
  mount = var.kv_mount
  name  = "providers/garage-harbor"
  data_json = jsonencode({
    accessKey = garage_key.harbor.id
    secretKey = garage_key.harbor.secret_access_key
  })
}
