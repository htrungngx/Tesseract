terraform {
  required_version = ">= 1.10.0" # use_lockfile needs 1.10+

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }

  backend "s3" {
    bucket = "tesseract-homelab"
    key    = "default.tfstate"

    region                      = "auto"
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true # R2 has no cert for virtual-host-style
  }
}

# Auth via env: PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN, PROXMOX_VE_INSECURE
provider "proxmox" {}

module "lxcs" {
  source   = "./modules/lxc"
  for_each = var.lxcs

  node_name   = var.node_name
  name        = each.key
  tags_global = var.tags_global
  guest       = each.value
}

module "vms" {
  source   = "./modules/vm"
  for_each = var.vms

  node_name   = var.node_name
  name        = each.key
  tags_global = var.tags_global
  guest       = each.value
}

# LXC templates — Terraform pulls them via Proxmox's download-url API (ADR-0011).
# Declared at root so the map can grow without touching modules/lxc.
resource "proxmox_virtual_environment_download_file" "template" {
  for_each = var.templates

  node_name    = var.node_name
  datastore_id = "local"
  content_type = "vztmpl"
  url          = each.value.url
  file_name    = each.value.file_name

  checksum           = each.value.checksum
  checksum_algorithm = each.value.checksum_algorithm

  # Removing a template from the map would delete it from pve01 storage and
  # break any LXC still referencing it. Force a deliberate code change.
  lifecycle {
    prevent_destroy = true
  }
}
