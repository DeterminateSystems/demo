
data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["535002876703"]

  filter {
    name   = "name"
    values = ["determinate/nixos/24.05.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "demo" {
  ami                         = data.aws_ami.nixos.id
  associate_public_ip_address = true
  instance_type               = "t3a.nano"
  vpc_security_group_ids      = [aws_security_group.demo.id]
  key_name                    = one(aws_key_pair.deployer[*].key_name)
  subnet_id                   = aws_subnet.main.id
  iam_instance_profile        = aws_iam_instance_profile.flakehub_client_machine.name
  user_data                   = <<-USERDATA
#!/bin/sh

determinate-nixd login aws

fh apply nixos ${var.flake_reference}
USERDATA


  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "FlakeHubDemo"
  }
}

module "deploy_from_github" {
  count  = var.deploy_from_github ? 1 : 0
  source = "./deploy-from-github"

  github_repo       = var.github_repo
  machine_role_name = aws_iam_role.flakehub_client_machine.name
}
