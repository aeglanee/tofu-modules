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

# Push targets for what Harbor can't proxy, such as charts mirrored in by hand from an HTTP
# (index.yaml) Helm repo: Harbor 2.x proxies OCI only.
resource "harbor_project" "push" {
  for_each = var.projects
  name     = each.key
  public   = true
}

# Harbor creates the default "library" project itself; it isn't managed here.
