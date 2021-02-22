#########################################################
# On-Prem VNet
#########################################################
resource "azurerm_virtual_network" "onprem-vnet" {
  name                = "onprem-vnet"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  address_space       = ["10.57.0.0/16"]
  
  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet" "onprem-workstation-subnet" {
    name                    = "workstation-subnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.onprem-vnet.name
    address_prefix          = "10.57.1.0/24"
}

resource "azurerm_subnet" "onprem-proxy-subnet" {
    name                        = "proxy-subnet"
    resource_group_name         = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name        = azurerm_virtual_network.onprem-vnet.name
    address_prefix              = "10.57.2.0/24"
}

resource "azurerm_subnet" "onprem-bastion-subnet" {
    name                    = "AzureBastionSubnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.onprem-vnet.name
    address_prefix          = "10.57.0.0/27"
}

resource "azurerm_network_security_group" "on-prem-proxy-subnet-nsg" {
  name                = "on-prem-proxy-subnet-nsg"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  security_rule {
    name                       = "allow-ISAKMP-from-any"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = [500,4500]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_network_security_group_association" "onprem-proxy-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.onprem-proxy-subnet.id
  network_security_group_id = azurerm_network_security_group.on-prem-proxy-subnet-nsg.id
} 

#########################################################
# Azure hub VNet
#########################################################
resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  address_space       = ["10.58.0.0/16"]

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet" "hub-firewall-subnet" {
    name                    = "AzureFirewallSubnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.hub-vnet.name
    address_prefix          = "10.58.1.0/24"
}

resource "azurerm_subnet" "hub-gateway-subnet" {
    name                    = "GatewaySubnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.hub-vnet.name
    address_prefix          = "10.58.0.0/27"
}

  
#########################################################
# Azure wvd-spoke VNet
#########################################################
resource "azurerm_virtual_network" "wvd-spoke-vnet" {
  name                = "wvd-spoke-vnet"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  address_space       = ["10.59.0.0/16"]

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet" "wvd-subnet" {
    name                    = "wvd-subnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.wvd-spoke-vnet.name
    address_prefix          = "10.59.1.0/24"
}

resource "azurerm_subnet" "wvd-spoke-bastion-subnet" {
    name                    = "AzureBastionSubnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.wvd-spoke-vnet.name
    address_prefix          = "10.59.0.0/27"
}

resource "azurerm_network_security_group" "wvd-subnet-nsg" {
  name                = "wvd-subnet-nsg"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_network_security_group_association" "wvd-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.wvd-subnet.id
  network_security_group_id = azurerm_network_security_group.wvd-subnet-nsg.id
}

#########################################################
# Peering hub <--> wvd-spoke
#########################################################  
resource "azurerm_virtual_network_peering" "wvd-spoke-2-hub" {
  name                              = "wvd-spoke-2-hub"
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name
  virtual_network_name              = azurerm_virtual_network.wvd-spoke-vnet.name
  remote_virtual_network_id         = azurerm_virtual_network.hub-vnet.id
  allow_virtual_network_access      = true
  allow_forwarded_traffic           = true
  allow_gateway_transit             = false
  use_remote_gateways               = true
  
  depends_on                        = [azurerm_virtual_network_gateway.hub-vpngw]
}

resource "azurerm_virtual_network_peering" "hub-2-wvd-spoke" {
  name                              = "hub-2-wvd-spoke"
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name
  virtual_network_name              = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id         = azurerm_virtual_network.wvd-spoke-vnet.id
  allow_virtual_network_access      = true
  allow_forwarded_traffic           = false
  allow_gateway_transit             = true
  use_remote_gateways               = false

  depends_on                        = [azurerm_virtual_network_gateway.hub-vpngw]
}


#########################################################
# On-Prem Bastion host
#########################################################

resource "azurerm_public_ip" "onprem-bastion-ip" {
  name                = "onprem-bastion-ip"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_bastion_host" "onprem-bastion" {
  name                = "onprem-bastion"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.onprem-bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.onprem-bastion-ip.id
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}


#########################################################
# WVD-Spoke Bastion host
#########################################################

