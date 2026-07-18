# ADR 0010: CI/CD is deferred — local-first workflow today, Atlantis later

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

The repo needs a defined workflow for *who runs `terraform plan` and `terraform
apply`, and from where.* Two phases were considered:

- **Today (bring-up).** Operator runs plan/apply from their laptop, manually,
  against the R2 state backend (ADR-0003) and Proxmox (ADR-0002).
- **Later (CI/CD).** Pull-request-driven automation using **Atlantis** (the
  standard PR-comment-driven Terraform runner): `atlantis plan` /
  `atlantis apply` comments on PRs trigger plan/apply on a server inside the
  homelab.

CI/CD is **explicitly not urgent.** The repo is bootstrapping from a manually-
managed homelab (ADR-0001); the immediate priority is correct Terraform code
and a safe import pass, not automation. Atlantis will be implemented in a
later phase, against the design recorded here.

### Why the future CI is homelab-hosted (constraint, not preference)

The homelab sits behind CGNAT (ADR-0007) with no usable inbound public IP.
A GitHub-hosted runner cannot reach `pve01:8006` (a private LAN address).
Therefore the future Atlantis instance — and any runner that executes
`terraform` — must live **inside the LAN.** The obvious host is the
`hermesagent` LXC (`102`), which is already Debian, always-on (`onboot=1`),
and exists for exactly this kind of automation.

### Why Atlantis specifically (vs. GitHub Actions with self-hosted runner)

Atlantis is purpose-built for PR-driven Terraform: it posts plan output as
PR comments, gates apply on approval, and locks per-PR. Doing the same with
raw GitHub Actions requires gluing together comment-posting actions, lock
management, and approval gates. Atlantis is the standard tool; deferring the
choice doesn't change that.

### The webhook-reachability constraint (record for future-self)

Atlantis is **webhook-driven**: GitHub pushes events to an Atlantis HTTP
endpoint on every PR action. Through CGNAT, GitHub cannot reach a homelab-
hosted Atlantis directly. The future Atlantis install must be exposed via
either:

- The **Cloudflare tunnel** (already run by LXC `100`), adding an Atlantis
  hostname to the tunnel config, or
- **Tailscale Funnel** (separate from the existing tailnet).

Not a problem to solve today — but solving it is a prerequisite for the
"Later" phase, not an afterthought.

## Decision

### Phase 1 (today): local-first, manual

- **All `terraform plan` and `terraform apply` runs from the operator's
  laptop.** No CI, no automation.
- **State** lives on R2 (ADR-0003); the operator's laptop holds the backend
  credentials in `.env` (ADR-0009).
- **Branch + PR discipline still applies** even without CI:
  - Changes go on a branch, opened as a PR for self-review (yes, self-review —
    the discipline matters even with one operator; the PR is the audit trail).
  - The operator runs `terraform plan` locally and pastes the relevant
    excerpt into the PR description for the record.
  - Merge → operator runs `terraform apply` locally.
- **The sentinel check (ADR-0007) is a local tool for now.** A `make
  check-ips` (or `scripts/check-ips`) target the operator runs manually
  after suspecting router-side drift (e.g., post-router-reboot, per ADR-0007).
  Wire into CI later — see *Phase 2*.

### Phase 2 (later): Atlantis

When CI/CD becomes worth implementing:

1. **Host Atlantis on `hermesagent` (LXC `102`)** or a sibling LXC. Inside
   the LAN; reaches `pve01:8006` directly.
2. **Expose Atlantis to GitHub via the Cloudflare tunnel** (preferred — reuses
   existing infra) or Tailscale Funnel. This is the CGNAT workaround.
3. **Atlantis owns `plan` and `apply`; the laptop stops running `apply`** on
   `main`. Local laptop may still run `plan` for experimentation on branches.
4. **Atlantis carries backend credentials** (Proxmox token, R2 keys) via its
   own env / secret store, **not** the laptop `.env`. The `.env` contract
   (ADR-0009) still holds for local dev.
5. **Atlantis `apply` requires human approval** (`atlantis apply` comment
   from a collaborator) — do not enable auto-apply.

### What holds in both phases

- **`lifecycle { prevent_destroy = true }`** on every guest resource (LXCs
  and VMs) — the always-on safety net regardless of who runs `apply`. A
  destroy requires editing the module, which is visible in code review.
- **State locking** via R2 `use_lockfile` (ADR-0003) serializes concurrent
  runs whether from the laptop or Atlantis. No special handling needed.
- **tfvars is secret-free** (ADR-0009) — applies equally to laptop and CI.

## Consequences

### Phase 1

- **No CI to maintain.** Lower complexity during bring-up; focus stays on
  getting the Terraform code right.
- **The operator is the runner.** Plan/apply happen on the laptop; if the
  laptop is offline, nothing changes. Acceptable for Phase 1.
- **PR discipline is voluntary but expected.** Without CI enforcing it, the
  operator commits to opening PRs and recording plans. The audit trail is
  only as good as this discipline.
- **Sentinel check is opt-in/manual.** Run after router reboots, or whenever
  drift is suspected. Not automatic until Phase 2.

### Phase 2

- **Atlantis becomes a small new service to operate** on `hermesagent` (or
  sibling). Backups and updates become part of the homelab runbook.
- **The Cloudflare tunnel gains an Atlantis ingress.** One more hostname /
  tunnel entry; documented in the tunnel runbook.
- **`apply` is gated by Atlantis approval**, not by branch protection alone.
  Stronger control than Phase 1's "merge → operator remembers to apply."
- **Concurrent plans (multiple open PRs)** serialize on the R2 lock. Expected
  and correct.

### Cross-cutting

- **Phase 2 does not require rewriting Terraform code.** Same state, same
  modules, same tfvars. Only the *runner* changes. This is the value of
  having the state backend and secrets handling already remote/clean
  (ADR-0003, ADR-0009).
- **The day Atlantis is added, this ADR is superseded** by a Phase-2 ADR
  that records the actual Atlantis config (host, tunnel ingress, repo
  permissions, apply policy). Until then, this ADR governs.

## References

- ADR-0001 (do not recreate guests — applies regardless of runner).
- ADR-0002 (Proxmox API token — same token works for laptop and Atlantis).
- ADR-0003 (R2 state backend — works identically from laptop or Atlantis).
- ADR-0007 (sentinel check — local tool in Phase 1, CI step in Phase 2).
- ADR-0009 (secrets — `.env` on laptop, equivalent secret store on Atlantis).
- Atlantis: <https://www.runatlantis.io/>
