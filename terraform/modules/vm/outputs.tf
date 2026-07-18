output "vmid" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  value = var.name
}

output "expected_ip" {
  description = "Observed IP via router DHCP. Recorded, not enforced (ADR-0007)."
  value       = var.guest.expected_ip
}
