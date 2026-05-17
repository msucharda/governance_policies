output "management_resource_group_id" {
  description = "Management resource group ID."
  value       = module.management_resources.resource_group.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.management_resources.log_analytics_workspace.id
}

output "automation_account_id" {
  description = "Automation Account resource ID."
  value       = module.management_resources.automation_account.id
}

output "data_collection_rule_ids" {
  description = "Data collection rule IDs created by the management module."
  value       = module.management_resources.data_collection_rule_ids
}

output "ama_user_assigned_identity_ids" {
  description = "AMA user-assigned identity IDs created by the management module."
  value       = module.management_resources.user_assigned_identity_ids
}

output "private_dns_resource_group_id" {
  description = "Private DNS resource group ID."
  value       = azurerm_resource_group.private_dns.id
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs keyed by zone name."
  value       = { for name, zone in azurerm_private_dns_zone.private_endpoint_zones : name => zone.id }
}

output "private_dns_zone_virtual_network_link_ids" {
  description = "Private DNS zone virtual network link IDs keyed by zone name."
  value       = { for name, link in azurerm_private_dns_zone_virtual_network_link.private_endpoint_zones : name => link.id }
}

output "management_group_resource_ids" {
  description = "Management group resource IDs returned by the SLZ policy module."
  value       = module.alz_policies.management_group_resource_ids
}

output "policy_assignment_resource_ids" {
  description = "Policy assignment resource IDs returned by the SLZ policy module."
  value       = module.alz_policies.policy_assignment_resource_ids
}

output "policy_assignment_identity_ids" {
  description = "Policy assignment managed identity principal IDs returned by the SLZ policy module."
  value       = module.alz_policies.policy_assignment_identity_ids
}

