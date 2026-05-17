variable "management_subscription_id" {
  type        = string
  description = "Subscription ID that hosts SLZ management resources such as Log Analytics, Automation, DCRs, and AMA UAMI."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.management_subscription_id))
    error_message = "management_subscription_id must be a subscription GUID."
  }
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Subscription ID that hosts shared connectivity resources, including Private DNS zones."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.connectivity_subscription_id))
    error_message = "connectivity_subscription_id must be a subscription GUID."
  }
}

variable "identity_subscription_id" {
  type        = string
  default     = null
  description = "Optional identity subscription ID to place under the identity management group."

  validation {
    condition     = var.identity_subscription_id == null || var.identity_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.identity_subscription_id))
    error_message = "identity_subscription_id must be null, empty, or a subscription GUID."
  }
}

variable "security_subscription_id" {
  type        = string
  default     = null
  description = "Optional security subscription ID to place under the security management group."

  validation {
    condition     = var.security_subscription_id == null || var.security_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.security_subscription_id))
    error_message = "security_subscription_id must be null, empty, or a subscription GUID."
  }
}

variable "parent_management_group_id" {
  type        = string
  description = "Parent management group ID for the existing SLZ root. Use the tenant ID when the root management group is directly under the tenant root group."
}

variable "architecture_name" {
  type        = string
  default     = "slz_existing"
  description = "Architecture name defined in lib/architecture_definitions/slz_existing.alz_architecture_definition.yaml."
}

variable "root_management_group_id" {
  type        = string
  default     = "slz"
  description = "Existing SLZ root management group ID. Must match the id in the architecture definition."
}

variable "platform_management_group_id" {
  type        = string
  default     = "platform"
  description = "Existing Platform management group ID."
}

variable "landing_zones_management_group_id" {
  type        = string
  default     = "landingzones"
  description = "Existing Landing Zones management group ID."
}

variable "corp_management_group_id" {
  type        = string
  default     = "corp"
  description = "Existing Corp management group ID."
}

variable "management_management_group_id" {
  type        = string
  default     = "management"
  description = "Existing Management management group ID."
}

variable "connectivity_management_group_id" {
  type        = string
  default     = "connectivity"
  description = "Existing Connectivity management group ID."
}

variable "identity_management_group_id" {
  type        = string
  default     = "identity"
  description = "Existing Identity management group ID."
}

variable "security_management_group_id" {
  type        = string
  default     = "security"
  description = "Existing Security management group ID."
}

variable "enable_subscription_placement" {
  type        = bool
  default     = true
  description = "When true, Terraform manages placement of platform subscriptions into the existing management groups."
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for management resources and policy managed identities."
}

variable "location_short" {
  type        = string
  default     = "weu"
  description = "Short location token used in generated resource names."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment tag value."
}

variable "prefix" {
  type        = string
  default     = "alz"
  description = "Naming prefix for created resources."
}

variable "security_contact_email" {
  type        = string
  description = "Security contact email used by Defender for Cloud policy parameters."
}

variable "management_resource_group_name" {
  type        = string
  default     = null
  description = "Optional override for the management resource group name."
}

variable "service_health_resource_group_name" {
  type        = string
  default     = null
  description = "Optional override for the service health alerts resource group name."
}

variable "mdfc_export_resource_group_name" {
  type        = string
  default     = null
  description = "Optional override for the Microsoft Defender for Cloud export resource group name."
}

variable "private_dns_resource_group_name" {
  type        = string
  default     = null
  description = "Optional override for the Private DNS zones resource group name in the connectivity subscription."
}

variable "log_analytics_workspace_name" {
  type        = string
  default     = null
  description = "Optional override for the Log Analytics workspace name."
}

variable "automation_account_name" {
  type        = string
  default     = null
  description = "Optional override for the Automation Account name."
}

variable "ama_user_assigned_identity_name" {
  type        = string
  default     = null
  description = "Optional override for the AMA user-assigned managed identity name."
}

variable "dcr_change_tracking_name" {
  type        = string
  default     = null
  description = "Optional override for the Change Tracking data collection rule name."
}

variable "dcr_vm_insights_name" {
  type        = string
  default     = null
  description = "Optional override for the VM Insights data collection rule name."
}

variable "dcr_defender_sql_name" {
  type        = string
  default     = null
  description = "Optional override for the Defender SQL data collection rule name."
}

variable "private_dns_zone_region" {
  type        = string
  default     = null
  description = "Region value supplied to the ALZ Deploy-Private-DNS-Zones policy. Defaults to var.location."
}

