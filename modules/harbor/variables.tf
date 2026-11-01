variable "registries" {
  description = <<-EOT
    One entry per upstream registry Harbor proxy-caches; the key names the registry endpoint.
    Images and OCI Helm charts both pull through these.
      provider_name Harbor's registry type: docker-hub, github, docker-registry, ...
      endpoint_url  the upstream's URL
      insecure      skip TLS verification (a plain-HTTP in-cluster endpoint)
      project       the proxy-cache project's name; defaults to <key>-proxy
  EOT
  type = map(object({
    provider_name = string
    endpoint_url  = string
    insecure      = optional(bool, false)
    project       = optional(string)
  }))
}

variable "projects" {
  description = "Public projects that aren't proxy caches: push targets, e.g. for charts from HTTP-only Helm repos (Harbor 2.x proxies OCI only). Empty for none."
  type        = set(string)

  validation {
    condition     = length(distinct(concat([for k, r in var.registries : coalesce(r.project, "${k}-proxy")], tolist(var.projects)))) == length(var.registries) + length(var.projects)
    error_message = "Two projects would have the same name."
  }
}
