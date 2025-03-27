resource "azapi_resource" "dns_resolver_policy" {
  type      = "Microsoft.Network/dnsResolverPolicies@2023-07-01-preview"
  name      = "nwg-ck-weu-dnsresolverpolicy-01"
  location  = "westeurope"
  parent_id = azurerm_resource_group.main.id

}

resource "azapi_resource" "dns_resolver_policy_vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@2023-07-01-preview"
  name      = "${azurerm_virtual_network.hub_vnet.name}-vnet"
  parent_id = azapi_resource.dns_resolver_policy.id

  body = {
    location = "westeurope"
    properties = {
      virtualNetwork = {
        id = azurerm_virtual_network.hub_vnet.id
      }
    }
  }

}

data "azurerm_log_analytics_workspace" "platform" {
  name                = "nwg-ck-weu-platform-01-la"
  resource_group_name = "nwg-ck-weu-loganalytics-01-rg"
}

#Enable diagnostics on the Azure DNS Security Policy
resource "azurerm_monitor_diagnostic_setting" "dns_resolver_diagnostics" {
  name                       = "${azapi_resource.dns_resolver_policy.name}-diag"
  target_resource_id         = azapi_resource.dns_resolver_policy.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id

  # Log settings
  enabled_log {
    category = "DnsResponse"
  }

  # Metric settings
  metric {
    category = "AllMetrics"
  }
}