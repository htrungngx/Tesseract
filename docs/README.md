# Tesseract Documentation

This directory holds the durable design and decision records for the Tesseract
homelab Infrastructure-as-Code (IaC) repository.

## Layout

| Path | Purpose |
| --- | --- |
| [`adr/`](./adr/) | Architecture Decision Records — one numbered file per decision that is hard/expensive to reverse. |
| [`glossary/`](./glossary/) | Ubiquitous-language glossary. Terms used in code, docs, and discussion map back here so naming stays consistent. |
| `runbooks/` *(planned)* | Operational runbooks for recurring tasks (rotating tokens, adding a node, etc.). |

## How to use these docs

- **ADR format:** Michael Nygard template. Each ADR is numbered (`NNNN-kebab-case-title.md`),
  in the order they were made. Status is one of `Proposed`, `Accepted`, `Deprecated`, `Superseded`.
- **Glossary format:** one term per heading, with a one-line definition and any aliases.
- When a decision in an ADR is overturned, write a new ADR that supersedes it — don't
  rewrite history.

## Index

### ADRs
- [0000 — Use Markdown ADR template](./adr/0000-use-markdown-adr-template.md)
- [0001 — Import existing guests, never recreate](./adr/0001-import-existing-guests-do-not-recreate.md)
- [0002 — bpg/proxmox provider + root@pam API token](./adr/0002-proxmox-provider-and-auth.md)
- [0003 — Cloudflare R2 state backend](./adr/0003-cloudflare-r2-state-backend.md)
- [0004 — Repository layout](./adr/0004-repository-layout.md)
- [0005 — Inventory as data — for_each over map](./adr/0005-inventory-as-data-for-each-over-map.md)
- [0006 — Terraform scope: shells only, no provisioners](./adr/0006-terraform-scope-shells-only.md)
- [0007 — DHCP networking, expected_ip, sentinel check](./adr/0007-network-mode-dhcp-expected-ip.md)
- [0008 — VM template 104 out of scope](./adr/0008-vm-template-out-of-scope.md)
- [0009 — Secrets: Tier 1, secret-free tfvars](./adr/0009-secrets-handling-tier-1.md)
- [0010 — CI/CD deferred — local-first, Atlantis later](./adr/0010-ci-cd-deferred-local-first.md)

### Glossary
- [Terms](./glossary/README.md)

### Runbooks
- [Index](./runbooks/README.md)
