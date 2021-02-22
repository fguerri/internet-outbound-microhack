#########################################################
# Azure hub VPN Gateway
#########################################################

resource "azurerm_public_ip" "hub-vpngw-ip" {
  name                = "hub-vpngw-ip"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  allocation_method = "Dynamic"

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_virtual_network_gateway" "hub-vpngw" {
  name                              = "hub-vpngw"
  location                          = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name

  type                              = "Vpn"
  vpn_type                          = "RouteBased"

  active_active                     = false
  enable_bgp                        = false
  sku                               = "VpnGw1"

  ip_configuration {
    name                            = "vnetGatewayIpConfig"
    public_ip_address_id            = azurerm_public_ip.hub-vpngw-ip.id
    private_ip_address_allocation   = "Dynamic"
    subnet_id                       = azurerm_subnet.hub-gateway-subnet.id
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}


#########################################################
# On-prem Local Network Gateway
#########################################################

resource "azurerm_local_network_gateway" "onprem-lng" {
  name                  = "onprem-lng"
  resource_group_name   = azurerm_resource_group.internet-outbound-microhack-rg.name
  location              = azurerm_resource_group.internet-outbound-microhack-rg.location
  gateway_address       = azurerm_linux_virtual_machine.onprem-proxy-vm.public_ip_address
  address_space         = ["10.57.0.0/16"]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}


#########################################################
# Connection to Hub
#########################################################

resource "azurerm_virtual_network_gateway_connection" "hub-2-onprem" {
  name                          = "hub-2-onprem"
  location                      = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name           = azurerm_resource_group.internet-outbound-microhack-rg.name

  type                          = "IPsec"
  virtual_network_gateway_id    = azurerm_virtual_network_gateway.hub-vpngw.id
  local_network_gateway_id      = azurerm_local_network_gateway.onprem-lng.id

  shared_key                    = local.shared-key

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}


#########################################################
# Forced tunneling
#########################################################

resource "azurerm_route_table" "wvd-spoke-rt" {
  name                          = "wvd-spoke-rt"
  location                      = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name           = azurerm_resource_group.internet-outbound-microhack-rg.name
  disable_bgp_route_propagation = false

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_route_table_association" "wvd-spoke-rt-association" {
  subnet_id      = azurerm_subnet.wvd-subnet.id
  route_table_id = azurerm_route_table.wvd-spoke-rt.id
}

