# ADR 0008: The k3s template (`104`) is out of scope — VMs are modeled as standalone, not clones

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

VM `104` (`k3s-template`, Ubuntu 22.04, 4 GB / 20 GB, stopped) was built by
hand and used as the clone source for the 4 running k3s VMs (`105`–`108`).
Three positions were considered for how Terraform treats it:

- **A. Ignore `104` entirely; model VMs as standalone.** `104` is invisible
  to Terraform; VMs have no `clone` block.
- **B. Import `104` as a read-only `data` source;** modules reference it via
  `template_id` from the data source.
- **C. Terraform fully owns `104`'s lifecycle.** Template is "managed" but
  its *contents* aren't — dishonest, and would need Packer to do properly
  (which ADR-0006 explicitly defers).

`104` is a **historical bootstrap artifact**: a build-time tool that already
did its job (producing the 4 running VMs). It is the VM equivalent of what
the community-scripts (ADR-0001) are to the LXCs — we adopt the *result*, not
the bootstrap process.

## Decision

Adopt **Position A**: `104` is out of scope for Terraform.

### Concrete shape

- `104` is **not** a Terraform resource, **not** a Terraform data source. It
  does not appear in `terraform plan` output. It is invisible to the IaC.
- The 4 running VMs (`105`–`108`) are modeled as **standalone VMs**, not as
  clones. The `vm` module has **no `clone` block** and **no `template_id`
  input**. Their disks are their own (originally cloned, now independent —
  that history is irrelevant to ongoing management).
- VMs are brought into Terraform via `terraform import`, the same as LXCs.
  After import + reconciliation, `terraform plan` shows them as managed with
  no creation/clone activity.
- The `vm` module carries `lifecycle { prevent_destroy = true }` so that no
  accidental destroy (which would require a clone to usefully recreate) can
  happen without a deliberate code change. (See ADR-0001: do not recreate.)

### `104` is documented, not automated

`104`'s construction (base image, what was installed, how it was prepared
for k3s) is recorded in `docs/runbooks/k3s-template.md` — a manual
procedure, not IaC. If `104` is ever lost, the runbook tells an operator
how to rebuild it by hand. If reproducibility becomes a real pain, Packer
(or equivalent) is the answer — deferred to a future ADR, same pattern as
Ansible (ADR-0006).

## Consequences

- **The `vm` module is simpler than the "clone-from-template" sketch.**
  No `clone` block, no `template_id` variable. The tfvars `vms` map has
  no `template_id` field. The module just describes a VM shell.
- **VM destruction requires out-of-band recovery.** If a VM is somehow
  destroyed (despite `prevent_destroy`), Terraform cannot recreate it
  usefully — it would produce a blank VM, not a configured k3s node.
  Recovery is: manually clone from `104` (per the runbook), then
  `terraform import` the new VM. Acceptable because destruction is meant
  to be rare and deliberate.
- **`104`'s absence from Terraform is deliberate, not an oversight.**
  Anyone reading the code should find this ADR and understand why.
- **Adding a *new* VM is a future decision, not solved here.** If/when a
  new VM is needed, three options exist (clone from `104` by adding a
  conditional `clone` block; provision fresh from a cloud-init image;
  build by hand + import). That choice gets its own ADR when forced; the
  current `vm` module is shaped for *adopting existing VMs*, not for
  creating new ones.
- **Future Packer adoption is unblocked.** If template reproducibility
  becomes valuable, Packer builds `104` (and any other templates) outside
  Terraform; this ADR is simply superseded by the Packer ADR. No code
  rewrite required — `104` was never in Terraform to begin with.

## References

- ADR-0001 (do not disturb existing guests; import-only adoption).
- ADR-0004 (two generic modules: `lxc` and `vm`).
- ADR-0006 (Terraform scope: shells only; config tooling deferred, not
  refused — same pattern applied here to template building).
