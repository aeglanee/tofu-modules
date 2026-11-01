output "kv_path" {
  description = "Where Harbor's S3 key is written, as {accessKey, secretKey}, under var.kv_mount."
  value       = vault_kv_secret_v2.harbor.name
}