resource "azurerm_public_ip" "wvd-spoke-bastion-ip" {
  name                = "wvd-spoke-bastion-ip"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_bastion_host" "wvd-spoke-bastion" {
  name                = "wvd-spoke-bastion"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.wvd-spoke-bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.wvd-spoke-bastion-ip.id
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

#########################################################
# DBricks Spoke VNet
#########################################################
resource "azurerm_virtual_network" "dbricks-spoke-vnet" {
  name                = "dbricks-spoke-vnet"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  address_space       = ["10.60.0.0/16"]
  
  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet" "dbricks-public-subnet" {
    name                    = "public-subnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.dbricks-spoke-vnet.name
    address_prefix          = "10.60.0.0/24"

    delegation {
        name = "dbricks-delegation"
        service_delegation {
          name = "Microsoft.Databricks/workspaces"
        }
    }
}

resource "azurerm_subnet" "dbricks-private-subnet" {
    name                    = "private-subnet"
    resource_group_name     = azurerm_resource_group.internet-outbound-microhack-rg.name
    virtual_network_name    = azurerm_virtual_network.dbricks-spoke-vnet.name
    address_prefix          = "10.60.1.0/24"

    delegation {
        name = "dbricks-delegation"
        service_delegation {
          name = "Microsoft.Databricks/workspaces"
        }
    }
}


resource "azurerm_network_security_group" "dbricks-public-nsg" {
  name                = "dbricks-public-nsg"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_network_security_group_association" "dbricks-public-nsg-association" {
  subnet_id                 = azurerm_subnet.dbricks-public-subnet.id
  network_security_group_id = azurerm_network_security_group.dbricks-public-nsg.id
} 

resource "azurerm_network_security_group" "dbricks-private-nsg" {
  name                = "dbricks-private-nsg"
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_network_security_group_association" "dbricks-private-nsg-association" {
  subnet_id                 = azurerm_subnet.dbricks-private-subnet.id
  network_security_group_id = azurerm_network_security_group.dbricks-private-nsg.id
} 

resource "azurerm_route_table" "dbricks-spoke-rt" {
  name                          = "dbricks-spoke-rt"
  location                      = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name           = azurerm_resource_group.internet-outbound-microhack-rg.name
  disable_bgp_route_propagation = false

   route {
    name           = "contoso-default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "None"
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

resource "azurerm_subnet_route_table_association" "dbricks-spoke-private-subnet-rt-association" {
  subnet_id      = azurerm_subnet.dbricks-private-subnet.id
  route_table_id = azurerm_route_table.dbricks-spoke-rt.id
}

resource "azurerm_subnet_route_table_association" "dbricks-spoke-public-subnet-rt-association" {
  subnet_id      = azurerm_subnet.dbricks-public-subnet.id
  route_table_id = azurerm_route_table.dbricks-spoke-rt.id
}

#########################################################
# Peering hub <--> dbricks-spoke
#########################################################  
resource "azurerm_virtual_network_peering" "dbricks-spoke-2-hub" {
  name                              = "dbricks-spoke-2-hub"
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name
  virtual_network_name              = azurerm_virtual_network.dbricks-spoke-vnet.name
  remote_virtual_network_id         = azurerm_virtual_network.hub-vnet.id
  allow_virtual_network_access      = true
  allow_forwarded_traffic           = true
  allow_gateway_transit             = false
  use_remote_gateways               = true
  
  depends_on                        = [azurerm_virtual_network_gateway.hub-vpngw]
}

resource "azurerm_virtual_network_peering" "hub-2-dbricks-spoke" {
  name                              = "hub-2-dbricks-spoke"
  resource_group_name               = azurerm_resource_group.internet-outbound-microhack-rg.name
  virtual_network_name              = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id         = azurerm_virtual_network.dbricks-spoke-vnet.id
  allow_virtual_network_access      = true
  allow_forwarded_traffic           = false
  allow_gateway_transit             = true
  use_remote_gateways               = false

  depends_on                        = [azurerm_virtual_network_gateway.hub-vpngw]
}

#########################################################
# Log Analytics workspace
#########################################################  
resource "random_string" "random" {
  length = 16
  special = false
  
}
resource "azurerm_log_analytics_workspace" "internet-outbound-microhack-wksp" {
  name                = join("",["internet-outbound-microhack-wksp-", random_string.random.result])
  location            = azurerm_resource_group.internet-outbound-microhack-rg.location
  resource_group_name = azurerm_resource_group.internet-outbound-microhack-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}
