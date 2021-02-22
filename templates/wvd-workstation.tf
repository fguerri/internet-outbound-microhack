#########################################################
# WVD Workstation
#########################################################

resource "azurerm_public_ip" "wvd-workstation-pip" {
  name                = "wvd-workstation-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_network_interface" "wvd-workstation-nic" {
  name                = "wvd-workstation-nic"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.wvd-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.59.1.4"
    public_ip_address_id          = azurerm_public_ip.wvd-workstation-pip.id
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_windows_virtual_machine" "wvd-workstation" {
  name                      = "wvd-workstation"
  resource_group_name       = azurerm_resource_group.internet-outbound-microhack-rg.name
  location                  = azurerm_resource_group.internet-outbound-microhack-rg.location
  size                      = "Standard_D2_v3"
  admin_username            = "adminuser"
  admin_password            = var.admin_password
  network_interface_ids     = [azurerm_network_interface.wvd-workstation-nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "20h2-evd-o365pp"
    version   = "latest"
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}
