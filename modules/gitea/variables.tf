variable "org" {
  description = "Organisation that owns var.repos; created here."
  type        = string
}

variable "repos" {
  description = "Repositories created empty and private under var.org (a sync job fills them), each with main protected against force-push and deletion."
  type        = list(string)
}

variable "bots" {
  description = <<-EOT
    One Gitea user per entry; the key is the username. Each gets an API token, written to
    <kv_mount>/providers/gitea-<bot> as {username, token}.
      access  collaborator permission on each of its repos: read, write or admin
      repos   names from var.repos
      scopes  the token's scopes, e.g. ["read:repository"]; changing them replaces the token
  EOT
  type = map(object({
    access = string
    repos  = list(string)
    scopes = list(string)
  }))

  validation {
    condition     = alltrue([for b in var.bots : contains(["read", "write", "admin"], b.access)])
    error_message = "bots[*].access must be \"read\", \"write\" or \"admin\"."
  }
  validation {
    condition     = alltrue([for b in var.bots : length(setsubtract(b.repos, var.repos)) == 0])
    error_message = "A bot lists a repository that isn't in var.repos."
  }
  # providers/gitea-tofu-state holds the admin's state token.
  validation {
    condition     = !contains(keys(var.bots), "tofu-state")
    error_message = "A bot can't be called tofu-state."
  }
}

variable "domain" {
  description = "Bot emails are <bot>@<domain>."
  type        = string
}

variable "mirrors_org" {
  description = "Public organisation that holds var.mirrors; created here."
  type        = string
}

variable "mirrors" {
  description = "Public pull mirrors under var.mirrors_org: repository name => upstream https clone URL."
  type        = map(string)
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the tokens are written to."
  type        = string
  default     = "kv"
}
