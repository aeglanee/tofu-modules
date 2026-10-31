variable "domain" {
  description = "Apps are reached at https://<host>.<domain>; Authentik at https://<authentik_host>.<domain>."
  type        = string
}

variable "authentik_host" {
  description = "Authentik's subdomain, for the issuer URLs written to OpenBao."
  type        = string
  default     = "authentik"
}

variable "clients" {
  description = <<-EOT
    One entry per SSO client; the key is the client name = client ID = application slug (renaming
    it creates a new client). The fields match the `sso.yaml` an app declares:
      mode          "oidc" (default) or "proxy" (Authentik's embedded outpost in front of the app)
      host          subdomain under var.domain; defaults to the key
      redirect_path the app's callback path; oidc only, required there
      internal_host where the outpost forwards to; proxy only, required there
      groups        full group names allowed to log in; empty = any user
      display_name  shown in Authentik; defaults to the key
      email         send the email claim (oidc); off unless the app needs it
  EOT
  type = map(object({
    mode          = optional(string, "oidc")
    host          = optional(string)
    redirect_path = optional(string)
    internal_host = optional(string)
    groups        = optional(list(string), [])
    display_name  = optional(string)
    email         = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for c in var.clients : contains(["oidc", "proxy"], c.mode)])
    error_message = "clients[*].mode must be \"oidc\" or \"proxy\"."
  }
  validation {
    condition     = alltrue([for c in var.clients : c.mode != "oidc" || c.redirect_path != null])
    error_message = "An oidc client needs redirect_path."
  }
  validation {
    condition     = alltrue([for c in var.clients : c.mode != "proxy" || c.internal_host != null])
    error_message = "A proxy client needs internal_host."
  }
  validation {
    condition     = alltrue([for c in var.clients : length(distinct(c.groups)) == length(c.groups)])
    error_message = "A client lists a group twice."
  }
  # The module makes these two itself, and the admin group inherits every client group.
  validation {
    condition     = !anytrue([for c in var.clients : contains(c.groups, var.superuser_group) || contains(c.groups, var.admin_group)])
    error_message = "A client lists the superuser or admin group; give it an app group instead."
  }
}

variable "superuser_group" {
  description = "Group whose members are Authentik superusers."
  type        = string
  default     = "authentik-admin"
}

variable "admin_group" {
  description = "Group whose members belong to every app group and to var.superuser_group."
  type        = string
  default     = "full-admin"
}

variable "admin_users" {
  description = "Usernames that are members of var.admin_group. Users that don't exist yet are skipped until the next apply. Membership is authoritative."
  type        = list(string)
  default     = []
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the client secrets are written to."
  type        = string
  default     = "kv"
}

variable "kv_prefix" {
  description = "Each oidc client's secret goes to <kv_prefix>/<client>/oidc, as {clientId, clientSecret, issuer}."
  type        = string
  default     = "apps"
}

variable "secret_version" {
  description = "Bump to rewrite every secret in OpenBao (they are write-only, so Tofu can't see drift there)."
  type        = number
  default     = 1
}

variable "authorization_flow" {
  description = "Slug of the flow that authorises a login."
  type        = string
  default     = "default-provider-authorization-implicit-consent"
}

variable "invalidation_flow" {
  description = "Slug of the flow that ends a session."
  type        = string
  default     = "default-provider-invalidation-flow"
}

variable "signing_key" {
  description = "Name of the certificate key pair that signs the oidc tokens."
  type        = string
  default     = "authentik Self-signed Certificate"
}
