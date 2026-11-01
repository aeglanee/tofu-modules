# Offline: Harbor is mocked, so this checks what the module would ask for, not that Harbor accepts it.
mock_provider "harbor" {}

variables {
  registries = {
    dockerhub = { provider_name = "docker-hub", endpoint_url = "https://hub.docker.com" }
    shim      = { provider_name = "docker-registry", endpoint_url = "http://chart-proxy.chart-proxy.svc:9000", insecure = true, project = "charts" }
  }
  projects = ["helm-charts"]
}

run "projects" {
  command = apply

  assert {
    condition     = output.proxy_projects == { dockerhub = "dockerhub-proxy", shim = "charts" }
    error_message = "one proxy project per registry, <key>-proxy unless project says otherwise"
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
    condition     = keys(harbor_project.push) == ["helm-charts"] && harbor_project.push["helm-charts"].public
    error_message = "each entry of projects is a public project"
  }
}

run "no_push_projects" {
  command = plan
  variables {
    projects = []
  }
  assert {
    condition     = length(harbor_project.push) == 0
    error_message = "projects may be empty"
  }
}

run "project_names_are_distinct" {
  command = plan
  variables {
    projects = ["dockerhub-proxy"]
  }
  expect_failures = [var.projects]
}
