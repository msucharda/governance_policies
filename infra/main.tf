locals {
  tags = merge(
    {
      environment = var.environment
      workload    = "governance"
      managed-by  = "terraform"
    },
    var.tags
  )

  management_resource_group_name     = coalesce(var.management_resource_group_name, "rg-${var.prefix}-management-${var.location_short}")
  service_health_resource_group_name = coalesce(var.service_health_resource_group_name, "rg-${var.prefix}-service-health-${var.location_short}")
  mdfc_export_resource_group_name    = coalesce(var.mdfc_export_resource_group_name, "rg-${var.prefix}-mdfc-export-${var.location_short}")
  private_dns_resource_group_name    = coalesce(var.private_dns_resource_group_name, "rg-${var.prefix}-private-dns-${var.location_short}")
  log_analytics_workspace_name       = coalesce(var.log_analytics_workspace_name, "law-${var.prefix}-${var.location_short}")
  automation_account_name            = coalesce(var.automation_account_name, "aa-${var.prefix}-${var.location_short}")
  ama_user_assigned_identity_name    = coalesce(var.ama_user_assigned_identity_name, "uami-ama")
  dcr_change_tracking_name           = coalesce(var.dcr_change_tracking_name, "dcr-change-tracking")
  dcr_vm_insights_name               = coalesce(var.dcr_vm_insights_name, "dcr-vm-insights")
  dcr_defender_sql_name              = coalesce(var.dcr_defender_sql_name, "dcr-defender-sql")
  private_dns_zone_region            = coalesce(var.private_dns_zone_region, var.location)
  ddos_protection_enabled            = var.ddos_protection_plan_id != null && var.ddos_protection_plan_id != ""
  create_mdfc_policy_parameter_values = var.enable_defender_plans ? {
    enableAscForAppServices                     = jsonencode({ value = "DeployIfNotExists" })
    enableAscForArm                             = jsonencode({ value = "DeployIfNotExists" })
    enableAscForContainers                      = jsonencode({ value = "DeployIfNotExists" })
    enableAscForCosmosDbs                       = jsonencode({ value = "DeployIfNotExists" })
    enableAscForCspm                            = jsonencode({ value = "DeployIfNotExists" })
    enableAscForKeyVault                        = jsonencode({ value = "DeployIfNotExists" })
    enableAscForOssDb                           = jsonencode({ value = "DeployIfNotExists" })
    enableAscForServers                         = jsonencode({ value = "DeployIfNotExists" })
    enableAscForServersVulnerabilityAssessments = jsonencode({ value = "DeployIfNotExists" })
    enableAscForSql                             = jsonencode({ value = "DeployIfNotExists" })
    enableAscForSqlOnVm                         = jsonencode({ value = "DeployIfNotExists" })
    enableAscForStorage                         = jsonencode({ value = "DeployIfNotExists" })
  } : {}

  policy_default_values = merge(
    {
      ama_change_tracking_data_collection_rule_id = jsonencode({
        value = provider::azapi::resource_group_resource_id(
          var.management_subscription_id,
          local.management_resource_group_name,
          "Microsoft.Insights/dataCollectionRules",
          [local.dcr_change_tracking_name]
        )
      })
      ama_mdfc_sql_data_collection_rule_id = jsonencode({
        value = provider::azapi::resource_group_resource_id(
          var.management_subscription_id,
          local.management_resource_group_name,
          "Microsoft.Insights/dataCollectionRules",
          [local.dcr_defender_sql_name]
        )
      })
      ama_user_assigned_managed_identity_id = jsonencode({
        value = provider::azapi::resource_group_resource_id(
          var.management_subscription_id,
          local.management_resource_group_name,
          "Microsoft.ManagedIdentity/userAssignedIdentities",
          [local.ama_user_assigned_identity_name]
        )
      })
      ama_user_assigned_managed_identity_name = jsonencode({
        value = local.ama_user_assigned_identity_name
      })
      ama_vm_insights_data_collection_rule_id = jsonencode({
        value = provider::azapi::resource_group_resource_id(
          var.management_subscription_id,
          local.management_resource_group_name,
          "Microsoft.Insights/dataCollectionRules",
          [local.dcr_vm_insights_name]
        )
      })
      email_security_contact = jsonencode({
        value = var.security_contact_email
      })
      log_analytics_workspace_id = jsonencode({
        value = provider::azapi::resource_group_resource_id(
          var.management_subscription_id,
          local.management_resource_group_name,
          "Microsoft.OperationalInsights/workspaces",
          [local.log_analytics_workspace_name]
        )
      })
      private_dns_zone_region = jsonencode({
        value = local.private_dns_zone_region
      })
      private_dns_zone_resource_group_name = jsonencode({
        value = local.private_dns_resource_group_name
      })
      private_dns_zone_subscription_id = jsonencode({
        value = var.connectivity_subscription_id
      })
      resource_group_location = jsonencode({
        value = var.location
      })
      resource_group_name_mdfc = jsonencode({
        value = local.mdfc_export_resource_group_name
      })
      resource_group_name_service_health_alerts = jsonencode({
        value = local.service_health_resource_group_name
      })
      allowed_locations = jsonencode({
        value = var.allowed_locations
      })
    },
    local.ddos_protection_enabled ? {
      ddos_protection_plan_id = jsonencode({
        value = var.ddos_protection_plan_id
      })
    } : {}
  )

  default_policy_assignments_to_modify = merge(
    {
      (var.root_management_group_id) = {
        policy_assignments = {
          Deploy-MDFC-Config-H224 = {
            parameters = local.create_mdfc_policy_parameter_values
          }
        }
      }
    },
    local.ddos_protection_enabled ? {} : {
      (var.connectivity_management_group_id) = {
        policy_assignments = {
          Enable-DDoS-VNET = {
            creation_enabled = false
          }
        }
      }
      (var.landing_zones_management_group_id) = {
        policy_assignments = {
          Enable-DDoS-VNET = {
            creation_enabled = false
          }
        }
      }
    }
  )

  policy_assignments_to_modify = merge(
    local.default_policy_assignments_to_modify,
    var.policy_assignments_to_modify
  )

  subscription_placement = var.enable_subscription_placement ? merge(
    {
      management = {
        subscription_id       = lower(var.management_subscription_id)
        management_group_name = var.management_management_group_id
      }
      connectivity = {
        subscription_id       = lower(var.connectivity_subscription_id)
        management_group_name = var.connectivity_management_group_id
      }
    },
    var.identity_subscription_id == null || var.identity_subscription_id == "" ? {} : {
      identity = {
        subscription_id       = lower(var.identity_subscription_id)
        management_group_name = var.identity_management_group_id
      }
    },
    var.security_subscription_id == null || var.security_subscription_id == "" ? {} : {
      security = {
        subscription_id       = lower(var.security_subscription_id)
        management_group_name = var.security_management_group_id
      }
    }
  ) : {}
}

