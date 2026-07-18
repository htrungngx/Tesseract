variable "node_name" {
  type = string
}

variable "name" {
  type = string
}

variable "tags_global" {
  type    = set(string)
  default = []
}

variable "guest" {
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
