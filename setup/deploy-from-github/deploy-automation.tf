data "aws_caller_identity" "current" {}

resource "aws_ssm_document" "deploy" {
  name = "FlakeHub-ApplyNixOS"

  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Deploy NixOS with FlakeHub Apply"
    parameters = {
      flakeref = {
        type           = "String"
        description    = "The FlakeHub flake reference. Example: DeterminateSystems/demo/0.1#nixosConfigurations.ethercalc-demo"
        allowedPattern = join("", [
          # Owner/Flake/
          "^[a-zA-Z0-9\\-_]+\\/[a-zA-Z0-9\\-_]+",
          # /
          "\\/",
          # Version specifier
          "[a-zA-Z0-9\\-_.+=~*]+",
          # literal #
          "#",
          # attribute path
          "([a-zA-Z0-9\\-_]+\\.?)+$"])
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "FlakeHubApplyNixOS"
        inputs = {
          runCommand = [
            "fh apply nixos {{flakeref}}"
          ]
        }
      }
    ]
  })
}

module "oidc_provider" {
  source = "github.com/philips-labs/terraform-aws-github-oidc?ref=v0.8.1//modules/provider"

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

module "oidc_repo_s3" {
  source = "github.com/philips-labs/terraform-aws-github-oidc?ref=v0.8.1"

  openid_connect_provider_arn = module.oidc_provider.openid_connect_provider.arn
  repo                        = var.github_repo
  role_name                   = "FlakeHubDeployDemo"
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = module.oidc_repo_s3.role.name
  policy_arn = aws_iam_policy.ssm_fh_apply_command.arn
}

resource "aws_iam_policy" "ssm_fh_apply_command" {
  name        = "AllowFlakeHubDeployDemo"
  path        = "/"
  description = "Allow deploying to NixOS machines with FlakeHub and SSM"

  policy = data.aws_iam_policy_document.ssm_fh_apply_command.json
}

data "aws_iam_policy_document" "ssm_fh_apply_command" {
  statement {
    sid = "AllowRunFlakeHubApplyNixOSDocument"

    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      aws_ssm_document.deploy.arn,
    ]
  }

  statement {
    sid = "AllowFlakeHubApplyNixOSOnInstances"

    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Name"
      values   = ["FlakeHubDemo"]
    }

  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = var.machine_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
