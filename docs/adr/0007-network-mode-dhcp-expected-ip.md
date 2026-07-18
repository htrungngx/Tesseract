# ADR 0007: Network mode is router-managed DHCP; Terraform records `expected_ip` but does not enforce it

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

### Homelab network topology

```
ISP (4G/LTE) ── (CGNAT, no usable inbound public IP) ──> [4G router]
                                                                │
                                    single device does ALL of:
                                      ├── WAN: 4G modem (ISP-controlled)
                                      ├── LAN: 192.168.1.0/24, DHCP server
                                      ├── NAT, firewall
                                      └── (likely Wi-Fi AP)
                                                                │
                                              LAN cable ──> [pve01 Proxmox host]
                                                                │
                                                  └── 14 guests (LXC + VM)
```

Key facts:

- **The router is a 4G CPE: one physical box doing WAN modem + LAN DHCP/NAT/AP.**
  It is simultaneously the ISP modem and the user's LAN router — there is no
  separate upstream device.
- **The WAN side is ISP-controlled and behind CGNAT.** The homelab
  effectively has **no usable inbound public IP**: the ISP hands the router
  a private CGNAT address and can change it at any time. This is not a
  "dynamic public IP" situation; inbound connections from the public
  internet are not possible without a tunnel.
- **Remote access is exclusively via overlays:** **Tailscale** (mesh VPN)
  and the **Cloudflare tunnel** (run by the `cloudflared` LXC `100`).
  These are load-bearing, not optional — they are the only way into the
  homelab.
- **The LAN side is user-administered but has no API.** DHCP runs
  autonomously on the router and assigns IPs to guests (empirically
  MAC-sticky, which is why current guests have stable addresses `.123`,
  `.125`, `.126`, …). Admin is via web UI only.
- **The router is a single point of failure.** A reboot (power blip,
  firmware update, ISP-side reset) takes down WAN **and** DHCP together.
  Some consumer 4G routers **lose their DHCP table / MAC-sticky mappings
  on reboot** — not guaranteed persistent. If this one does, guest IPs
  could actually change across a router reboot.

### Why internal IP stability still matters

Public-IP stability is irrelevant (Tailscale + CF tunnel bypass the WAN
entirely). But **internal IP stability is load-bearing**:

- The Cloudflare tunnel's ingress on `cloudflared` (`100`) routes to internal
  IPs (e.g., Jellyfin at `.136`).
- LXC-to-LXC service traffic (`prowlarr` → `radarr` → `sonarr` → `jellyfin`)
  is configured against these IPs.
- Tailscale subnet routes / exit-node config (if/when used) reference them.

A silent IP drift on a guest → confusing partial outage of a downstream
service. The risk is higher than on a normal homelab because the router is
a consumer 4G device whose DHCP table may not survive reboots.

### Why Terraform can't be the IP authority today

`bpg/proxmox` *can* set a static IP on a guest (via `initialization` for VMs,
network config for LXCs). We choose not to, for two reasons:

1. **ADR-0001 forbids disturbing the 14 running guests.** Switching 14 live
   guests from DHCP to static is risky and provides little marginal value
   while the router's DHCP already produces stable IPs in the common case.
2. **Dual IP authority = IP-conflict risk.** If Terraform sets `.125` on a
   guest and the router still considers `.125` part of its assignable pool,
   the router can hand `.125` to another device (phone, laptop) →
   duplicate-IP outage that takes hours to diagnose.

So: one tool that could enforce IPs (Terraform), a router that already hands
out stable IPs autonomously, and no API to reconcile them. Something has to
give.

## Decision

### 1. DHCP stays. Router is the IP authority.

- All guests continue to use DHCP, assigned by the 4G router.
- The router is the **single source of truth** for which IP each guest
  actually has.
- Terraform **does not** set static IPs on guests. Network blocks in the
  `lxc` and `vm` modules are DHCP-only. (See ADR-0006 on Terraform scope.)
