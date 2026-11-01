variable "gitea_url" {
  description = "Gitea's ROOT_URL, e.g. https://gitea.example.com; the issuer is <gitea_url>/api/actions/oidc."
  type        = string
}

variable "repository" {
  description = "The only repository whose jobs may log in, as <owner>/<name>."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.repository))
    error_message = "repository must be <owner>/<name>."
  }
}

variable "policies" {
  description = <<-EOT
    One role per entry, with a policy of the same name; the key is the role a job logs in as. The
    value maps a path under var.kv_mount (e.g. "data/providers/harbor") to its capabilities (e.g.
    ["read"]).
  EOT
  type        = map(map(list(string)))
}

variable "ref" {
  description = "The only ref whose jobs may log in; it must be a protected branch."
  type        = string
  default     = "refs/heads/main"
}

variable "kv_mount" {
  description = "OpenBao KV v2 mount the policies grant access to."
  type        = string
  default     = "kv"
}
