# Outputs. Non-sensitive, suitable for `terraform output` inspection and for
# the sentinel check (ADR-0007). `expected_ip` is documented as "observed, not
# enforced" — outputs re-publish it as such.

output "lxc_guests" {
  description = "All managed LXCs: name → {vmid, expected_ip, tags}. expected_ip is observed, not enforced (ADR-0007)."
  value = {
    for k, v in var.lxcs : k => {
      vmid        = v.vmid
      expected_ip = v.expected_ip
      tags        = concat(v.tags, sort(var.tags_global))
    }
  }
}

output "vm_guests" {
  description = "All managed VMs: name → {vmid, expected_ip, tags}. Same expected_ip semantics as lxc_guests."
  value = {
    for k, v in var.vms : k => {
      vmid        = v.vmid
      expected_ip = v.expected_ip
      tags        = concat(v.tags, sort(var.tags_global))
    }
  }
}

output "all_guests" {
  description = "Flat map of every guest (LXC + VM), keyed by name, with kind. Convenience for the sentinel check."
  value = merge(
    { for k, v in var.lxcs : k => { kind = "lxc", vmid = v.vmid, expected_ip = v.expected_ip } },
    { for k, v in var.vms : k => { kind = "vm", vmid = v.vmid, expected_ip = v.expected_ip } },
  )
}
