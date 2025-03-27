# Dummy "On-Premise" VNet
resource "azurerm_virtual_network" "onprem_vnet" {
  name                = "onprem-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "onprem_subnet" {
  name                 = "onprem-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Windows VM in "On-Prem" VNet
# Public IP for "On-Prem" VM
resource "azurerm_public_ip" "onprem_vm_public_ip" {
  name                = "onprem-vm-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Basic"
}

# Network Interface for "On-Prem" VM with Public IP
resource "azurerm_network_interface" "onprem_vm_nic" {
  name                = "onprem-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "onprem-ip-config"
    subnet_id                     = azurerm_subnet.onprem_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onprem_vm_public_ip.id
  }
}

resource "azurerm_windows_virtual_machine" "onprem_vm" {
  name                  = "onprem-dns-vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B2ms"
  admin_username        = "azureuser"
  admin_password        = "T0fferk!ngvm"
  network_interface_ids = [azurerm_network_interface.onprem_vm_nic.id]
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

# Custom Script to Install DNS Role
resource "azurerm_virtual_machine_extension" "onprem_dns_install" {
  count                = var.enable_on_prem_forwarding
  name                 = "install-dns"
  virtual_machine_id   = azurerm_windows_virtual_machine.onprem_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name DNS -IncludeManagementTools; Add-DnsServerForwarder -IPAddress '8.8.8.8'; Add-DnsServerForwarder -IPAddress '8.8.4.4'; Restart-Service -Name DNS\""
    }
SETTINGS
}