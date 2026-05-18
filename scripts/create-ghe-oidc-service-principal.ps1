<#
.SYNOPSIS
Creates the Entra service principal used by GitHub Enterprise Cloud (GHE.com)
GitHub Actions to deploy this SLZ Terraform configuration.

.DESCRIPTION
The script uses Azure CLI to:
1. Create or reuse a Microsoft Entra application registration.
2. Create or reuse its service principal.
3. Add a federated identity credential for GitHub Actions OIDC from GHE.com.
4. Assign the Azure RBAC roles required by the Terraform deployment.

No client secret is created. Authentication from GitHub Actions should use OIDC.

Prerequisites for the operator running this script:
- Azure CLI is installed and logged in with az login.
- Permission to create app registrations in the tenant, or an existing app object.
- Owner, User Access Administrator, or equivalent role assignment permission at
  the target management group and subscription scopes.

For GHE.com, the default issuer is:
https://token.actions.<GHE_SUBDOMAIN>.ghe.com

If your enterprise enabled a custom issuer with an enterprise slug, override
-OidcIssuer with:
https://token.actions.<GHE_SUBDOMAIN>.ghe.com/<ENTERPRISE_SLUG>
#>

[CmdletBinding()]
param(
    [string]$TenantId = "<AZURE_TENANT_ID>",

    [string]$AppDisplayName = "sp-governance-policies-terraform-ghe",

    [string]$GitHubEnterpriseSubdomain = "<GHE_SUBDOMAIN>",

    [string]$GitHubOrganization = "<GHE_ORGANIZATION>",

    [string]$GitHubRepository = "governance_policies",

    [string]$GitHubBranch = "main",

    # Default matches .github/workflows/terraform-cd.yml. Set to an empty string
    # to use the branch subject instead:
    # repo:<org>/<repo>:environment:<environment>
    [string]$GitHubEnvironment = "production",

    # Optional explicit subject. Use this for custom GHE OIDC subject templates.
    [string]$FederatedSubject = "",

    # Optional explicit issuer. If blank, the script uses the GHE.com issuer from
    # GitHubEnterpriseSubdomain.
    [string]$OidcIssuer = "",

    [string]$FederatedCredentialName = "",

    [string]$Audience = "api://AzureADTokenExchange",

    [string]$RootManagementGroupId = "<SLZ_ROOT_MANAGEMENT_GROUP_ID>",

    [string]$ManagementSubscriptionId = "<MANAGEMENT_SUBSCRIPTION_ID>",

    [string]$ConnectivitySubscriptionId = "<CONNECTIVITY_SUBSCRIPTION_ID>",

    # Add identity/security or other subscriptions if Terraform will place or manage them.
    [string[]]$AdditionalSubscriptionIds = @(
        # "<IDENTITY_SUBSCRIPTION_ID>",
        # "<SECURITY_SUBSCRIPTION_ID>"
    ),

    # Optional: create the Azure Storage backend used by Terraform remote state.
    [switch]$CreateBackendStorage,

    # Defaults to ManagementSubscriptionId when omitted.
    [string]$BackendSubscriptionId = "",

    [string]$BackendResourceGroupName = "",

    [string]$BackendStorageAccountName = "",

    [string]$BackendContainerName = "tfstate",

    [string]$BackendLocation = "westeurope",

    [string]$BackendStateKey = "governance-policies.tfstate",

    [switch]$SkipBackendRoleAssignment,

    [switch]$SkipManagementGroupRoleAssignments,

    [switch]$SkipSubscriptionRoleAssignments
)

$ErrorActionPreference = "Stop"

function Test-IsPlaceholder {
    param([string]$Value)

    return [string]::IsNullOrWhiteSpace($Value) -or $Value.Trim().StartsWith("<")
}

function Assert-ConfiguredValue {
    param(
        [string]$Name,
        [string]$Value
    )

    if (Test-IsPlaceholder -Value $Value) {
        throw "Set the $Name parameter before running this script."
    }
}

function ConvertTo-FederatedCredentialName {
    param([string]$Value)

    $safeName = ($Value -replace "[^A-Za-z0-9-]", "-").Trim("-")
    if ($safeName.Length -gt 120) {
        return $safeName.Substring(0, 120).Trim("-")
    }

    return $safeName
}

function Invoke-Az {
    param([string[]]$Arguments)

    $output = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')`n$output"
    }

    return $output
}

function Get-AzJson {
    param([string[]]$Arguments)

    $json = Invoke-Az -Arguments ($Arguments + @("--only-show-errors", "-o", "json"))
    $jsonText = ($json | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return $null
    }

    return $jsonText | ConvertFrom-Json
}

