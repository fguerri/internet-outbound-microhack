provider "azurerm" {
  version = "2.0.0"
  features {}
}

#########################################################
# Resource Group for all resources used in the MicroHack
#########################################################
data "azurerm_resource_group" "internet-outbound-microhack-rg" {
  name     = "internet-outbound-microhack-rg" 
}

data "azurerm_virtual_network" "dbricks-spoke-vnet" {
  name                = "dbricks-spoke-vnet"
  resource_group_name = "internet-outbound-microhack-rg"
}

resource "azurerm_resource_group" "internet-outbound-microhack-dbricks-rg" {
  name     = "internet-outbound-microhack-dbricks-rg" 
  location = data.azurerm_resource_group.internet-outbound-microhack-rg.location
}