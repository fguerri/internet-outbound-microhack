#########################################################
# Variables
#########################################################

variable "location" {
  description = "Location to deploy resources"
  type        = string
}

variable "admin_password" {
  description = "Password for all VMs deployed in this MicroHack"
  type        = string
}


#########################################################
# Locals
#########################################################

locals {
  shared-key = "microhack-shared-key"
}

