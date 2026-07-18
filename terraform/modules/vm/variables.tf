# Generic VM module. See ADR-0004 (two modules), ADR-0005 (inventory-as-data),
# ADR-0008 (standalone VMs — no clone block, no template_id).

variable "node_name" {
  type        = string
  description = "Proxmox node hosting the VM."
}

variable "name" {
  type        = string
  description = "VM name. Stable identity in state (ADR-0005)."
}

variable "tags_global" {
  type        = set(string)
  default     = []
  description = "Tags added to every guest, merged with per-guest tags."
}

variable "guest" {
  description = "Per-guest config — see `vms` variable type in /terraform/variables.tf."
  type = object({
    vmid          = number
    expected_ip   = string
    description   = optional(string)
    cores         = number
    memory_mb     = number
    disk_gb       = number
    bios          = optional(string, "seabios")
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true)
  })
}

# --- Fleet defaults ---

variable "datastore_id" {
  description = "Datastore for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge all VMs attach to."
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "dns_domain" {
  type    = string
  default = "htrung.dev"
}

variable "scsi_hardware" {
  description = "SCSI controller type. Default matches Proxmox's modern recommendation."
  type        = string
  default     = "virtio-scsi-pci"
}
