# Provider config: bpg/proxmox. See ADR-0002.
#
# Auth values are read from environment variables (see ADR-0009):
#   PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN, PROXMOX_VE_INSECURE
# The block below has no literal secrets — it deliberately references nothing
# sensitive so it can live in git.

provider "proxmox" {
  # Empty: endpoint, api_token, and insecure all come from PROXMOX_VE_* env
  # vars. This is intentional — keeps secrets out of the repo entirely.
}
