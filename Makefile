# Tesseract homelab IaC — operator shortcuts.
# See docs/adr/ for the decisions behind each command.

# Terraform lives in terraform/ (ADR-0004). Every terraform command runs there.
TF := cd terraform && terraform

.PHONY: help init plan apply import-lxc import-vm check-ips fmt validate clean

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

init:  ## terraform init (pulls provider, connects to R2 backend)
	$(TF) init

plan:  ## terraform plan (reads tfvars; remember to source .env first)
	$(TF) plan

apply:  ## terraform apply (remember to source .env first)
	$(TF) apply

# Import an existing guest into state. ADR-0001: import-only, never recreate.
# Usage: make import-lxc NAME=adguard
# Usage: make import-vm  NAME=k3s_master01
import-lxc:  ## Import an existing LXC into state. Usage: make import-lxc NAME=adguard
	@test -n "$(NAME)" || { echo "Usage: make import-lxc NAME=adguard"; exit 2; }
	VMID=$$($(TF) output -raw lxc_guests 2>/dev/null | jq -r '.["$(NAME)"].vmid'); \
	test -n "$$VMID" && $(TF) import "module.lxcs[\"$(NAME)\"].proxmox_virtual_environment_container.this" "$$VMID"

import-vm:  ## Import an existing VM into state. Usage: make import-vm NAME=k3s_master01
	@test -n "$(NAME)" || { echo "Usage: make import-vm NAME=k3s_master01"; exit 2; }
	VMID=$$($(TF) output -raw all_guests 2>/dev/null | jq -r '.["$(NAME)"].vmid'); \
	test -n "$$VMID" && $(TF) import "module.vms[\"$(NAME)\"].proxmox_virtual_environment_vm.this" "$$VMID"

check-ips:  ## Sentinel check (ADR-0007) — verify guests are at their expected_ip.
	@./scripts/check-ips

fmt:  ## terraform fmt
	$(TF) fmt -recursive

validate:  ## terraform validate
	$(TF) validate

clean:  ## Remove .terraform cache. State stays on R2.
	rm -rf terraform/.terraform
