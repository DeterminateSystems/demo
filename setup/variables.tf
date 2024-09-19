variable "aws_region" {
  type = string
}

variable "ssh_key" {
  type    = string
  default = ""
}

variable "github_repo" {
  type = string
}

variable "flake_reference" {
  type = string
}

variable "deploy_from_github" {
  type = bool
}
