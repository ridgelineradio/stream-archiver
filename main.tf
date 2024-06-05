provider "azurerm" {
  features {}
}

variable "monitors" {}

resource "azurerm_resource_group" "example" {
  name     = "stream-archiver"
  location = "West US 2"
}

resource "azurerm_storage_account" "example" {
  name                             = "krdfaudioarchives"
  resource_group_name              = azurerm_resource_group.example.name
  location                         = azurerm_resource_group.example.location
  account_tier                     = "Standard"
  account_replication_type         = "RAGRS"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
}

resource "azurerm_storage_share" "example" {
  name                 = "audio"
  storage_account_name = azurerm_storage_account.example.name
  quota                = 256
}

resource "azurerm_container_app_environment" "example" {
  name                = "stream-archiver"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_container_app_environment_storage" "example" {
  name                         = "audio"
  container_app_environment_id = azurerm_container_app_environment.example.id
  account_name                 = azurerm_storage_account.example.name
  share_name                   = azurerm_storage_share.example.name
  access_key                   = azurerm_storage_account.example.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "example" {
  name                         = "stream-archiver"
  resource_group_name          = azurerm_resource_group.example.name
  container_app_environment_id = azurerm_container_app_environment.example.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    max_replicas = 1

    dynamic "container" {
      for_each = var.monitors
      content {
        name  = "stream-archiver-${container.key}"
        image = "ghcr.io/jooola/earhorn"
        command = [
          "/usr/local/bin/earhorn",
          "--stream-url",
          container.value.url,
          "--archive-path=/mnt/audio/${container.key}",
          "--archive-segment-format",
          "mp3",
          "--archive-copy-stream",
          "--listen-port",
          container.value.port
        ]

        cpu    = "0.25"
        memory = "0.5Gi"

        volume_mounts {
          name = "audio"
          path = "/mnt/audio"
        }
      }
    }

    volume {
      name         = "audio"
      storage_name = azurerm_storage_share.example.name
      storage_type = "AzureFile"
    }
  }
}
