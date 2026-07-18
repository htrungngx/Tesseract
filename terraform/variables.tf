# Input schema. The inventory is *data* — two maps, one per guest kind.
# See ADR-0005. Per-guest differences live in tfvars; fleet-wide defaults live
# in the modules (modules/lxc/variables.tf, modules/vm/variables.tf).

variable "node_name" {
  description = "Proxmox node that hosts all guests. Single-node homelab."
  type        = string
  default     = "pve01"
}

variable "tags_global" {
  description = "Tags added to every guest (in addition to per-guest tags). Lets us mark the whole fleet at once."
  type        = set(string)
  default     = ["iac"]
}

# --- LXC inventory ----------------------------------------------------------

# The shape of a single LXC entry in `var.lxcs`. Module defaults handle
# fleet-wide settings (unprivileged, nesting, keyctl, onboot, DHCP networking,
# datastore, dns) — only per-guest differences go here.
variable "lxcs" {
  description = "Map of LXCs to manage. Key is the stable guest name (load-bearing — see ADR-0005)."
  type = map(object({
    vmid          = number # Proxmox container ID (e.g., 101)
    expected_ip   = string # Observed IP via router DHCP; Terraform does NOT enforce (ADR-0007)
    description   = optional(string)
    os_template   = string # e.g. "local:vztmpl/debian-13-standard_*.tar.zst"
    os_type       = string # "debian" | "ubuntu" | "alpine" | ... (ADR-0006: provider sets it on the shell)
    cores         = number
    memory_mb     = number # dedicated RAM in MB
    disk_gb       = number # root disk size in GB
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true) # fleet default; override per-guest if ever needed
  }))
  default = {}
}

# --- VM inventory -----------------------------------------------------------

# The shape of a single VM entry in `var.vms`. No template_id / clone fields —
# VMs are modeled as standalone (ADR-0008).
variable "vms" {
  description = "Map of VMs to manage. Key is the stable guest name (load-bearing — see ADR-0005)."
  type = map(object({
    vmid          = number
    expected_ip   = string
    description   = optional(string)
    cores         = number
    memory_mb     = number # dedicated RAM in MB
    disk_gb       = number
    bios          = optional(string, "seabios") # "seabios" | "omuf" (ovmf requires efi_disk, not the default)
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true)
  }))
  default = {}
}
