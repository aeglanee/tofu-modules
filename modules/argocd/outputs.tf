output "kv_paths" {
  description = "Where each account's token is written, as {token}, under var.kv_mount."
  value       = { for k, s in vault_kv_secret_v2.token : k => s.name }
}
