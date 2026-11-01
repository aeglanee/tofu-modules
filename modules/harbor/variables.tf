variable "registries" {
  description = <<-EOT
    One entry per upstream registry Harbor proxy-caches; the key names the registry endpoint and its
    `<key>-proxy` project. Images and OCI Helm charts both pull through these.
      provider_name Harbor's registry type: docker-hub, github, docker-registry, ...
      endpoint_url  the upstream's URL
      insecure      skip TLS verification (a plain-HTTP in-cluster endpoint)
  EOT
  type = map(object({
    provider_name = string
    endpoint_url  = string
    insecure      = optional(bool, false)
  }))
}
