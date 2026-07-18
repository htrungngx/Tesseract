# ADR 0001: Import existing guests — do not recreate

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

The 14 Proxmox guests (9 LXCs `100`–`113`, 5 VMs `104`–`108`) already exist and
were brought up by hand, with in-container software installed via the
[community-scripts.org](https://community-scripts.org/) project (the post-tteck
script collection). Several guests hold irreplaceable runtime state:

- `112` Jellyfin — media libraries, metadata DB
- `109/110/111` Prowlarr/Radarr/Sonarr — configs and indexed history
- `101` AdGuard — blocklists, rewrites
- `100` cloudflared — rotating tunnel token
- `105–108` k3s cluster — etcd / control-plane / worker identity

We are adopting IaC (Terraform) for ongoing management of the homelab. Three
strategies were considered:

- **A. Import-first.** Run `terraform import` against every guest, reconcile the
  first plan field-by-field. Produces code that mirrors current state but tends
  toward spaghetti.
- **B. Code-first, then selective import.** Design modules for the *future*
  shape (clean, modular, extensible), then `terraform import` to adopt existing
  guests without rebuilding them.
- **C. Taint-and-recreate.** Drop state, let Terraform rebuild. Destroys
  running services and cluster state.

## Decision

Adopt **Option B**: write clean, modular Terraform that describes the intended
guest shapes, then `terraform import` each existing guest into that code. The
community-scripts install is treated as a one-time historical bootstrap — it is
**not** rerun and **not** made a dependency of the IaC.

As a schema probe before committing to the full module shape, import the
smallest/cheapest guest first (`101` AdGuard) and confirm the provider schema
matches reality.

## Consequences

- No guest is destroyed or rebuilt as part of IaC adoption.
- First `terraform plan` after import will show diffs; each must be
  hand-reconciled to confirm it is cosmetic (e.g., provider defaults) and not
  state-destroying before `apply`.
- The community-scripts install logic is **out of scope** for Terraform. Future
  *new* guests and *software* inside any guest are configured by Ansible (see
  forthcoming ADR on configuration layering).
- State for live guests becomes irreplaceable until backups are in place —
  see ADR on state backend.
