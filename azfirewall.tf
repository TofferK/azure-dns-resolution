variable "dns_proxy_enabled" {
  description = "Enable or disable DNS Proxy on the Azure Firewall"
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
  default     = "West Europe"
}

resource "azurerm_resource_group" "firewall_rg" {
  name     = "weu-firewall-rg"
  location = var.location
}



resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.2.3.0/24"]
}

resource "azurerm_public_ip" "firewall_pip" {
  name                = "weu-fw-pip"
  location            = azurerm_resource_group.firewall_rg.location
  resource_group_name = azurerm_resource_group.firewall_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_firewall_policy" "weu-firewall-policy" {
  name                = "weu-firewall-base-policy"
  resource_group_name = azurerm_resource_group.firewall_rg.name
  location            = azurerm_resource_group.firewall_rg.location

  dns {
    proxy_enabled = var.dns_proxy_enabled
    servers       = [azurerm_private_dns_resolver_inbound_endpoint.inbound.ip_configurations[0].private_ip_address]
  }
}

resource "azurerm_firewall" "weu-firewall" {
  name                = "weu-firewall"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  firewall_policy_id = azurerm_firewall_policy.weu-firewall-policy.id
}

resource "azurerm_firewall_policy_rule_collection_group" "weu-firewall" {
  name               = "weu-firewall-base-rules"
  firewall_policy_id = azurerm_firewall_policy.weu-firewall-policy.id
  priority           = 150

  # Rule Collection for DNS (Higher Priority)
  network_rule_collection {
    name     = "dns-rule-collection"
    priority = 150
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }

  # Rule Collection for All Traffic (Lower Priority)
  #network_rule_collection {
  #  name     = "allow-all-rule-collection"
  #  priority = 200
  #  action   = "Allow"
#
  #  rule {
  #    name                  = "allow-all"
  #    protocols             = ["Any"]
  #    source_addresses      = ["*"]
  #    destination_addresses = ["*"]
  #    destination_ports     = ["*"]
  #  }
  #}
}

# Configure diagnostics settings for the Firewall Policy
resource "azurerm_monitor_diagnostic_setting" "firewall_policy_diagnostics" {
  name                           = "firewall-diagnostics"
  target_resource_id             = azurerm_firewall.weu-firewall.id
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.platform.id
  log_analytics_destination_type = "Dedicated"

  # Enable logs and metrics
  enabled_log {
    category = "AZFWApplicationRule"
  }

  enabled_log {
    category = "AZFWApplicationRuleAggregation"
  }

  enabled_log {
    category = "AZFWDnsQuery"
  }

  enabled_log {
    category = "AZFWFatFlow"
  }

  enabled_log {
    category = "AZFWFlowTrace"
  }

  enabled_log {
    category = "AZFWFqdnResolveFailure"
  }

  enabled_log {
    category = "AZFWIdpsSignature"
  }

  enabled_log {
    category = "AZFWNatRule"
  }

  enabled_log {
    category = "AZFWNatRuleAggregation"
  }

  enabled_log {
    category = "AZFWNetworkRule"
  }

  enabled_log {
    category = "AZFWNetworkRuleAggregation"
  }

  enabled_log {
    category = "AZFWThreatIntel"
  }

  metric {
    category = "AllMetrics"
  }
}