# Spoke VNet
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "spoke-vnet"
  address_space       = ["10.3.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  //Use the DNS Resolver IP if we want to route traffic via the firewall
  # dns_servers         = [azurerm_private_dns_resolver_inbound_endpoint.inbound.ip_configurations[0].private_ip_address]
  //Use the FW VIP if we want to "proxy" traffic via the firewall, and then on to the DNS Resolver
  dns_servers = [azurerm_firewall.weu-firewall.ip_configuration[0].private_ip_address]
}

resource "azurerm_subnet" "spoke_subnet" {
  name                 = "spoke-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = ["10.3.0.0/24"]
}

# Windows VM in Spoke VNet

# Public IP for "Spoke" VM
resource "azurerm_public_ip" "spoke_vm_public_ip" {
  name                = "spoke-vm-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Basic"
}

# Network Interface for "Spoke" VM with Public IP
resource "azurerm_network_interface" "spoke_vm_nic" {
  name                = "spoke-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "spoke-ip-config"
    subnet_id                     = azurerm_subnet.spoke_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke_vm_public_ip.id
  }
}

resource "azurerm_windows_virtual_machine" "spoke_vm" {
  name                  = "spoke-dns-vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B2ms"
  admin_username        = "azureuser"
  admin_password        = "T0fferk!ngvm"
  network_interface_ids = [azurerm_network_interface.spoke_vm_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-smalldisk"
    version   = "latest"
  }
}

# Create a Route Table
resource "azurerm_route_table" "spoke-vm-rt" {
  name                = "spoke-vm-route-table"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Add a Route to the Route Table
resource "azurerm_route" "route-to-dns-resolver" {
  name                   = "route-to-dns-resolver"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.spoke-vm-rt.name
  address_prefix         = "10.2.1.0/24" # Destination CIDR
  # next_hop_type          = "None"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.weu-firewall.ip_configuration[0].private_ip_address # Private VIP of the Firewall
}

# Associate the Route Table with a Subnet (Optional)
resource "azurerm_subnet_route_table_association" "spoke-vm-rt-association" {
  subnet_id      = azurerm_subnet.spoke_subnet.id # Replace with the subnet you want to associate
  route_table_id = azurerm_route_table.spoke-vm-rt.id
}

#Associate the default NSG with the VM subnet
resource "azurerm_subnet_network_security_group_association" "spoke_subnet_nsg_association" {
  count                     = var.enable_spoke_vm_subnet_nsg_association
  subnet_id                 = azurerm_subnet.spoke_subnet.id
  network_security_group_id = azurerm_network_security_group.default_nsg.id
}

variable "enable_spoke_vm_subnet_nsg_association" {
  type    = number
  default = 1
}