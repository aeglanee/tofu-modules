variable "readonly_accounts" {
  description = <<-EOT
    Argo CD local accounts that get an API token; the key is the account. Each must already exist
    in Argo CD (accounts.<name>: apiKey, with a read-only role); only the token is minted here, and
    written to <kv_mount>/<kv_path> as {token}.
      kv_path  where the token goes under var.kv_mount; defaults to apps/<account>/argocd
  EOT
  type = map(object({
    kv_path = optional(string)
  }))

  # Two records at one path would overwrite each other.
  validation {
    condition     = length(distinct([for k, a in var.readonly_accounts : coalesce(a.kv_path, "apps/${k}/argocd")])) == length(var.readonly_accounts)
    error_message = "Two accounts' tokens would go to the same kv path."
  }
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the tokens are written to."
  type        = string
  default     = "kv"
}
