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
