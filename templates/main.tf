terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=2.90"
    }
  }
}

provider "azurerm" {
  features {}
}

#########################################################
# Resource Group for all resources used in the MicroHack
#########################################################
resource "azurerm_resource_group" "internet-outbound-microhack-rg" {
  name     = "internet-outbound-microhack-rg"
  location = var.location

  tags = {
    environment = "onprem-and-cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}

