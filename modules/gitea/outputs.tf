output "bot_usernames" {
  description = "Gitea username per bot."
  value       = { for k, u in gitea_user.bot : k => u.username }
}

output "kv_paths" {
  description = "Where each bot's {username, token} is written under var.kv_mount, plus the admin's state token (key tofu-state)."
  value = merge(
    { for k, s in vault_kv_secret_v2.bot : k => s.name },
    { tofu-state = vault_kv_secret_v2.tofu_state.name },
  )
}
