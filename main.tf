terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.75.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

variable "azurerm_client_id" {}
variable "azurerm_client_secret" {}
variable "azurerm_tenant_id" {}
variable "azurerm_subscription_id" {}

provider "azurerm" {
  features {}

  client_id       = var.azurerm_client_id
  client_secret   = var.azurerm_client_secret
  tenant_id       = var.azurerm_tenant_id
  subscription_id = var.azurerm_subscription_id
}

provider "random" {}

resource "random_string" "suffix" {
  length  = 10
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "mycorp-eu-project-team-ondrej-${random_string.suffix.result}"
  location = "westeurope"
}

data "azurerm_resource_group" "global" {
  name = "tt-global"
}

resource "azurerm_storage_account" "main" {
  name                     = "example${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_account" "global" {
  name                     = "exampleglobal${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.global.name
  location                 = data.azurerm_resource_group.global.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

output "storage_account_main_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_globa_name" {
  value = azurerm_storage_account.global.name
}
