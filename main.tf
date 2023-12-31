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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.16.0"
    }
  }
  backend "http" {}
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

variable "cloudflare_api_token" {}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
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
  location   = "westeurope"
  prefix     = "mycorp-eu-project-team"
  prefix_net = replace(local.prefix, "-", "")
  rg_name    = "${local.prefix}-ondrej-${random_string.suffix.result}"
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

resource "azurerm_resource_group" "demo" {
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  name     = "${local.rg_name}-demo"
  location = local.location

  tags = {
    date_created = timestamp()
    company      = "democorp"
  }
}

resource "azurerm_resource_group" "demo2" {
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

  name     = "${local.rg_name}-demo2"
  location = local.location

  tags = {
    date_created = timestamp()
    company      = "democorp"
  }
}

output "tags" {
  value = azurerm_resource_group.demo.tags
}

module "net" {
  source = "./modules/net"

  name          = local.prefix_net
  address_space = ["10.250.0.0/16"]
  subnets = {
    subnet1 = "10.250.1.0/24"
  }
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

module "vms" {
  for_each = {
    "foo" = {
      size              = "Standard_B1ls"
      public_ip_enabled = true
    }
    "bar" = {
      size              = "Standard_B1ls"
      public_ip_enabled = false
    }
  }

  source = "./modules/vm"

  name                = each.key
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.net.subnet_ids[0]
  size                = each.value.size
  admin_username      = "default"
  admin_password      = "asdfasdfA1."
  public_ip_enabled   = each.value.public_ip_enabled
}

output "vm_ips" {
  value = {
    for name, vm in module.vms :
    name => vm.ip != null ? vm.ip : vm.private_ip
  }
}

module "vm_provisioner" {
  source = "./modules/vm2"

  name                = "prov"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.net.subnet_ids[0]
  size                = "Standard_B1ls"
  admin_username      = "default"
  admin_password      = "asdfasdfA1."
  public_ip_enabled   = true
}

output "vm_provisioner_ip" {
  value = module.vm_provisioner.ip
}

data "cloudflare_zone" "sikademo_com" {
  name = "sikademo.com"
}

resource "cloudflare_record" "example" {
  zone_id = data.cloudflare_zone.sikademo_com.id
  name    = "azure-vm-example-2023-10-09"
  value   = module.vm_provisioner.ip
  type    = "A"
  ttl     = 3600
}

output "vm_provisioner_fqdn" {
  value = cloudflare_record.example.hostname
}
