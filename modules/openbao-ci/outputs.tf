output "issuer" {
  description = "The OIDC issuer the auth backend trusts."
  value       = local.issuer
}

output "login_path" {
  description = "Where a job logs in: POST auth/<path>/login with {role, jwt}."
  value       = "auth/${vault_jwt_auth_backend.gitea.path}/login"
}

output "roles" {
  description = "Role names on the backend; each has the policy of the same name."
  value       = sort(keys(vault_jwt_auth_backend_role.role))
}
