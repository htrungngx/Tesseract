# One resource per VM. No clone block (ADR-0008): VMs are standalone, imported
# via `terraform import`. No provisioners (ADR-0006). DHCP only (ADR-0007):
# expected_ip is recorded in tfvars for outputs/sentinel, NOT pushed here.
#
# prevent_destroy (ADR-0010): a destroy requires editing this module, visible
# in code review. Recovery if destroyed is documented in
# docs/runbooks/k3s-template.md (manual clone + re-import).
#
# IMPORTANT for `terraform import`: the resource block here describes how
# Terraform expects the VM to look. First `plan` after import will likely show
# diffs against the real VM config (e.g., scsi_hardware, cpu type). Each diff
# must be reconciled by hand — confirm it's cosmetic before apply. See ADR-0001.

resource "proxmox_virtual_environment_vm" "this" {
  node_name = var.node_name
  vm_id     = var.guest.vmid
  name      = var.name
  started   = true

  description     = coalesce(var.guest.description, var.name)
  tags            = concat(var.guest.tags, sort(var.tags_global))
  on_boot         = var.guest.start_on_boot
  stop_on_destroy = false
  bios            = var.guest.bios
  scsi_hardware   = var.scsi_hardware
  machine         = "q35"

  cpu {
    architecture = "x86_64"
    cores        = var.guest.cores
    sockets      = 1
    type         = "host" # CPU passthrough per operator inventory ("host passthrough")
  }

  memory {
    dedicated = var.guest.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.guest.disk_gb
  }

  network_device {
    bridge  = var.bridge
    model   = "virtio"
    enabled = true
  }

  # DHCP — router is the IP authority (ADR-0007). VM uses guest-side DHCP
  # (configured historically on the OS), so we omit a static ip_config block.
  # The initialization block below is left absent entirely — adding cloud-init
  # is a separate decision (ADR-0006 future options).

  lifecycle {
    prevent_destroy = true
  }
}
