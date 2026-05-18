# Deployment Guide: SLZ Governance Policies and Management Resources

This Terraform configuration deploys shared management resources, creates Private DNS zones in the connectivity subscription, and applies Sovereign Landing Zone (SLZ) policy assignments to management groups that already exist.

## What this deploys

| Scope | Resources |
|---|---|
| Management subscription | Management resource group, Log Analytics workspace, Automation Account, AMA user-assigned managed identity, Data Collection Rules, Service Health resource group, Defender for Cloud export resource group |
| Connectivity subscription | Private DNS resource group and Private DNS zones from `private_dns_zone_names` |
| Existing management groups | SLZ/ALZ policy definitions, initiatives, policy assignments, policy managed identities, policy role assignments, and optional subscription placement |

The management group hierarchy itself is not created. The local SLZ architecture file marks all management groups as `exists: true`.

## Key assumptions

1. The SLZ management groups already exist.
2. The default management group IDs are `slz`, `platform`, `landingzones`, `public`, `corp`, `online`, `local`, `confidential_corp`, `confidential_online`, `sandbox`, `security`, `management`, `connectivity`, `identity`, and `decommissioned`.
3. If your actual management group IDs differ, update `terraform.tfvars` where variables exist and update `lib\architecture_definitions\slz_existing.alz_architecture_definition.yaml`.
4. The upstream library is `platform/slz` and it brings in standard ALZ policy definitions through its dependency on `platform/alz`.
5. `allowed_locations` is required. It feeds the SLZ L1 data residency policy `Enforce-Sov-L1-Regions`.
6. The Terraform identity has permission to create resources in the management and connectivity subscriptions.
7. The Terraform identity has permission to create policy assignments and role assignments at the SLZ management group scopes.
8. `enable_subscription_placement = true` means Terraform will manage placement of platform subscriptions under the configured management groups.

## Required parameters

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill these values:

| Parameter | Required | Description |
|---|---:|---|
| `management_subscription_id` | Yes | Subscription that will host Log Analytics, Automation, DCRs, AMA UAMI, Service Health RG, and MDFC export RG. |
| `connectivity_subscription_id` | Yes | Subscription that will host the Private DNS zones. |
| `parent_management_group_id` | Yes | Parent of the existing SLZ root management group. Use the tenant ID if `slz` is directly under the tenant root group. |
| `architecture_name` | Yes | Must match `name:` in `lib\architecture_definitions\slz_existing.alz_architecture_definition.yaml`; default is `slz_existing`. |
| `security_contact_email` | Yes | Email passed to Defender for Cloud policy parameters. |
| `allowed_locations` | Yes | Azure regions allowed by SLZ L1 data residency controls, for example `["westeurope", "northeurope"]`. |
| `private_dns_zone_virtual_network_id` | Yes | Resource ID of the hub or shared services VNet to link to every Private DNS zone. |
| `location` | Yes | Azure region for management resources and policy assignment managed identities. |
| `location_short` | Yes | Short region token used in generated names, for example `weu`. |
| `prefix` | Yes | Naming prefix used for generated resource names, for example `rlp`. |

## Management group parameters

These values must match the real Azure management group IDs, not display names:

| Parameter | Default | Notes |
|---|---|---|
| `root_management_group_id` | `slz` | Root SLZ management group where root and sovereign L1 policies are assigned. |
| `platform_management_group_id` | `platform` | Parent of management/connectivity/identity/security. |
| `landing_zones_management_group_id` | `landingzones` | Parent of public/corp/online/local/confidential landing zones. |
| `corp_management_group_id` | `corp` | Private/corporate landing zones; receives Private DNS policy assignment and sovereign L2 controls. |
| `management_management_group_id` | `management` | Hosts the management subscription when subscription placement is enabled; receives sovereign L2 controls. |
| `connectivity_management_group_id` | `connectivity` | Hosts the connectivity subscription when subscription placement is enabled; receives sovereign L2 controls. |
| `identity_management_group_id` | `identity` | Hosts the optional identity subscription; receives sovereign L2 controls. |
| `security_management_group_id` | `security` | Hosts the optional security subscription; receives sovereign L2 controls. |

The SLZ-only IDs `public`, `confidential_corp`, and `confidential_online` are defined directly in `lib\architecture_definitions\slz_existing.alz_architecture_definition.yaml`. Update the YAML if your existing IDs use hyphens, prefixes, or other naming conventions.

