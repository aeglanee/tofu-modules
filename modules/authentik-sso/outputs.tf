output "issuers" {
  description = "Issuer URL per oidc client, as written to OpenBao."
  value       = { for k, _ in local.oidc : k => "https://${var.authentik_host}.${var.domain}/application/o/${k}/" }
}

output "proxy_provider_ids" {
  description = "Ids of the proxy providers, for the embedded outpost's protocol_providers (see README)."
  value       = [for k in sort(keys(local.proxy)) : authentik_provider_proxy.app[k].id]
}

output "groups" {
  description = "Group id per group name, including var.superuser_group and var.admin_group."
  value = merge(
    { for g, r in authentik_group.app : g => r.id },
    { (var.superuser_group) = authentik_group.superuser.id, (var.admin_group) = authentik_group.admin.id },
  )
}
