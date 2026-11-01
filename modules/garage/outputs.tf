output "kv_paths" {
  description = "Where each consumer's S3 key is written, as {accessKey, secretKey}, under var.kv_mount."
  value       = { for k, s in vault_kv_secret_v2.consumer : k => s.name }
}
