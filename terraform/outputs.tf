output "all_guests" {
  description = "Every guest: name -> {kind, vmid, expected_ip}. expected_ip is observed, not enforced."
  value = merge(
    { for k, v in var.lxcs : k => { kind = "lxc", vmid = v.vmid, expected_ip = v.expected_ip } },
    { for k, v in var.vms : k => { kind = "vm", vmid = v.vmid, expected_ip = v.expected_ip } },
  )
}