- Adding a new guest: boot it, let the router assign an IP, observe the IP,
  record it in tfvars. The router's MAC-sticky behavior handles stability in
  the common case; add an explicit reservation only if you want to *pin* a
  specific address (and the router UI supports it).

### 2. tfvars field is named `expected_ip`, not `ip`.

- The field records **what we expect the IP to be**, based on observation
  of the router's assignment.
- The name makes the semantic explicit: Terraform does not enforce this
  value. It is documentation and a sentinel target, not a configuration
  Terraform pushes.
- Used by Terraform `output`s (so downstream references — Cloudflare tunnel
  docs, Tailscale docs — can cite it) and by the sentinel check (below).

### 3. Sentinel check in CI: detect drift, don't enforce.

Because the router is un-automatable and its DHCP table may not survive
reboots, IP drift is **both invisible to Terraform and more likely than on
a normal homelab**. We add a tiny **sentinel check** — a script run in CI
(and optionally on-demand) that:

1. Reads `expected_ip` for every guest from `terraform output`.
2. Resolves each guest's **actual** current IP via the Proxmox API guest-net
   info (`/nodes/pve01/qemu/<vmid>/interfaces` or the LXC equivalent).
   `arp`/`ping` is a fallback if API query is undesirable.
3. Fails if any guest's actual IP ≠ its `expected_ip`.

This does not reconcile drift (Terraform can't — it doesn't own the IP). It
**detects** drift so an operator can fix the router (or update tfvars)
deliberately, before a downstream service breaks. Given the consumer-4G
failure mode above, this check earns its keep.

### 4. Router operations are documented as a runbook, not IaC.

Anything that requires touching the router UI (adding a manual reservation
to pin an IP, changing the DHCP pool, rebooting after an ISP-side reset,
re-checking DHCP table after a power blip) is documented in
`docs/runbooks/router-ops.md`. It is explicitly a manual operational task,
not automated.

## Consequences

- **No IP-conflict risk.** Single IP authority (router); Terraform only
  observes.
- **Router-side drift is detectable but not auto-fixable.** The sentinel
  check is the safety net; an operator still has to act on it.
- **WAN stability is explicitly out of scope** for this repo. Tailscale +
  Cloudflare tunnel handle inbound; they are external systems whose configs
  reference internal IPs (so IP stability still matters to them) but whose
  own state (tokens, ACLs) is covered by the secrets ADR.
- **Adding a guest is two steps:** edit tfvars (record observed IP) and,
  only if you want to pin it, add a router reservation via the router UI.
  Documented in the runbook.
- **`expected_ip` is a deliberately honest name.** Anyone reading tfvars
  sees the "expected" qualifier and knows not to assume Terraform enforces
  it.
- **The bpg `initialization`/network-config IP fields are not used.**
  Modules leave IP assignment to DHCP.
- **4G-router-specific risk acknowledged:** the runbook should include
  "after a router reboot, run the sentinel check (or `make check-ips`)
  before assuming services are healthy." The DHCP table may have moved.

## Future: Option B (static IPs via Terraform) is a deliberate, separate ADR

If we ever want Terraform to be the IP authority:

1. Pick a maintenance window.
2. Add explicit reservations on the router for the transition (to prevent
   the router from handing those IPs to other devices during cutover).
3. Switch the modules' network blocks from DHCP to static, sourced from a
   renamed `ip` field.
4. Remove router reservations after cutover (or keep them as belt-and-
   suspenders — separate decision).

This is a real change with real risk on running services. It gets its own
ADR when (if) we choose to do it; it does not happen by accident.

## References

- Homelab network topology and DHCP behavior: per operator inventory.
- ADR-0001 (do not disturb running guests).
- ADR-0006 (Terraform scope: shells only).
- Tailscale: <https://tailscale.com/>
- Cloudflare Tunnel: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