function Get-AzJsonOrNull {
    param([string[]]$Arguments)

    $json = & az @($Arguments + @("--only-show-errors", "-o", "json")) 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $jsonText = ($json | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return $null
    }

    return $jsonText | ConvertFrom-Json
}

function Ensure-RoleAssignment {
    param(
        [string]$ServicePrincipalObjectId,
        [string]$RoleName,
        [string]$Scope
    )

    $existingAssignmentId = & az role assignment list `
        --assignee $ServicePrincipalObjectId `
        --role $RoleName `
        --scope $Scope `
        --query "[0].id" `
        --only-show-errors `
        -o tsv 2>$null

    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingAssignmentId)) {
        Write-Host "Role assignment already exists: $RoleName at $Scope"
        return
    }

    Write-Host "Creating role assignment: $RoleName at $Scope"
    Invoke-Az -Arguments @(
        "role", "assignment", "create",
        "--assignee-object-id", $ServicePrincipalObjectId,
        "--assignee-principal-type", "ServicePrincipal",
        "--role", $RoleName,
        "--scope", $Scope,
        "--only-show-errors"
    ) | Out-Null
}

function Ensure-BackendStorage {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$Location
    )

    Write-Host "Ensuring Terraform state backend storage in subscription: $SubscriptionId"
    Invoke-Az -Arguments @("account", "set", "--subscription", $SubscriptionId, "--only-show-errors") | Out-Null

    $resourceGroup = Get-AzJsonOrNull -Arguments @(
        "group", "show",
        "--name", $ResourceGroupName
    )

    if ($null -eq $resourceGroup) {
        Write-Host "Creating resource group for Terraform state: $ResourceGroupName"
        Invoke-Az -Arguments @(
            "group", "create",
            "--name", $ResourceGroupName,
            "--location", $Location,
            "--only-show-errors"
        ) | Out-Null
    }
    else {
        Write-Host "Reusing resource group for Terraform state: $ResourceGroupName"
    }

    $storageAccount = Get-AzJsonOrNull -Arguments @(
        "storage", "account", "show",
        "--resource-group", $ResourceGroupName,
        "--name", $StorageAccountName
    )

    if ($null -eq $storageAccount) {
        Write-Host "Creating storage account for Terraform state: $StorageAccountName"
        Invoke-Az -Arguments @(
            "storage", "account", "create",
            "--resource-group", $ResourceGroupName,
            "--name", $StorageAccountName,
            "--location", $Location,
            "--sku", "Standard_LRS",
            "--kind", "StorageV2",
            "--https-only", "true",
            "--min-tls-version", "TLS1_2",
            "--allow-blob-public-access", "false",
            "--only-show-errors"
        ) | Out-Null
    }
    else {
        Write-Host "Reusing storage account for Terraform state: $StorageAccountName"
    }

    $storageAccount = Get-AzJson -Arguments @(
        "storage", "account", "show",
        "--resource-group", $ResourceGroupName,
        "--name", $StorageAccountName
    )

    Write-Host "Ensuring Terraform state container exists: $ContainerName"
    if ($storageAccount.allowSharedKeyAccess -eq $false) {
        Invoke-Az -Arguments @(
            "storage", "container", "create",
            "--account-name", $StorageAccountName,
            "--name", $ContainerName,
            "--auth-mode", "login",
            "--only-show-errors"
        ) | Out-Null
    }
    else {
        $storageKey = Invoke-Az -Arguments @(
            "storage", "account", "keys", "list",
            "--resource-group", $ResourceGroupName,
            "--account-name", $StorageAccountName,
            "--query", "[0].value",
            "-o", "tsv",
            "--only-show-errors"
        )
        $storageKeyText = ($storageKey | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($storageKeyText)) {
            throw "Could not retrieve a storage account key to create the Terraform state container."
        }

        Invoke-Az -Arguments @(
            "storage", "container", "create",
            "--account-name", $StorageAccountName,
            "--account-key", $storageKeyText,
            "--name", $ContainerName,
            "--only-show-errors"
        ) | Out-Null
    }

    Write-Host "Disabling shared key access for Terraform state storage account."
    Invoke-Az -Arguments @(
        "storage", "account", "update",
        "--resource-group", $ResourceGroupName,
        "--name", $StorageAccountName,
        "--allow-shared-key-access", "false",
        "--only-show-errors"
    ) | Out-Null

    return "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName/blobServices/default/containers/$ContainerName"
}

