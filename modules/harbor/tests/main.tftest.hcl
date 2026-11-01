# Offline: Harbor is mocked, so this checks what the module would ask for, not that Harbor accepts it.
mock_provider "harbor" {}

variables {
  registries = {
    dockerhub = { provider_name = "docker-hub", endpoint_url = "https://hub.docker.com" }
    shim      = { provider_name = "docker-registry", endpoint_url = "http://chart-proxy.chart-proxy.svc:9000", insecure = true }
  }
}

run "projects" {
  command = apply

  assert {
    condition     = output.proxy_projects == { dockerhub = "dockerhub-proxy", shim = "shim-proxy" }
    error_message = "one <key>-proxy project per registry"
  }
  assert {
    condition     = harbor_registry.upstream["shim"].insecure && !harbor_registry.upstream["dockerhub"].insecure
    error_message = "insecure defaults to false"
  }
  assert {
    condition     = harbor_project.proxy["dockerhub"].registry_id == harbor_registry.upstream["dockerhub"].registry_id
    error_message = "each proxy project caches its own registry"
  }
  assert {
    condition     = harbor_project.helm_charts.name == "helm-charts"
    error_message = "the helm-charts push target exists"
  }
}
