terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name = var.node_name
  vm_id     = var.guest.vmid
  name      = var.name
  started   = true

  description   = coalesce(var.guest.description, var.name)
  tags          = concat(var.guest.tags, sort(var.tags_global))
  on_boot       = var.guest.start_on_boot
  bios          = var.guest.bios
  scsi_hardware = "virtio-scsi-pci"
  machine       = "q35"

  cpu {
    architecture = "x86_64"
    cores        = var.guest.cores
    sockets      = 1
    type         = "host" # passthrough
  }

  memory {
    dedicated = var.guest.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.guest.disk_gb
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    prevent_destroy = true
  }
}
