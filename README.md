# Continuous NixOS deployments to AWS - *in seconds* 🚀

The project demonstrates how to continuously deploy a NixOS configuration to an AWS EC2 instance using Terraform and FlakeHub in seconds ️⏱️

- The initial deployment completes in less than 60 seconds
- Subsequent deployments take less than 10 seconds

The deployment process involves fetching a pre-built NixOS closure from FlakeHub and applying it to the EC2 instance, streamlining the deployment process and ensuring consistency across deployments.

## Sign-up for the FlakeHub Beta

To experience this streamlined NixOS deployment pipeline for yourself, [sign up for the FlakeHub beta](https://determinate.systems/) at <https://determinate.systems/>.
FlakeHub provides the enterprise-grade Nix infrastructure needed to fully leverage these advanced deployment techniques, ensuring a secure and efficient path from development to production.

# Introduction

This demonstration project consists of the following key components:

- **Nix Flake Configuration**: A Nix flake configuration that defines the NixOS configuration for the deployment target.
- **Terraform Configuration**: A Terraform configuration that sets up an AWS EC2 instance and deploys the NixOS configuration using FlakeHub.
  - **User Data Script**: A script that runs on the EC2 instance to authenticate with FlakeHub and apply the NixOS configuration.
- **GitHub Actions Workflow**: A GitHub Actions workflow that triggers the deployment process using Terraform and FlakeHub.
  - **Triggering Rollbacks**: Demonstrates how to use the `workflow_dispatch` event to manually trigger a workflow run, enabling rollbacks to previous stable states.

## Nix Flake

The `flake.nix` sets up a NixOS configuration with specific dependencies and system packages for the demo system.

- **Inputs:** Specifies dependencies from external sources:
  - `nixpkgs`: Nixpkgs flake on FlakeHub.
  - `determinate`: Determinate flake on FlakeHub.
  - `fh`: FlakeHub client flake on FlakeHub.
- **Outputs:** Defines the outputs of the flake:
  - `nixosConfigurations.ethercalc-demo`: A NixOS configuration for the system.
  - Includes modules from `nixpkgs` and `determinate`.
  - Defines system packages, including a package from `fh`.
  - Importantly, Amazon Simple Service Management (SSM) agent is included in the system packages

### Amazon Simple Service Management (SSM) Agent

Deploying NixOS AMIs using Amazon SSM agent from GitHub Actions offers several advantages over traditional SSH-based deployments, especially for enterprise environments prioritizing security and automation:

- **Enhanced security:**
  - No need to expose SSH ports, reducing attack surface
  - Eliminates management of SSH keys
  - Leverages AWS IAM for access control
- **Improved compliance:**
  - Centralized logging of all actions through AWS CloudTrail
  - Easier to meet regulatory requirements with built-in audit trails
- **Streamlined operations:**
  - Consistent management interface across EC2 instances
  - Simplified access for operations teams without direct SSH access
- **Automation-friendly:**
  - Native integration with other AWS services
  - Easier to incorporate into CI/CD pipelines and GitOps workflows
- **Scalability:**
  - Better suited for managing large fleets of instances
  - Reduces operational overhead as infrastructure grows
- **Increased reliability:**
  - SSM agent can automatically update itself
  - More resilient to network issues than SSH
- **Fine-grained access control:**
  - Ability to grant temporary, limited access to specific instances
  - Easier to implement principle of least privilege

By leveraging SSM and GitHub Actions, enterprises can create a more secure, compliant, and efficient deployment pipeline for NixOS AMIs, aligning with best practices for cloud operations and security.

## Terraform Configuration

The `main.tf` file is a Terraform configuration that sets up an AWS EC2 instance with the following components:

- *Data Source:* `aws_ami.nixos`
  - Fetches the most recent AMI owned by Determinate Systems (535002876703) with the name pattern determinate/nixos/24.05.* and architecture x86_64.
- *Resource:* `aws_instance.demo`
  - Creates an EC2 instance using the fetched AMI.
  - Configures the instance with:
    - Public IP address association.
    - Instance type `t3a.nano`.
    - Security group ID from aws_security_group.demo.
    - Key name from aws_key_pair.deployer.
    - Subnet ID from aws_subnet.main.
    - IAM instance profile `flakehub_client_machine`.
    - User data script for initialization.

### User Data Script

The `user_data` portion in the aws_instance resource is a script that runs when the EC2 instance is first launched. This script performs the following actions:

- **Login Command:** `determinate-nixd login aws`
  - Logs into the Determinate Nix daemon using AWS credentials and sets up the environment for further FlakeHub operations.
- **Apply NixOS Configuration:** `fh apply nixos ${var.flake_reference}`
  - Uses the FlakeHub client command `fh` to apply a NixOS configuration specified by the `${var.flake_reference}` variable which is defined in the `vars.local.auto.tfvars` file, and points to a specific NixOS flake reference.

This script ensures that the EC2 instance is configured with the necessary NixOS setup as soon as it starts.

The `user_data` steps in the `main.tf` file simplify the process of authentication and configuration application in the following ways:

#### Simplified Authentication

1. **Using `determinate-nixd login aws`**:
   - **Automatic Authentication**: The `determinate-nixd login aws` command handles the authentication to the FlakeHub cache and sources using AWS credentials. This command abstracts away the complexity of manually managing and sharing credentials.
   - **Security**: By using this command, sensitive AWS credentials do not need to be explicitly shared or embedded in the deployment target. This reduces the risk of credential leakage and simplifies credential management.

`determinate-nixd` authenticates with FlakeHub using the machines' assumed role.
The [only requirement is the machine *have a role*, and for FlakeHub to know what that role is](https://learn.determinate.systems/advanced/log-in-with-aws-sts).
This role grants no privileges until you set `deploy_from_github = true` in `vars.local.auto.tfvars`

#### Simplified Configuration Application

2. **Using `fh apply nixos ${var.flake_reference}`**:
   - **Single Command Application**: The `fh apply nixos` command resolves and applies the NixOS configuration in one step. This command fetches the pre-evaluated NixOS closure referenced by `${var.flake_reference}` and applies it to the system.
   - **Efficiency**: Since the closure is pre-evaluated, the command does not need to perform the evaluation and build steps on the deployment target. This reduces the time and computational resources required for deployment.
   - **Consistency**: Applying a pre-evaluated closure ensures that the exact same configuration is deployed every time, leading to consistent and predictable system states.

### Summary

- **Authentication**: The `determinate-nixd login aws` command simplifies authentication by using AWS credentials directly, avoiding the need to manually manage and share S3 credentials.
- **Configuration Application**: The `fh apply nixos` command resolves and applies the NixOS configuration in one step, leveraging pre-evaluated closures for faster and more consistent deployments.

These steps streamline the deployment process, enhance security, and ensure reliable and efficient application of the NixOS configuration.

## GitHub Actions Workflow

This `.github/workflows/ci.yml` workflow is configured to run on three types of events: `pull_request`, `workflow_dispatch`, and `push` to specific branches (`main` and `master`) or tags matching a version pattern (`v?[0-9]+.[0-9]+.[0-9]+*`).

Checks out the repository using `actions/checkout@v4` and installs Nix using `DeterminateSystems/nix-installer-action@main` with `flakehubpush` enabled so the outputs are cached.

The `Deploy` step in the GitHub Actions workflow is responsible for deploying the application to AWS. Here's a breakdown of what it does:

- **Configure AWS Credentials**:
  - Uses the `aws-actions/configure-aws-credentials@v4` action to configure AWS credentials.
  - Specifies the AWS region (`us-east-2`) and the IAM role to assume (`arn:aws:iam::194722411868:role/github-actions/FlakeHubDeployDemo`).

- **Deploy Ethercalc**:
  - Runs an AWS Systems Manager (SSM) command to deploy the application.
  - Uses the `aws ssm send-command` command to send a command to instances tagged with `Name=FlakeHubDemo`.
  - Specifies the SSM document name (`FlakeHub-ApplyNixOS`) and passes the `flakeref` parameter, which includes the exact flake reference from the `BuildPublish` job's output.

### Triggering Rollbacks

The `workflow_dispatch` event in GitHub Actions allows you to manually trigger a workflow run. This can be particularly useful for handling rollbacks, as it enables you to execute a predefined set of steps to revert to a previous stable state of your application.
