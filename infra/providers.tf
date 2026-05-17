terraform {
  required_version = ">= 1.12, < 2.0"

  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.21"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.35"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azapi" {
  subscription_id = var.management_subscription_id
}

provider "azurerm" {
  alias           = "management"
  subscription_id = var.management_subscription_id

  features {}
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = var.connectivity_subscription_id

  features {}
}

provider "alz" {
  library_overwrite_enabled = true

  library_references = [
    {
      custom_url = "${path.root}/lib"
    }
  ]
}

