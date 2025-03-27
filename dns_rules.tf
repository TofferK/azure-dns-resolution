# DNS Forwarding Ruleset
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "ruleset" {
  name                                       = "dns-forwarding-ruleset"
  resource_group_name                        = azurerm_resource_group.main.name
  location                                   = azurerm_resource_group.main.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.outbound.id]
}

# Forwarding Rule for General DNS Queries to On-Prem
resource "azurerm_private_dns_resolver_forwarding_rule" "on_prem_dns" {
  #DNS resolution will fail with this in place if DNS is not installed on the 'on-prem' VM
  count                     = var.enable_on_prem_forwarding
  name                      = "on-prem-rule"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  domain_name               = "."

  target_dns_servers {
    ip_address = azurerm_network_interface.onprem_vm_nic.ip_configuration[0].private_ip_address
    port       = 53
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub" {
  name                      = "hub-link"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  virtual_network_id        = azurerm_virtual_network.hub_vnet.id
}

## Create a Forwarding Rule for DNS queries for *.microsoft.com
#resource "azurerm_private_dns_resolver_forwarding_rule" "microsoft_forwarding_rule" {
#  name                      = "forward-microsoft"
#  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.azure_magic_ip.id # Link to the ruleset
#  domain_name               = "microsoft.com."
#  target_dns_servers {
#    ip_address = "168.63.129.16" # Azure Magic IP for resolving Azure-specific domains
#  }
#}

## Create a Forwarding Rule for DNS queries for login.microsoftonline.com
#resource "azurerm_private_dns_resolver_forwarding_rule" "login_microsoftonline_forwarding_rule" {
#  name                      = "forward-login"
#  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.azure_magic_ip.id # Link to the ruleset
#  domain_name               = "login.microsoftonline.com."
#  target_dns_servers {
#    ip_address = "168.63.129.16" # Azure Magic IP for resolving Azure-specific domains
#  }
#}

## Create a Forwarding Rule for DNS queries for *.azure.com
#resource "azurerm_private_dns_resolver_forwarding_rule" "azure_com_forwarding_rule" {
#  name                      = "forward-azure"
#  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.azure_magic_ip.id # Link to the ruleset
#  domain_name               = "azure.com."
#  target_dns_servers {
#    ip_address = "168.63.129.16" # Azure Magic IP for resolving Azure-specific domains
#  }
#}
#

variable "enable_on_prem_forwarding" {
  type    = number
  default = 0
}