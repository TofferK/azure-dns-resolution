# Subnet for Inbound Resolver
resource "azurerm_subnet" "hub_inbound_subnet" {
  name                 = "hub-inbound-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.2.1.0/24"]

  delegation {
    name = "dns-resolver-inbound"
    service_delegation {
      name = "Microsoft.Network/dnsResolvers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Subnet for Outbound Resolver
resource "azurerm_subnet" "hub_outbound_subnet" {
  name                 = "hub-outbound-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.2.2.0/24"]

  delegation {
    name = "dns-resolver-outbound"
    service_delegation {
      name = "Microsoft.Network/dnsResolvers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Inbound Private DNS Resolver in Hub
resource "azurerm_private_dns_resolver" "hub_dns_resolver" {
  name                = "hub-dns-resolver"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_id  = azurerm_virtual_network.hub_vnet.id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "hub-inbound-endpoint"
  location                = azurerm_resource_group.main.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub_dns_resolver.id
  ip_configurations {
    subnet_id = azurerm_subnet.hub_inbound_subnet.id
  }
}

# Outbound Private DNS Resolver in Hub
resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "hub-outbound-endpoint"
  location                = azurerm_resource_group.main.location
  private_dns_resolver_id = azurerm_private_dns_resolver.hub_dns_resolver.id
  subnet_id               = azurerm_subnet.hub_outbound_subnet.id
}

# Create a Route Table
resource "azurerm_route_table" "dns-resolver-rt" {
  name                = "dns-resolver-route-table"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Add a Route to the Route Table
resource "azurerm_route" "route-to-spoke-from-resolver" {
  name                   = "route-to-spoke"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.dns-resolver-rt.name
  address_prefix         = "10.3.0.0/24" # Destination CIDR
  #next_hop_type          = "None"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.weu-firewall.ip_configuration[0].private_ip_address # Private VIP of the Firewall
}

# Associate the Route Table with a Subnet (Optional)
resource "azurerm_subnet_route_table_association" "dns-resolver-rt-association" {
  subnet_id      = azurerm_subnet.hub_inbound_subnet.id # Replace with the subnet you want to associate
  route_table_id = azurerm_route_table.dns-resolver-rt.id
}

#Associate the default NSG with the VM subnet
resource "azurerm_subnet_network_security_group_association" "dns_resolver_subnet_nsg_association" {
  count                     = var.enable_dns_resolver_subnet_nsg_association
  subnet_id                 = azurerm_subnet.hub_inbound_subnet.id
  network_security_group_id = azurerm_network_security_group.default_nsg.id
}

variable "enable_dns_resolver_subnet_nsg_association" {
  type    = number
  default = 1
}