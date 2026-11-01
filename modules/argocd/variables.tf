variable "readonly_accounts" {
  description = "Argo CD local accounts that get an API token, written to <kv_mount>/apps/<account>/argocd as {token}. Each must already exist in Argo CD (accounts.<name>: apiKey, with a read-only role); only the token is minted here."
  type        = set(string)
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the tokens are written to."
  type        = string
  default     = "kv"
}
