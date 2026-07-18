
resource "proxmox_virtual_environment_container" "this" {
  node_name = var.node_name
  vm_id     = var.guest.vmid
  started   = true

  description = coalesce(var.guest.description, var.name)
  tags        = concat(var.guest.tags, sort(var.tags_global))

  # --- Fleet defaults baked in here (ADR-0005): unprivileged + nesting +
  # keyctl, matching the existing homelab (per operator inventory).
  unprivileged = true
  features {
    nesting = true
    keyctl  = true
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
    datastore_id = var.datastore_id
    size         = var.guest.disk_gb
  }

  operating_system {
    template_file_id = var.guest.os_template
    type             = var.guest.os_type
  }

  initialization {
    hostname = var.name

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    # DHCP — the router is the IP authority (ADR-0007). We deliberately do NOT
    # set ipv4.address here; that would make Terraform the authority and risk
    # IP conflicts with the router's pool.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = var.bridge
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
