output "proxy_projects" {
  description = "Proxy-cache project name per registry key."
  value       = { for k, p in harbor_project.proxy : k => p.name }
}
