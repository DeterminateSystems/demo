# Determinate-nixd authenticates with FlakeHub using the machines' assumed role.
#
# The only requirement is the machine *have a role*, and for FlakeHub to know what that role is.
#
# This role grants no privileges until you set "deploy_from_github = true" in ./vars.local.auto.tfvars

resource "aws_iam_role" "flakehub_client_machine" {
  name               = "FlakeHubClientMachine"
  path               = "/demo/"
  assume_role_policy = data.aws_iam_policy_document.flakehub_client_machine_assume_role_policy.json
}

resource "aws_iam_instance_profile" "flakehub_client_machine" {
  name = "FlakeHubClientMachine"
  role = aws_iam_role.flakehub_client_machine.name
}

data "aws_iam_policy_document" "flakehub_client_machine_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