Assert-ConfiguredValue -Name "TenantId" -Value $TenantId
Assert-ConfiguredValue -Name "GitHubEnterpriseSubdomain" -Value $GitHubEnterpriseSubdomain
Assert-ConfiguredValue -Name "GitHubOrganization" -Value $GitHubOrganization
Assert-ConfiguredValue -Name "GitHubRepository" -Value $GitHubRepository
Assert-ConfiguredValue -Name "RootManagementGroupId" -Value $RootManagementGroupId
Assert-ConfiguredValue -Name "ManagementSubscriptionId" -Value $ManagementSubscriptionId
Assert-ConfiguredValue -Name "ConnectivitySubscriptionId" -Value $ConnectivitySubscriptionId

if (Test-IsPlaceholder -Value $BackendSubscriptionId) {
    $BackendSubscriptionId = $ManagementSubscriptionId
}

if ($CreateBackendStorage) {
    Assert-ConfiguredValue -Name "BackendSubscriptionId" -Value $BackendSubscriptionId
    Assert-ConfiguredValue -Name "BackendResourceGroupName" -Value $BackendResourceGroupName
    Assert-ConfiguredValue -Name "BackendStorageAccountName" -Value $BackendStorageAccountName
    Assert-ConfiguredValue -Name "BackendContainerName" -Value $BackendContainerName
    Assert-ConfiguredValue -Name "BackendLocation" -Value $BackendLocation
    Assert-ConfiguredValue -Name "BackendStateKey" -Value $BackendStateKey
}

if (Test-IsPlaceholder -Value $OidcIssuer) {
    $OidcIssuer = "https://token.actions.$GitHubEnterpriseSubdomain.ghe.com"
}

if (Test-IsPlaceholder -Value $FederatedSubject) {
    if (-not (Test-IsPlaceholder -Value $GitHubEnvironment)) {
        $FederatedSubject = "repo:$GitHubOrganization/$GitHubRepository:environment:$GitHubEnvironment"
    }
    else {
        Assert-ConfiguredValue -Name "GitHubBranch" -Value $GitHubBranch
        $FederatedSubject = "repo:$GitHubOrganization/$GitHubRepository:ref:refs/heads/$GitHubBranch"
    }
}

