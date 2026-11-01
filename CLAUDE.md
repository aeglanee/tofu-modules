# CLAUDE.md

Reusable OpenTofu modules; the cluster repos (homelab's `terraform/<root>/`) call them from thin
roots pinned to a commit.

- **Follow [README.md § Rules for modules](README.md#rules-for-modules)** for every input,
  default and output: no definitions in a module, conventions as defaults with an override.
- **Match the existing modules:** `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, a
  `README.md` (a minimal example call, the inputs, the conventions and their overrides) and
  `tests/main.tftest.hcl` with every provider mocked. A change to inputs or outputs updates the
  README and the tests in the same commit.
- **Checks**, from the repo root (the dev shell sets `API_DATA_IS_SENSITIVE=true`, which the gitea
  module's tests need):

  ```sh
  nix develop -c tofu -chdir=modules/<module> init   # once per module
  nix develop -c tofu -chdir=modules/<module> test
  nix develop -c pre-commit run --all-files
  ```
