# ADR 0006: Terraform owns guest shells only — no provisioners, no config-management tool chosen yet

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

A common temptation when adopting Terraform for Proxmox is to also use it to
**install and configure software inside guests** via provisioners (the
`bpg/proxmox` `initialization` block, `connection`+`remote-exec`, or
`local_exec` hooks). Equally common is to pair Terraform with a config
management tool (Ansible, cloud-init, Salt) and to misplace the boundary
between them.

The homelab today is in a specific state: all 14 guests were brought up by
hand, and the in-guest software was installed via the
[community-scripts.org](https://community-scripts.org/) project (see ADR-0001).
So *neither* Terraform *nor* any config tool currently needs to install
anything. We are at a clean decision point with no sunk cost on either side.

Two questions were raised together and should be answered separately:

1. **Do we add a config-management tool (Ansible) now?**
2. **What does Terraform own?**

These are independent and have different right answers.

## Why Terraform is structurally bad at in-guest software install

- **No idempotent plan for software state.** `terraform plan` cannot observe
  whether Jellyfin or the `hermes` user is installed, so it cannot detect drift
  in software. Every plan looks clean even when the box has drifted.
- **Provisioners run once, on create.** `bpg/proxmox` `initialization` and
  `connection`-based provisioners fire when the resource is created, not on
  every apply. They are not reconciliation loops.
- **Failure mode is a half-installed box.** If a provisioner fails mid-run,
  `terraform apply` will not retry it on the next apply (the resource already
  exists). Recovery is manual.
- **Software state becomes tied to VM lifecycle.** Changing an unrelated
  Terraform field that forces resource recreation can silently re-trigger (or
  fail to re-trigger) the provisioner, depending on lifecycle quirks.
- **Secrets land in state.** Anything passed to the guest via Terraform
  (config values, tokens) ends up in `.tfstate`, which we have designated
  sensitive-but-not-rotated (ADR-0003).

These are properties of Terraform, not of any particular provider. They would
not be fixed by swapping providers.

## Decision

### 1. Terraform owns the guest **shell** only.

Terraform manages, for each guest:

- Existence (the Proxmox resource is present or absent).
- Compute sizing (CPU, RAM).
- Storage (disk size, storage pool).
- Networking (bridge, VLAN, IP/IPv6, DHCP vs static).
- Lifecycle (`onboot`, start/stop, tags).
- For VMs: clone source template (`vmid` to clone from).

Terraform does **not** manage anything that requires logging into the guest:
packages, users, services, config files, secrets, application state.

### 2. No Terraform provisioners. Ever.

- No `provisioner "remote-exec"` blocks.
- No `provisioner "local-exec"` blocks that SSH into guests.
- No reliance on `bpg/proxmox` `initialization` custom scripts to install
  software (the `initialization` block is used **only** for things that are
  genuinely Proxmox-side: e.g., setting up a cloud-init drive when we adopt
  cloud-init, or the user-account seed for cloud-init — see *Future options*
  below).
- `terraform taint` / recreate is never used as a "reinstall software" trick.

### 3. Every fact has exactly one owner.

For each fact about the homelab, exactly one system is authoritative:

| Fact | Owner |
| --- | --- |
| Guest exists, CPU/RAM/disk/net | Terraform (via tfvars → state) |
| Guest IP and `vmid` | Terraform (in tfvars) |
| Packages, users, services inside guests | **Not IaC today** (deferred) |
| Router DHCP reservations | Manual (no router API — see router ADR) |
| Proxmox ACLs | Manual, one-time |
| Cloudflare tunnel token | Manual + secret store (see secrets ADR) |

Where two systems *could* both know a fact (e.g., guest IP), only one is
authoritative; others are derived outputs.

### 4. Config-management tool choice is **deferred** (not refused).

We do not adopt Ansible (or any other config tool) in this repo right now. We
also do **not** declare "never." Software-install strategy is explicitly a
future ADR with options left open:

- **Ansible** — classical choice; fits the shell/config split cleanly.
- **cloud-init** — integrated into Proxmox guest creation via the bpg
  `initialization` block; arguably still "Terraform-adjacent" rather than a
  separate tool. Worth a closer look when the question returns.
- **Hand-run community-scripts** — the status quo. Legitimate for a homelab.
- **Bare SSH + a shell script** — also fine at this scale.

When this ADR is revisited, it is superseded — not edited.

## Consequences

- **The repo stays minimal.** No `ansible/`, no playbooks, no inventory
  format to design. (ADR-0004 reflects this; `ansible/` was removed from the
  initial layout.)
- **Terraform's `plan` is honest.** It shows only what it can actually
  reconcile: shell-level changes. Operators are not misled into thinking
  plan-success means the box is configured correctly.
- **No hidden runtime dependencies.** `terraform apply` never needs network
  reachability to a guest's SSH port; it only talks to the Proxmox API. Apply
  works even if a guest is down (modulo the `start_on_boot` behavior).
- **Adding the *first* new guest with custom software is the trigger to
  revisit this ADR.** Until then, there is no forcing function and we don't
  pre-build for a hypothetical need.
- **If software-installed-via-IaC is later needed**, the most likely path is
  cloud-init via the bpg `initialization` block (least new tooling) or Ansible
  (most standard). Either lands as a new sibling under the repo root, not
  inside `terraform/`.
- **Community-scripts remain the historical source of truth** for what is
  installed on existing guests. There is no IaC record of "Jellyfin is
  installed on 112." That's acceptable; documenting it would be a separate,
  optional effort (a runbook, not IaC).