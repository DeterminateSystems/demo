output "github_actions_assume_role_arn" {
  value = module.oidc_repo_s3.role.arn
}
