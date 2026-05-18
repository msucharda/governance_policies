# Governance Policies OpenTofu

This repository is ready to run OpenTofu CI/CD from GitHub Enterprise Cloud.

## Bootstrap and push

1. Clone the repository and create the remote state backend:

   ```powershell
   .\scripts\create-ghe-oidc-service-principal.ps1 `
     -TenantId "<AZURE_TENANT_ID>" `
     -GitHubEnterpriseSubdomain "<GHE_SUBDOMAIN>" `
     -GitHubOrganization "<GHE_ORGANIZATION>" `
     -GitHubRepository "governance_policies" `
     -GitHubEnvironment "production" `
     -RootManagementGroupId "<SLZ_ROOT_MANAGEMENT_GROUP_ID>" `
     -ManagementSubscriptionId "<MANAGEMENT_SUBSCRIPTION_ID>" `
     -ConnectivitySubscriptionId "<CONNECTIVITY_SUBSCRIPTION_ID>" `
     -CreateBackendStorage `
     -BackendResourceGroupName "rg-opentofu-state" `
     -BackendStorageAccountName "<UNIQUE_STORAGE_ACCOUNT_NAME>" `
     -BackendContainerName "tfstate"
   ```

2. Copy `infra\backend.tf.example` to `infra\backend.tf`, fill it with the backend values printed by the script, and commit it.
3. Provide OpenTofu input values either by committing a reviewed `infra\prod.auto.tfvars` copied from `infra\terraform.tfvars.example`, or by storing the full tfvars content in the GitHub Actions secret `OPENTOFU_TFVARS`. The workflow also accepts `TERRAFORM_TFVARS` for compatibility.
4. Configure GitHub repository or `production` environment variables/secrets from the script output: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`.
5. Push to GHE. `OpenTofu CI` formats and validates; `OpenTofu CD` logs in with OIDC, runs a plan, uploads the plan artifact, and applies from `main`.

The CD workflow uses the GitHub environment `production`. Configure required reviewers on that environment if applies should wait for manual approval.

See `infra\DEPLOYMENT_GUIDE.md` for the full deployment checklist.

