# Runbook: 4G router operations

**Related ADR:** [0007](../adr/0007-network-mode-dhcp-expected-ip.md) — router
is the IP authority; Terraform only observes.

The 4G router is the single physical device doing WAN modem + LAN DHCP/NAT/AP.
It has no API. Everything here is manual.

## When to run `make check-ips`

- **After any router reboot** (power blip, firmware update, ISP-side reset).
  The DHCP table may not survive a reboot on consumer 4G gear — guest IPs
  could have moved.
- **Monthly** as a drift spot-check.
- **After suspecting a downstream service is broken** (Cloudflare tunnel 502,
  Jellyfin unreachable, etc.) — IP drift is a likely cause.

## Adding a new guest (network side)

1. Boot the guest. Let the router hand it an IP via DHCP.
2. Observe the assigned IP (e.g., via Proxmox guest-net info, or `arp -a`).
3. Record it as `expected_ip` in `terraform/terraform.tfvars`.
4. *(Optional)* If you want to **pin** the IP, log into the router UI and add
   a DHCP reservation mapping the guest's MAC to the desired IP. The router's
   MAC-sticky behavior usually makes this unnecessary.
5. Run `make check-ips` to confirm.

## After a router reboot

1. Wait for the WAN link + DHCP server to come back (typically 1–3 minutes).
2. Run `make check-ips`. If any guest has moved:
   - **Option A:** Update `expected_ip` in tfvars to match the new reality.
   - **Option B:** Add a router reservation to put it back where it was,
     then `make check-ips` again.
3. If Tailscale or the Cloudflare tunnel broke, restart them per their own
   procedures (out of scope for this repo).
