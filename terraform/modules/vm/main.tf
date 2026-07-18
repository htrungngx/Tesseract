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
  scsi_hardware = "virtio-scsi-pci"
  machine       = "q35"
  tablet_device = true

  # Real VMs are UEFI clones. bios/efi_disk/agent/operating_system describe
  # how they were built, not knobs to twiddle.
  bios             = "ovmf"
  operating_system { type = "l26" }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "2m"
  }

  agent {
    enabled = true
    timeout = "15m"
    type    = "virtio"
  }

  serial_device { device = "socket" }

  cpu {
    cores   = var.guest.cores
    sockets = 1
    type    = "host" # passthrough
  }

  memory {
    dedicated = var.guest.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.guest.disk_gb
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
  }

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"
    upgrade      = true
    ip_config {
      ipv4 { address = "dhcp" }
      ipv6 { address = "dhcp" }
    }
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    prevent_destroy = true
    # Cloud-init user_account is set once at first boot and the password isn't
    # tracked. Reconciling it would churn state every plan.
    ignore_changes = [initialization[0].user_account]
  }
}
