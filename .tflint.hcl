# tflint's own rules for the Terraform language (unused declarations, untyped variables, missing
# version constraints, deprecated syntax). CI: .gitea/workflows/validate.yml; locally:
# tflint --recursive --config "$PWD/.tflint.hcl"
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