module "management_resources" {
  source  = "Azure/avm-ptn-alz-management/azurerm"
  version = "0.9.0"

  providers = {
    azapi   = azapi
    azurerm = azurerm.management
  }

  automation_account_name      = local.automation_account_name
  enable_telemetry             = var.enable_telemetry
  location                     = var.location
  log_analytics_workspace_name = local.log_analytics_workspace_name
  resource_group_name          = local.management_resource_group_name
  tags                         = local.tags

  data_collection_rules = {
    change_tracking = {
      name = local.dcr_change_tracking_name
      tags = local.tags
    }
    defender_sql = {
      name = local.dcr_defender_sql_name
      tags = local.tags
    }
    vm_insights = {
      name = local.dcr_vm_insights_name
      tags = local.tags
    }
  }

  user_assigned_managed_identities = {
    ama = {
      name = local.ama_user_assigned_identity_name
      tags = local.tags
    }
  }
}

resource "azurerm_resource_group" "service_health" {
  provider = azurerm.management

  name     = local.service_health_resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "mdfc_export" {
  provider = azurerm.management

  name     = local.mdfc_export_resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "private_dns" {
  provider = azurerm.connectivity

  name     = local.private_dns_resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_private_dns_zone" "private_endpoint_zones" {
  provider = azurerm.connectivity
  for_each = toset(var.private_dns_zone_names)

  name                = each.value
  resource_group_name = azurerm_resource_group.private_dns.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_endpoint_zones" {
  provider = azurerm.connectivity
  for_each = azurerm_private_dns_zone.private_endpoint_zones

  name                  = substr("${var.private_dns_zone_virtual_network_link_name_prefix}-${replace(each.key, ".", "-")}", 0, 80)
  private_dns_zone_name = each.value.name
  resource_group_name   = azurerm_resource_group.private_dns.name
  virtual_network_id    = var.private_dns_zone_virtual_network_id
  registration_enabled  = false
  tags                  = local.tags
}

module "alz_policies" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.19.1"

  providers = {
    alz   = alz
    azapi = azapi
  }

  architecture_name            = var.architecture_name
  enable_telemetry             = var.enable_telemetry
  location                     = var.location
  parent_resource_id           = var.parent_management_group_id
  policy_assignments_to_modify = local.policy_assignments_to_modify
  policy_default_values        = local.policy_default_values
  subscription_placement       = local.subscription_placement

  policy_assignments_dependencies = [
    module.management_resources.data_collection_rule_ids,
    module.management_resources.resource_group.id,
    module.management_resources.resource_id,
    module.management_resources.user_assigned_identity_ids,
    azurerm_resource_group.service_health.id,
    azurerm_resource_group.mdfc_export.id,
    azurerm_resource_group.private_dns.id,
    [for zone in azurerm_private_dns_zone.private_endpoint_zones : zone.id],
    [for link in azurerm_private_dns_zone_virtual_network_link.private_endpoint_zones : link.id]
  ]

  policy_role_assignments_dependencies = [
    module.management_resources.data_collection_rule_ids,
    module.management_resources.resource_group.id,
    module.management_resources.resource_id,
    module.management_resources.user_assigned_identity_ids,
    azurerm_resource_group.private_dns.id,
    [for zone in azurerm_private_dns_zone.private_endpoint_zones : zone.id],
    [for link in azurerm_private_dns_zone_virtual_network_link.private_endpoint_zones : link.id]
  ]
}

resource "azurerm_role_assignment" "private_dns_policy_network_contributor" {
  provider = azurerm.connectivity
  count    = var.create_private_dns_policy_role_assignment ? 1 : 0

  scope                = azurerm_resource_group.private_dns.id
  role_definition_name = "Network Contributor"
  principal_id         = module.alz_policies.policy_assignment_identity_ids["${var.corp_management_group_id}/Deploy-Private-DNS-Zones"]
}

