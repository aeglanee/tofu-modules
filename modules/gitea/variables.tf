variable "org" {
  description = "Organisation that owns var.repos; created here."
  type        = string
}

variable "repos" {
  description = "Repositories created empty and private under var.org (a sync job fills them), each with var.protected_branch protected against force-push and deletion."
  type        = list(string)
}

variable "bots" {
  description = <<-EOT
    One Gitea user per entry; the key is the username. Each gets an API token, written to
    <kv_mount>/<kv_path> as {username, token}.
      access      collaborator permission on each of its repos: read, write or admin
      repos       names from var.repos
      scopes      the token's scopes, e.g. ["read:repository"]; changing them replaces the token
      kv_path     where the token goes under var.kv_mount; defaults to providers/gitea-<bot>
      token_name  the token's name in Gitea; changing it replaces the token
  EOT
  type = map(object({
    access     = string
    repos      = list(string)
    scopes     = list(string)
    kv_path    = optional(string)
    token_name = optional(string, "tofu")
  }))

  validation {
    condition     = alltrue([for b in var.bots : contains(["read", "write", "admin"], b.access)])
    error_message = "bots[*].access must be \"read\", \"write\" or \"admin\"."
  }
  validation {
    condition     = alltrue([for b in var.bots : length(setsubtract(b.repos, var.repos)) == 0])
    error_message = "A bot lists a repository that isn't in var.repos."
  }
  # The output kv_paths has the admin's state token under the key tofu-state.
  validation {
    condition     = !contains(keys(var.bots), "tofu-state")
    error_message = "A bot can't be called tofu-state."
  }
  # Two records at one path would overwrite each other.
  validation {
    condition     = length(distinct(concat([for k, b in var.bots : coalesce(b.kv_path, "providers/gitea-${k}")], [var.state_token_kv_path]))) == length(var.bots) + 1
    error_message = "Two tokens would go to the same kv path."
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

variable "protected_branch" {
  description = "The branch protected in every repository of var.repos; openbao-ci's ref must be refs/heads/<this>."
  type        = string
  default     = "main"
}

variable "state_token_name" {
  description = "Name of the admin's state token in Gitea."
  type        = string
  default     = "tofu-state"
}

variable "state_token_kv_path" {
  description = "Where the admin's state token goes under var.kv_mount, as {username, token}."
  type        = string
  default     = "providers/gitea-tofu-state"
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the tokens are written to."
  type        = string
  default     = "kv"
}
