resource "azurerm_network_security_group" "default_nsg" {
  name                = "default-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

#Allow RDP from home PC
resource "azurerm_network_security_rule" "allow_rdp_from_home_pc" {
  name                        = "AllowRDPFromHomePC"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "81.179.190.36"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.default_nsg.name
}

# Enable NSG Flow Logs
data "azurerm_network_watcher" "weu_network_watcher" {
  name                = "NetworkWatcher_westeurope"
  resource_group_name = "NetworkWatcherRG"
}

#Storage account is mandatory
resource "azurerm_storage_account" "weu_flow_logs_sa" {
  name                     = "nsgflowlogsweu01sa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#Enable flow logs for this NSG
resource "azurerm_network_watcher_flow_log" "flow_log" {
  name                 = "default-nsg-flow-logs"
  network_watcher_name = data.azurerm_network_watcher.weu_network_watcher.name
  resource_group_name  = data.azurerm_network_watcher.weu_network_watcher.resource_group_name
  target_resource_id   = azurerm_network_security_group.default_nsg.id
  storage_account_id   = azurerm_storage_account.weu_flow_logs_sa.id
  enabled              = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = data.azurerm_log_analytics_workspace.platform.workspace_id
    workspace_region      = data.azurerm_log_analytics_workspace.platform.location
    workspace_resource_id = data.azurerm_log_analytics_workspace.platform.id
    interval_in_minutes   = 10
  }
}
