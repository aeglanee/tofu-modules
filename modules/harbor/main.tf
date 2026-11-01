# One proxy-cache project per upstream registry. Pull path: harbor.<domain>/<key>-proxy/<repo>:<tag>.
resource "harbor_registry" "upstream" {
  for_each      = var.registries
  name          = each.key
  provider_name = each.value.provider_name
  endpoint_url  = each.value.endpoint_url
  insecure      = each.value.insecure
}

resource "harbor_project" "proxy" {
  for_each    = var.registries
  name        = "${each.key}-proxy"
  registry_id = harbor_registry.upstream[each.key].registry_id
  public      = true
}

# Push target for charts mirrored in by hand: Harbor 2.x can't proxy an HTTP (index.yaml) Helm
# repo, only OCI.
resource "harbor_project" "helm_charts" {
  name   = "helm-charts"
  public = true
}

# Harbor creates the default "library" project itself; it isn't managed here.
