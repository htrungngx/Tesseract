terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  node_name = var.node_name
  vm_id     = var.guest.vmid
  started   = true

  description = coalesce(var.guest.description, var.name)
  tags        = concat(var.guest.tags, sort(var.tags_global))

  unprivileged = true
  protection   = true
  features {
    nesting = true
    keyctl  = true
    fuse    = true
  }

  start_on_boot = var.guest.start_on_boot

  cpu {
    architecture = "amd64"
    cores        = var.guest.cores
  }

  memory {
    dedicated = var.guest.memory_mb
    swap      = var.guest.memory_mb
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.guest.disk_gb
  }

  operating_system {
    template_file_id = var.guest.os_template
    type             = var.guest.os_type
  }

  initialization {
    hostname = var.name
    dns {
      domain  = "htrung.dev"
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    # DHCP — router owns IP assignment, no static address here.
    ip_config {
      ipv4 { address = "dhcp" }
      ipv6 { address = "auto" }
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    enabled = true
  }

  dynamic "device_passthrough" {
    for_each = { for d in var.guest.device_passthroughs : d.path => d }
    content {
      path       = device_passthrough.value.path
      gid        = device_passthrough.value.gid
      uid        = device_passthrough.value.uid
      mode       = device_passthrough.value.mode
      deny_write = device_passthrough.value.deny_write
    }
  }

  lifecycle {
    prevent_destroy = true
    # Template only used at create time; imported guests don't track it.
    ignore_changes = [operating_system[0].template_file_id]
  }
}