## SLZ hierarchy modeled by the YAML

The local architecture applies:

| Management group | Archetypes |
|---|---|
| `slz` | `root`, `sovereign_l1_controls` |
| `corp`, `online`, `security`, `management`, `connectivity`, `identity` | Base ALZ archetype plus `sovereign_l2_controls` |
| `confidential_corp`, `confidential_online` | Base workload archetype plus `sovereign_l2_controls` and `sovereign_l3_controls` |
| `public` | `public` |
| `platform`, `landingzones`, `local`, `sandbox`, `decommissioned` | Standard ALZ archetypes from the SLZ library dependency |

## Optional parameters

| Parameter | Default | When to change |
|---|---|---|
| `identity_subscription_id` | `null` | Set if an identity subscription should be placed under the identity management group. |
| `security_subscription_id` | `null` | Set if a security subscription should be placed under the security management group. |
| `enable_subscription_placement` | `true` | Set to `false` if subscription placement is managed elsewhere. |
| `ddos_protection_plan_id` | `null` | Set to an existing DDoS plan resource ID to enable `Enable-DDoS-VNET`. If left null, DDoS policy assignments are skipped. |
| `enable_defender_plans` | `true` | Set to `false` if you do not want this scaffold to enable Defender plan policy parameters. |
| `private_dns_zone_names` | Default list | Add or remove Private DNS zones based on required private endpoint services. |
| `private_dns_zone_virtual_network_link_name_prefix` | `vnet-link` | Change only if the default link name prefix conflicts with naming standards. |
| `create_private_dns_policy_role_assignment` | `true` | Set to `false` if you want to assign Network Contributor for `Deploy-Private-DNS-Zones` manually. |
| `preventive_policy_assignments_audit_mode_enabled` | `true` | Keeps known Deny, DenyAction, and Enforce policy assignments in `DoNotEnforce` mode for brownfield rollout. |
| `enable_telemetry` | `false` | Set to `true` if AVM module telemetry is acceptable. |
| `tags` | `{}` | Add customer or operational tags. |

All resource-name override variables are optional. If left null, names are generated from `prefix` and `location_short`.

## Files to review before deployment

| File | Purpose |
|---|---|
| `providers.tf` | Provider versions and subscription aliases. |
| `main.tf` | Resource creation, policy defaults, policy assignment modifications, and SLZ module calls. |
| `variables.tf` | Input parameters and defaults. |
| `terraform.tfvars.example` | Copy this to `prod.auto.tfvars` for committed non-secret inputs, or use it as the template for the `TERRAFORM_TFVARS` secret. |
| `backend.tf.example` | Copy to `backend.tf`, fill with Azure Storage remote state values, and commit for GitHub Actions. |
| `..\scripts\create-ghe-oidc-service-principal.ps1` | Azure CLI script to create the GitHub Enterprise Cloud OIDC service principal, RBAC assignments, and optionally the remote state backend. |
| `lib\alz_library_metadata.json` | Pins the upstream SLZ library reference. |
| `lib\architecture_definitions\slz_existing.alz_architecture_definition.yaml` | Existing SLZ management group structure used by the ALZ provider. |

## Deployment steps

From the repository root in PowerShell, prepare the Terraform input values:

```powershell
Copy-Item .\infra\terraform.tfvars.example .\infra\prod.auto.tfvars
```

Edit `infra\prod.auto.tfvars` and fill the real values. Commit this file only if it contains no secrets and has been approved for source control. Otherwise, store the full tfvars content in the GitHub Actions secret `TERRAFORM_TFVARS`; the CD workflow writes it to `terraform.tfvars` at runtime.

Prepare the remote state backend:

```powershell
Copy-Item .\infra\backend.tf.example .\infra\backend.tf
```

Edit `infra\backend.tf` with the real Terraform state resource group, storage account, container, and key. Commit this file so GitHub Actions can initialize the same backend.

## GitHub Enterprise Cloud OIDC service principal

Use the helper script from an admin workstation to create the Entra app registration, service principal, federated identity credential, Azure RBAC assignments for GitHub Actions, and optionally the Azure Storage remote state backend:

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
  -BackendResourceGroupName "rg-terraform-state" `
  -BackendStorageAccountName "<UNIQUE_STORAGE_ACCOUNT_NAME>" `
  -BackendContainerName "tfstate"