if (Test-IsPlaceholder -Value $FederatedCredentialName) {
    $federatedCredentialScope = if (-not (Test-IsPlaceholder -Value $GitHubEnvironment)) {
        "env-$GitHubEnvironment"
    }
    else {
        "branch-$GitHubBranch"
    }

    $FederatedCredentialName = ConvertTo-FederatedCredentialName `
        -Value "ghe-$GitHubOrganization-$GitHubRepository-$federatedCredentialScope"
}

Write-Host "Using tenant: $TenantId"
Invoke-Az -Arguments @("login", "--tenant", $TenantId, "--only-show-errors") | Out-Null

$app = Get-AzJson -Arguments @(
    "ad", "app", "list",
    "--display-name", $AppDisplayName,
    "--query", "[0].{appId:appId,id:id,displayName:displayName}"
)

if ($null -eq $app -or [string]::IsNullOrWhiteSpace($app.appId)) {
    Write-Host "Creating app registration: $AppDisplayName"
    $app = Get-AzJson -Arguments @(
        "ad", "app", "create",
        "--display-name", $AppDisplayName,
        "--sign-in-audience", "AzureADMyOrg",
        "--query", "{appId:appId,id:id,displayName:displayName}"
    )
}
else {
    Write-Host "Reusing app registration: $($app.displayName)"
}

$appId = $app.appId

$spJsonOutput = & az ad sp show --id $appId --query "{id:id,appId:appId,displayName:displayName}" --only-show-errors -o json 2>$null
$spJson = ($spJsonOutput | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($spJson)) {
    Write-Host "Creating service principal for app ID: $appId"
    $sp = Get-AzJson -Arguments @(
        "ad", "sp", "create",
        "--id", $appId,
        "--query", "{id:id,appId:appId,displayName:displayName}"
    )

    Start-Sleep -Seconds 15
}
else {
    $sp = $spJson | ConvertFrom-Json
    Write-Host "Reusing service principal: $($sp.displayName)"
}

$spObjectId = $sp.id

$existingFederatedCredential = Get-AzJson -Arguments @(
    "ad", "app", "federated-credential", "list",
    "--id", $appId,
    "--query", "[?name=='$FederatedCredentialName'] | [0]"
)

if ($null -eq $existingFederatedCredential -or [string]::IsNullOrWhiteSpace($existingFederatedCredential.name)) {
    Write-Host "Creating federated identity credential: $FederatedCredentialName"

    $federatedCredential = [ordered]@{
        name        = $FederatedCredentialName
        issuer      = $OidcIssuer
        subject     = $FederatedSubject
        audiences   = @($Audience)
        description = "GitHub Actions OIDC from GHE.com for $GitHubOrganization/$GitHubRepository"
    }

    $credentialPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "ghe-federated-credential-$([guid]::NewGuid()).json"
    try {
        $federatedCredential | ConvertTo-Json -Depth 5 | Set-Content -Path $credentialPath -Encoding utf8NoBOM
        Invoke-Az -Arguments @(
            "ad", "app", "federated-credential", "create",
            "--id", $appId,
            "--parameters", "@$credentialPath",
            "--only-show-errors"
        ) | Out-Null
    }
    finally {
        Remove-Item -Path $credentialPath -Force -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host "Federated identity credential already exists: $FederatedCredentialName"
    Write-Host "Existing credential subject/issuer were not changed. Delete it first if the trust values changed."
}

if (-not $SkipManagementGroupRoleAssignments) {
    $managementGroupScope = "/providers/Microsoft.Management/managementGroups/$RootManagementGroupId"

    Ensure-RoleAssignment -ServicePrincipalObjectId $spObjectId -RoleName "Management Group Contributor" -Scope $managementGroupScope
    Ensure-RoleAssignment -ServicePrincipalObjectId $spObjectId -RoleName "Resource Policy Contributor" -Scope $managementGroupScope
    Ensure-RoleAssignment -ServicePrincipalObjectId $spObjectId -RoleName "User Access Administrator" -Scope $managementGroupScope
}

if (-not $SkipSubscriptionRoleAssignments) {
    $subscriptionIds = (@($ManagementSubscriptionId, $ConnectivitySubscriptionId, $BackendSubscriptionId) + $AdditionalSubscriptionIds) |
        Where-Object { -not (Test-IsPlaceholder -Value $_) } |
        Select-Object -Unique

    foreach ($subscriptionId in $subscriptionIds) {
        $subscriptionScope = "/subscriptions/$subscriptionId"

        Ensure-RoleAssignment -ServicePrincipalObjectId $spObjectId -RoleName "Contributor" -Scope $subscriptionScope
        Ensure-RoleAssignment -ServicePrincipalObjectId $spObjectId -RoleName "User Access Administrator" -Scope $subscriptionScope
    }
}

if ($CreateBackendStorage) {
    $backendContainerScope = Ensure-BackendStorage `
        -SubscriptionId $BackendSubscriptionId `
        -ResourceGroupName $BackendResourceGroupName `
        -StorageAccountName $BackendStorageAccountName `
        -ContainerName $BackendContainerName `
        -Location $BackendLocation

    if (-not $SkipBackendRoleAssignment) {
        Ensure-RoleAssignment `
            -ServicePrincipalObjectId $spObjectId `
            -RoleName "Storage Blob Data Contributor" `
            -Scope $backendContainerScope
    }
}

Write-Host ""
Write-Host "Service principal and federated identity are ready."
Write-Host ""
Write-Host "Use these GitHub Actions secrets or variables:"
Write-Host "AZURE_CLIENT_ID=$appId"
Write-Host "AZURE_TENANT_ID=$TenantId"
Write-Host "AZURE_SUBSCRIPTION_ID=$ManagementSubscriptionId"
Write-Host ""
Write-Host "Use this federated credential configuration:"
Write-Host "issuer=$OidcIssuer"
Write-Host "subject=$FederatedSubject"
Write-Host "audience=$Audience"
Write-Host ""
Write-Host "Terraform OIDC environment variables for workflow steps:"
Write-Host "ARM_USE_OIDC=true"
Write-Host "ARM_CLIENT_ID=$appId"
Write-Host "ARM_TENANT_ID=$TenantId"
Write-Host "ARM_SUBSCRIPTION_ID=$ManagementSubscriptionId"
if ($CreateBackendStorage) {
    Write-Host ""
    Write-Host "Commit this Terraform backend configuration in infra/backend.tf:"
    Write-Host 'terraform {'
    Write-Host '  backend "azurerm" {'
    Write-Host "    resource_group_name  = `"$BackendResourceGroupName`""
    Write-Host "    storage_account_name = `"$BackendStorageAccountName`""
    Write-Host "    container_name       = `"$BackendContainerName`""
    Write-Host "    key                  = `"$BackendStateKey`""
    Write-Host "    use_azuread_auth     = true"
    Write-Host '  }'
    Write-Host '}'
}
