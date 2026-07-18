# ADR 0000: Use Markdown ADR template

- **Status:** Accepted
- **Date:** 2026-07-17

## Context

We need a durable, low-friction way to record the irreversible or
expensive-to-reverse decisions made while building out the Tesseract IaC.

## Decision

Adopt Michael Nygard's Architecture Decision Record format, stored as numbered
Markdown files under `docs/adr/`. Each file follows the sections: *Context,
Decision, Consequences, Status*.

## Consequences

- One file per decision, append-only except for status changes.
- Superseding a decision = a new ADR referencing the old one, never an edit.
- Easy to diff, easy to read on the forge, no tooling required.
