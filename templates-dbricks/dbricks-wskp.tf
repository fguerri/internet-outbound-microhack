#########################################################
# Databricks workspace
#########################################################  
resource "azurerm_databricks_workspace" "dbricks-wksp" {
  name                        = "dbricks-wksp"
  resource_group_name         = azurerm_resource_group.internet-outbound-microhack-dbricks-rg.name
  location                    = azurerm_resource_group.internet-outbound-microhack-dbricks-rg.location
  sku                         = "trial"

  managed_resource_group_name = "internet-outbound-microhack-dbricks-managed-rg"

  custom_parameters {
    virtual_network_id = data.azurerm_virtual_network.dbricks-spoke-vnet.id
    public_subnet_name = "public-subnet"
    private_subnet_name = "private-subnet"
    no_public_ip = var.secure_cluster_connectivity
  }

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "internet-outbound"
  }
}
