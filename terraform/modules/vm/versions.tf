# Child modules must declare the providers they use — otherwise Terraform
# infers `hashicorp/<name>` (the default) instead of the real source. The
# version pin lives at the root (terraform/versions.tf); here we only declare
# the source, with no version constraint, so the root pin governs.

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
