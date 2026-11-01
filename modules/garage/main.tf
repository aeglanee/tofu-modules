locals {
  kv_paths = { for k, b in var.buckets : k => coalesce(b.kv_path, "providers/garage-${k}") }
}

# A dedicated bucket per consumer and a key that owns it.
resource "garage_bucket" "consumer" {
  for_each     = var.buckets
  global_alias = each.value.bucket
}

resource "garage_key" "consumer" {
  for_each = var.buckets
  name     = each.value.bucket
}

resource "garage_bucket_permission" "consumer" {
  for_each      = var.buckets
  bucket_id     = garage_bucket.consumer[each.key].id
  access_key_id = garage_key.consumer[each.key].id
  read          = true
  write         = true
  owner         = true # a dedicated bucket: the consumer gets full control (multipart cleanup, lifecycle)
}

# Garage generates the key; the consumer's ExternalSecret reads this copy.
resource "vault_kv_secret_v2" "consumer" {
  for_each = var.buckets
  mount    = var.kv_mount
  name     = local.kv_paths[each.key]
  data_json = jsonencode({
    accessKey = garage_key.consumer[each.key].id
    secretKey = garage_key.consumer[each.key].secret_access_key
  })
}
