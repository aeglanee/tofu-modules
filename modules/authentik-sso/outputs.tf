output "issuers" {
  description = "Issuer URL per oidc client, as written to OpenBao."
  value       = { for k, _ in local.oidc : k => "https://${var.authentik_host}.${var.domain}/application/o/${k}/" }
}

output "groups" {
  description = "Group id per group name, including var.superuser_group and var.admin_group."
  value = merge(
    { for g, r in authentik_group.app : g => r.id },
    { (var.superuser_group) = authentik_group.superuser.id, (var.admin_group) = authentik_group.admin.id },
  )
}
