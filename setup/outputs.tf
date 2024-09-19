output "github_actions_assume_role_arn" {
  value = one(module.deploy_from_github[*].github_actions_assume_role_arn)
}

output "flakehub_organization_allow_arn" {
  # the role's ARN will be like:
  # arn:aws:iam::12345:role/demo/demo_flakehub_access
  #
  # what flakehub will expect is:
  # arn:aws:sts::12345:assumed-role/demo_flakehub_access/i-12345
  value = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.flakehub_client_machine.name}/*"
}

output "website" {
  value = "http://${aws_instance.demo.public_dns}"
}
