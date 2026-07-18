variable "node_name" {
  type    = string
  default = "pve01"
}

variable "tags_global" {
  type    = set(string)
  default = ["iac"]
}

variable "lxcs" {
  type = map(object({
    vmid          = number
    expected_ip   = string # observed via DHCP, not enforced
    description   = optional(string)
    os_template   = string
    os_type       = string
    cores         = number
    memory_mb     = number
    disk_gb       = number
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true)
    device_passthroughs = optional(list(object({
      path       = string
      gid        = optional(number)
      uid        = optional(number)
      mode       = optional(string)
      deny_write = optional(bool)
    })), [])
  }))
  default = {}
}

variable "vms" {
  type = map(object({
    vmid          = number
    expected_ip   = string
    description   = optional(string)
    cores         = number
    memory_mb     = number
    disk_gb       = number
    tags          = optional(list(string), [])
    start_on_boot = optional(bool, true)
  }))
  default = {}
}