variable "ddos_protection_plan_id" {
  type        = string
  default     = null
  description = "Optional existing DDoS protection plan resource ID. If omitted, Enable-DDoS-VNET policy assignments are not created."
}

variable "allowed_locations" {
  type        = list(string)
  description = "Allowed Azure regions for SLZ Level 1 data residency controls. This must not be empty."

  validation {
    condition     = length(var.allowed_locations) > 0
    error_message = "allowed_locations must contain at least one Azure region for SLZ L1 data residency policy."
  }
}

variable "enable_defender_plans" {
  type        = bool
  default     = true
  description = "When true, overrides Deploy-MDFC-Config-H224 policy parameters to enable Defender plans with DeployIfNotExists."
}

variable "enable_telemetry" {
  type        = bool
  default     = false
  description = "Enable telemetry for Microsoft AVM modules."
}

variable "create_private_dns_policy_role_assignment" {
  type        = bool
  default     = true
  description = "Assign Network Contributor on the Private DNS resource group to the Deploy-Private-DNS-Zones policy managed identity."
}

variable "policy_assignments_to_modify" {
  type = map(object({
    policy_assignments = map(object({
      creation_enabled = optional(bool, true)
      enforcement_mode = optional(string, null)
      identity         = optional(string, null)
      identity_ids     = optional(list(string), null)
      parameters       = optional(map(string), null)
      not_scopes       = optional(list(string), null)
      non_compliance_messages = optional(set(object({
        message                        = string
        policy_definition_reference_id = optional(string, null)
      })), null)
      resource_selectors = optional(list(object({
        name = string
        resource_selector_selectors = optional(list(object({
          kind   = string
          in     = optional(set(string), null)
          not_in = optional(set(string), null)
        })), [])
      })), null)
      overrides = optional(list(object({
        kind  = string
        value = string
        override_selectors = optional(list(object({
          kind   = string
          in     = optional(set(string), null)
          not_in = optional(set(string), null)
        })), [])
      })), null)
    }))
  }))
  default     = {}
  description = "Additional or overriding SLZ/ALZ policy assignment modifications. Keys must be management group IDs from the architecture definition."
}

variable "private_dns_zone_names" {
  type        = list(string)
  description = "Private DNS zones to create in the connectivity subscription for private endpoint integration."
  default = [
    "privatelink.adf.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.api.azureml.ms",
    "privatelink.azconfig.io",
    "privatelink.azure-api.net",
    "privatelink.azure-automation.net",
    "privatelink.azurecr.io",
    "privatelink.azure-devices.net",
    "privatelink.azurehealthcareapis.com",
    "privatelink.azurestaticapps.net",
    "privatelink.azurewebsites.net",
    "privatelink.batch.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.cassandra.cosmos.azure.com",
    "privatelink.cognitiveservices.azure.com",
    "privatelink.database.windows.net",
    "privatelink.datafactory.azure.net",
    "privatelink.dev.azuresynapse.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.eventgrid.azure.net",
    "privatelink.eventhub.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.gremlin.cosmos.azure.com",
    "privatelink.managedhsm.azure.net",
    "privatelink.mongo.cosmos.azure.com",
    "privatelink.monitor.azure.com",
    "privatelink.mysql.database.azure.com",
    "privatelink.notebooks.azure.net",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.postgres.database.azure.com",
    "privatelink.prod.migration.windowsazure.com",
    "privatelink.purview.azure.com",
    "privatelink.purviewstudio.azure.com",
    "privatelink.queue.core.windows.net",
    "privatelink.redis.cache.windows.net",
    "privatelink.redisenterprise.cache.azure.net",
    "privatelink.search.windows.net",
    "privatelink.service.signalr.net",
    "privatelink.servicebus.windows.net",
    "privatelink.sql.azuresynapse.net",
    "privatelink.table.core.windows.net",
    "privatelink.table.cosmos.azure.com",
    "privatelink.vaultcore.azure.net",
    "privatelink.webpubsub.azure.com"
  ]
}

variable "private_dns_zone_virtual_network_id" {
  type        = string
  description = "Resource ID of the virtual network to link to every Private DNS zone."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.private_dns_zone_virtual_network_id))
    error_message = "private_dns_zone_virtual_network_id must be a valid Azure virtual network resource ID."
  }
}

variable "private_dns_zone_virtual_network_link_name_prefix" {
  type        = string
  default     = "vnet-link"
  description = "Prefix used for each Private DNS zone virtual network link name."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied to taggable resources."
}

