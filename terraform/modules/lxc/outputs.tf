output "vmid" {
  description = "Proxmox container ID."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "name" {
  value = var.name
}

output "expected_ip" {
  description = "Observed IP via router DHCP. Recorded, not enforced (ADR-0007)."
  value       = var.guest.expected_ip
}