```

For GHE.com, the default issuer is `https://token.actions.<GHE_SUBDOMAIN>.ghe.com`. If the enterprise uses a custom OIDC issuer with an enterprise slug, pass `-OidcIssuer "https://token.actions.<GHE_SUBDOMAIN>.ghe.com/<ENTERPRISE_SLUG>"`.

The script assigns:

1. `Management Group Contributor`, `Resource Policy Contributor`, and `User Access Administrator` at the SLZ root management group scope.
2. `Contributor` and `User Access Administrator` on the management and connectivity subscriptions.
3. The same subscription roles on any values passed through `-AdditionalSubscriptionIds`.
4. When `-CreateBackendStorage` is used, `Storage Blob Data Contributor` on the Terraform state container.

In GitHub Actions, configure the values printed by the script as repository variables, repository secrets, or `production` environment variables/secrets:

| Name | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | Entra application/client ID used by OIDC. |
| `AZURE_TENANT_ID` | Azure tenant ID. |
| `AZURE_SUBSCRIPTION_ID` | Management subscription used as the default Azure context. |
| `TERRAFORM_TFVARS` | Optional secret containing the full tfvars content when no committed `*.auto.tfvars` file is used. |

The CD workflow uses the GitHub environment `production`, so the federated credential subject must be `repo:<org>/<repo>:environment:production`. Configure required reviewers on the GitHub environment if applies should wait for approval.

## GitHub Actions workflows

| Workflow | Trigger | Behavior |
|---|---|---|
| `Terraform CI` | Pull requests, pushes to `main`, and manual dispatch | Runs `terraform fmt -check`, `terraform init -backend=false`, and `terraform validate`. |
| `Terraform CD` | Pushes to `main` and manual dispatch | Uses GitHub OIDC through `azure/login`, initializes the committed remote backend, creates a plan artifact, and applies when triggered from `main` or when manual input `apply` is true. |

No client secret is required. The workflow sets `ARM_USE_OIDC=true` for Terraform provider and backend authentication.

## Local validation

Then run:

```powershell
Set-Location -Path .\infra
terraform init -backend=false
terraform fmt -recursive
terraform validate
```

To run a local plan or apply against the remote backend, sign in with Azure CLI using an identity that has management-plane access to the target scopes and `Storage Blob Data Contributor` on the state container, then run:

```powershell
terraform init
terraform plan -out governance-policies.tfplan
terraform apply governance-policies.tfplan
```

## Plan review checklist

Before applying, confirm:

1. Terraform is not trying to create or replace management groups.
2. Policy assignments target the expected SLZ management group IDs.
3. Preventive Deny, DenyAction, and Enforce assignments show `enforcementMode = DoNotEnforce` when `preventive_policy_assignments_audit_mode_enabled = true`.
4. `Enforce-Sov-L1-Regions` receives the intended `allowed_locations`.
5. Sovereign L2 controls appear on the expected platform and workload management groups.
6. Sovereign L3 controls appear only on the confidential management groups.
7. The management subscription receives only management resources.
8. The connectivity subscription receives only the Private DNS RG, zones, and VNet links.
9. `Enable-DDoS-VNET` is skipped if `ddos_protection_plan_id = null`.
10. `Deploy-Private-DNS-Zones` is present at the Corp management group if private DNS policy is required.
11. Subscription placement changes are expected, or `enable_subscription_placement` is set to `false`.
12. No unexpected role assignments are created outside the SLZ scopes or Private DNS resource group.

## Important cautions

- Do not apply until the management group IDs in `terraform.tfvars` and the YAML architecture file match Azure exactly.
- `preventive_policy_assignments_audit_mode_enabled = true` uses Azure Policy assignment `DoNotEnforce`, which evaluates compliance without blocking creates or updates. After reviewing compliance, set it to `false` or override individual assignments to `Default` in a controlled rollout.
- `allowed_locations` is mandatory for SLZ. An incorrect or incomplete list can block deployments in required regions.
- `create_private_dns_policy_role_assignment = true` expects the policy identity output key `corp/Deploy-Private-DNS-Zones`. If the policy assignment name or Corp management group ID differs, set this to `false` and create the role assignment manually.
- If Private DNS zones already exist, either import them into Terraform state or remove them from `private_dns_zone_names` before applying.
- If Private DNS zones are already linked to the target VNet, import the `azurerm_private_dns_zone_virtual_network_link` resources before applying.
- If management resources already exist, align the override names to the existing resources and import them, or Terraform will try to create duplicates.
- Keep `.alzlib/` out of source control; it is a provider cache.
