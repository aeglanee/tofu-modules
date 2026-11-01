variable "buckets" {
  description = <<-EOT
    One bucket per consumer; the key names the consumer. Each gets its bucket, a key with full
    control of it, and that key in OpenBao as {accessKey, secretKey}.
      bucket   the bucket's global alias; the key is named the same
      kv_path  where the key goes under var.kv_mount; defaults to providers/garage-<consumer>
  EOT
  type = map(object({
    bucket  = string
    kv_path = optional(string)
  }))

  # Two records at one path would overwrite each other.
  validation {
    condition     = length(distinct([for k, b in var.buckets : coalesce(b.kv_path, "providers/garage-${k}")])) == length(var.buckets)
    error_message = "Two consumers' keys would go to the same kv path."
  }
}

variable "kv_mount" {
  description = "OpenBao/Vault KV v2 mount the S3 keys are written to."
  type        = string
  default     = "kv"
}
