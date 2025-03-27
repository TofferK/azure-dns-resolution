# Windows VM in hub VNet

# Subnet for Hub VM
resource "azurerm_subnet" "hub_vm_subnet" {
  name                 = "hub-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.2.4.0/24"]
}

# Public IP for "hub" VM
resource "azurerm_public_ip" "hub_vm_public_ip" {
  name                = "hub-vm-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Basic"
}

# Network Interface for "hub" VM with Public IP
resource "azurerm_network_interface" "hub_vm_nic" {
  name                = "hub-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "hub-ip-config"
    subnet_id                     = azurerm_subnet.hub_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hub_vm_public_ip.id
  }
}

resource "azurerm_windows_virtual_machine" "hub_vm" {
  name                  = "hub-dns-vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B2ms"
  admin_username        = "azureuser"
  admin_password        = "T0fferk!ngvm"
  network_interface_ids = [azurerm_network_interface.hub_vm_nic.id]
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
resource "azurerm_route_table" "hub-vm-rt" {
  name                = "hub-vm-route-table"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# Add a Route to the Route Table
resource "azurerm_route" "route-to-spoke" {
  name                   = "route-to-spoke"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.hub-vm-rt.name
  address_prefix         = "10.3.0.0/24" # Destination CIDR
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.weu-firewall.ip_configuration[0].private_ip_address # Private VIP of the Firewall
}

# Associate the Route Table with a Subnet (Optional)
resource "azurerm_subnet_route_table_association" "hub-vm-rt-association" {
  subnet_id      = azurerm_subnet.hub_vm_subnet.id # Replace with the subnet you want to associate
  route_table_id = azurerm_route_table.hub-vm-rt.id
}

#Associate the default NSG with the VM subnet
resource "azurerm_subnet_network_security_group_association" "hub_vm_subnet_nsg_association" {
  count                     = var.enable_hub_vm_subnet_nsg_association
  subnet_id                 = azurerm_subnet.hub_vm_subnet.id
  network_security_group_id = azurerm_network_security_group.default_nsg.id
}

variable "enable_hub_vm_subnet_nsg_association" {
  type    = number
  default = 0
}