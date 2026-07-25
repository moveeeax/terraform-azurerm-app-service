terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.63.0, < 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "app_service" {
  source = "../.."

  name                = "example-webapp01"
  service_plan_name   = "example-asp"
  resource_group_name = "example-rg"
  location            = "eastus"
  sku_name            = "B1"

  # A managed identity lets app settings reference Key Vault secrets instead of
  # carrying them as plaintext values.
  identity_type = "SystemAssigned"

  app_settings = {
    WEBSITES_PORT = "8080"
  }

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "app_service_hostname" {
  value = module.app_service.default_hostname
}
