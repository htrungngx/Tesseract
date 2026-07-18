# Generic LXC module. See ADR-0004 (two modules), ADR-0005 (inventory-as-data),
# ADR-0006 (shells only — no provisioners, no software install).
#
# Fleet-wide defaults live HERE, not in tfvars. Per-guest differences come in
# via `guest`. This is what makes "change once, applies everywhere" true.

variable "node_name" {
  description = "Proxmox node hosting the container."
  type        = string
}

variable "name" {
  description = "Container hostname and Proxmox display name. Also the stable identity in state (ADR-0005)."
  type        = string
}

variable "tags_global" {
  description = "Tags added to every guest, merged with per-guest tags."
  type        = set(string)
  default     = []
}

variable "guest" {
  description = "Per-guest config — see `lxcs` variable type in /terraform/variables.tf."
  type = object({
    vmid          = number
    expected_ip   = string
    description   = optional(string)
    os_template   = string
    os_type       = string
    cores         = number
    memory_mb     = number
    disk_gb       = number
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true)
  })
}

# --- Fleet defaults (rarely changed; if you do, all guests get the change) ---

variable "datastore_id" {
  description = "Root-disk datastore for all LXCs."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge all LXCs attach to."
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS servers pushed via cloud-init init block."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "dns_domain" {
  description = "DNS search domain pushed via cloud-init."
  type        = string
  default     = "htrung.dev"
}
