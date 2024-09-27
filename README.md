# Continuous NixOS deployments to AWS - *in seconds* 🚀

The project demonstrates how to continuously deploy a NixOS configuration to an AWS EC2 instance using Terraform and [FlakeHub](https://flakehub.com) _in seconds_ ️⏱️

- **The initial deployment completes in _less than 60 seconds_**
- **Subsequent deployments take _less than 10 seconds_**

The deployment process involves fetching a pre-built NixOS closure from [FlakeHub](https://flakehub.com) and applying it to the EC2 instance, streamlining the deployment process and ensuring consistency across deployments.

## Sign-up for the FlakeHub beta

To experience this streamlined NixOS deployment pipeline for yourself, [**sign up for the FlakeHub beta**](https://determinate.systems/) at <https://determinate.systems/>.
FlakeHub provides the enterprise-grade Nix infrastructure needed to fully leverage these advanced deployment techniques, ensuring a secure and efficient path from development to production.

# Introduction

This demonstration project consists of the following key components:

- **Nix Flake configuration**: A Nix flake configuration that defines the NixOS configuration for the deployment target.
- **Terraform configuration**: A Terraform configuration that sets up an AWS EC2 instance and deploys the NixOS configuration using [FlakeHub](https://flakehub.com).
  - **User Data script**: A script that runs on the EC2 instance to authenticate with [FlakeHub](https://flakehub.com) and apply the NixOS configuration.
- **GitHub Actions workflow**: A GitHub Actions workflow that triggers the deployment process using Terraform and [FlakeHub](https://flakehub.com).
  - **Triggering rollbacks**: Demonstrates how to use the `workflow_dispatch` event to manually trigger a workflow run, enabling rollbacks to previous stable states.

## Nix flake

The `flake.nix` sets up a NixOS configuration with specific dependencies and system packages for the demo system.

- **Inputs:** Specifies dependencies from external sources:
  - `nixpkgs`: Nixpkgs flake on FlakeHub.
  - `determinate`: Determinate flake on FlakeHub.
  - `fh`: [FlakeHub client](https://github.com/determinatesystems/fh) flake on FlakeHub.
- **Outputs:** Defines the outputs of the flake:
  - `nixosConfigurations.ethercalc-demo`: A NixOS configuration for the system.
  - Includes modules from `nixpkgs` and `determinate`.
  - Defines system packages, including a package from `fh`.
  - Importantly, **Amazon Simple Service Management (SSM) agent is included** in the system packages

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

## Terraform configuration

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

### User Data script

The `user_data` portion in the aws_instance resource is a script that runs when the EC2 instance is first launched. This script performs the following actions:

- **Login command:** `determinate-nixd login aws`
  - Logs into the Determinate Nix daemon using AWS credentials and sets up the environment for further [FlakeHub](https://flakehub.com) operations.
- **Apply NixOS configuration:** `fh apply nixos ${var.flake_reference}`
  - Uses the [FlakeHub client](https://github.com/determinatesystems/fh) command `fh` to apply a NixOS configuration specified by the `${var.flake_reference}` variable which is defined in the `vars.local.auto.tfvars` file, and points to a specific NixOS flake reference.

This script ensures that the EC2 instance is configured with the necessary NixOS setup as soon as it starts.

The `user_data` steps in the `main.tf` simplify the process of authentication and applying the system configuration in the following ways:

#### Simple authentication

1. **Using `determinate-nixd login aws`**:
   - **Automatic authentication**: The `determinate-nixd login aws` command handles the authentication to the [FlakeHub](https://flakehub.com) cache and sources using AWS credentials. This command abstracts away the complexity of manually managing and sharing credentials.
   - **Security**: By using this command, sensitive AWS credentials do not need to be explicitly shared or embedded in the deployment target. This reduces the risk of credential leakage and simplifies credential management.

`determinate-nixd` authenticates with FlakeHub using the machines' assumed role.
The [only requirement is the machine *have a role*, and for FlakeHub to know what that role is](https://learn.determinate.systems/advanced/log-in-with-aws-sts).
This role grants no privileges until you set `deploy_from_github = true` in `vars.local.auto.tfvars`

#### Simplified & faster deployment

2. **Using `fh apply nixos ${var.flake_reference}`**:
   - **Single Command Application**: The `fh apply nixos` command resolves and applies the NixOS configuration in one step. This command fetches the pre-evaluated NixOS closure referenced by `${var.flake_reference}` and applies it to the system.
   - **Efficiency**: Since the closure is pre-evaluated, the command does not need to perform the evaluation and build steps on the deployment target. This reduces the time and computational resources required for deployment.

## GitHub actions workflow

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

### Continuous deployment

The GitHub Actions workflow is configured to run on multiple events, including `push` to specific branches or tags, and `pull_request`.
This setup enables continuous deployment of the NixOS configuration to the AWS EC2 instance whenever changes are pushed to the repository or a pull request is opened.

Continuous deployments can be demonstrated by toggling the `enable` state of `services.ethercalc` and `services.writefreely` in `flake.nix` and then pushing the changes or submitting a pull request (PR) to GitHub.
This will trigger the GitHub Actions workflow, which will deploy the changes automatically and the changes will be reflected on the AWS EC2 instance with chosen service listening on port 80.

### Triggering rollbacks

The `workflow_dispatch` event in GitHub Actions allows you to manually trigger a workflow run. This can be particularly useful for handling rollbacks, as it enables you to execute a predefined set of steps to revert to a previous stable state of your application.

## Summary

Applying a fully evaluated NixOS closure via [FlakeHub](https://flakehub.com) differs from typical deployments using Nix in several key ways, leading to potential improvements in speed and reliability:

### Pre-evaluation and pre-build
  - **FlakeHub deployment:** The NixOS configuration is evaluated and built ahead of time, resulting in a closure that contains all the necessary dependencies and configurations.
  - **Typical Nix deployment** The evaluation and build process happens during the deployment, which can be time-consuming and error-prone.

### Deployment speed
  - **FlakeHub deployment:** Since the closure is pre-built, and cached, the deployment process is faster. The EC2 instance only needs to download and apply the pre-built closure, reducing the time spent on evaluation and building.
  - **Typical Nix deployment:** The instance, or a deployment host, must evaluate the Nix expressions and build the necessary packages during deployment, which can significantly increase the deployment time.

### Reliability
  - **FlakeHub deployment:** The pre-built closure ensures that the configuration has been tested and verified before deployment. This reduces the risk of runtime errors and inconsistencies.
  - **Typical Nix deployment:** Errors can occur during the evaluation and build process, leading to potential deployment failures or inconsistencies.

### Resource utilization:
  - **FlakeHub deployment:** Offloads the computationally intensive tasks of evaluation and building to a more controlled environment (e.g., a CI/CD pipeline), freeing up resources on the target EC2 instance.
  - **Typical Nix deployment:** The target EC2 instance must handle the evaluation and build process, which can be resource-intensive and may require larger instance types or longer deployment times.

In summary, applying a fully evaluated NixOS closure from [FlakeHub](https://flakehub.com) during deployments ensures that the exact same configuration is deployed every time, as the closure is a fixed, immutable artifact.
It also leads to faster, more reliable, and consistent deployments by pre-evaluating and pre-building the NixOS configuration, thus offloading the heavy lifting from the deployment phase to the build phase.
