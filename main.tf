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

locals {
  location = "westeurope"
  prefix   = "mycorp-eu-project-team"
  rg_name  = "${local.prefix}-ondrej-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = local.location
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
  lifecycle {
    prevent_destroy = false
  }

  name                     = "exampleglobal${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.global.name
  location                 = data.azurerm_resource_group.global.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_container" "main" {
  count = 5

  name                  = "cont${count.index}"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "main2" {
  for_each = {
    bar = {
      demo = "2"
    }
    baz = {}
  }

  name                  = "cont-${each.key}"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
  metadata              = each.value
}


resource "azurerm_storage_container" "main3" {
  # for_each = { for i in range(5) : tostring(i) => null }
  for_each = {
    "1" = {}
    "3" = {}
    "4" = {}
  }

  name                  = "example${each.key}"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

locals {
  conditional_container_enabled = true
}

resource "azurerm_storage_container" "conditional" {
  count = local.conditional_container_enabled ? 1 : 0

  name                  = "conditional"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

locals {
  conditional_container_id = length(azurerm_storage_container.conditional) == 1 ? azurerm_storage_container.conditional[0].id : null
}

output "conditional_container_id" {
  value = local.conditional_container_id
}

output "storage_account_main_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_globa_name" {
  value = azurerm_storage_account.global.name
}

output "storage_account_main_access_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}

output "example_string" {
  value = "string"
}

output "example_number" {
  value = 53
}

output "example_list" {
  value = ["hello", "world"]
}

output "example_map" {
  value = {
    a = 0
    b = 1
  }
}
