# Entry point. Provider config in provider.tf, backend in backend.tf,
# version pins in versions.tf.
#
# Two module calls — one per guest kind (ADR-0004). Each is instantiated with
# `for_each` over its inventory map (ADR-0005). Adding a guest is a tfvars
# edit, not a code change.

module "lxcs" {
  source   = "./modules/lxc"
  for_each = var.lxcs

  node_name   = var.node_name
  name        = each.key
  tags_global = var.tags_global
  guest       = each.value
}

module "vms" {
  source   = "./modules/vm"
  for_each = var.vms

  node_name   = var.node_name
  name        = each.key
  tags_global = var.tags_global
  guest       = each.value
}
