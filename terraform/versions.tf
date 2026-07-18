# Terraform and provider version pins.
#
# - Terraform >= 1.10 is required for `use_lockfile = true` on the S3 backend
#   (see ADR-0003). Pin a floor, not a ceiling, so bugfixes arrive.
# - bpg/proxmox pinned to ~> 0.111 (latest patch of the 0.111 line — see
#   ADR-0002). Breaking minors / 1.0 require a deliberate upgrade pass.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}
