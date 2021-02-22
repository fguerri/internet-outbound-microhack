#########################################################
# CloudInit template
#########################################################

data "template_file" "cloudconfig" {
  template = file("${path.module}/cloud-init.tpl")

  vars = {
   proxy-vm-pip = azurerm_public_ip.onprem-proxy-pip.ip_address
   hub-vpngw-pip = azurerm_public_ip.hub-vpngw-ip.ip_address
   shared-key = local.shared-key
  }

  depends_on    = [azurerm_virtual_network_gateway.hub-vpngw]
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.cloudconfig.rendered
  }
}


#########################################################
# Onprem proxy VM
#########################################################

resource "azurerm_public_ip" "onprem-proxy-pip" {
  name                = "proxy-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_network_interface" "onprem-proxy-nic" {
  name                = "onprem-proxy-nic"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.onprem-proxy-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.57.2.4"
    public_ip_address_id          = azurerm_public_ip.onprem-proxy-pip.id
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_linux_virtual_machine" "onprem-proxy-vm" {
  name                              = "onprem-proxy-vm"
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name
  location                          = azurerm_resource_group.internet-outbound-microhack-rg.location
  size                              = "Standard_A1_v2"
  admin_username                    = "adminuser"
  disable_password_authentication   = "false"
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.onprem-proxy-nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_2"
    version   = "latest"
  }

  custom_data = data.template_cloudinit_config.config.rendered

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}
