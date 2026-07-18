TF := cd terraform && terraform

.PHONY: init plan apply import-lxc import-vm check-ips fmt validate

init:     ; $(TF) init
plan:     ; $(TF) plan
apply:    ; $(TF) apply
fmt:      ; $(TF) fmt -recursive
validate: ; $(TF) validate
check-ips: ; @./scripts/check-ips

# Import existing guest into state (never recreate).
# bpg wants "node/vmid" form. Values pulled from tfvars via `terraform console`.
# tr -cd keeps only the listed chars — defends against warnings leaking in.
import-lxc:
	@test -n "$(NAME)" || { echo "Usage: make import-lxc NAME=adguard"; exit 2; }
	@NODE=$$(cd terraform && terraform console -no-color 2>/dev/null <<< 'var.node_name' | tr -cd 'a-zA-Z0-9'); \
	VMID=$$(cd terraform && terraform console -no-color 2>/dev/null <<< 'var.lxcs["$(NAME)"].vmid' | tr -cd '0-9'); \
	test -n "$$VMID" || { echo "No VMID for $(NAME) — is it in tfvars?"; exit 2; }; \
	echo "Importing $(NAME) as $$NODE/$$VMID ..."; \
	cd terraform && terraform import "module.lxcs[\"$(NAME)\"].proxmox_virtual_environment_container.this" "$$NODE/$$VMID"

import-vm:
	@test -n "$(NAME)" || { echo "Usage: make import-vm NAME=k3s-master01"; exit 2; }
	@NODE=$$(cd terraform && terraform console -no-color 2>/dev/null <<< 'var.node_name' | tr -cd 'a-zA-Z0-9'); \
	VMID=$$(cd terraform && terraform console -no-color 2>/dev/null <<< 'var.vms["$(NAME)"].vmid' | tr -cd '0-9'); \
	test -n "$$VMID" || { echo "No VMID for $(NAME) — is it in tfvars?"; exit 2; }; \
	echo "Importing $(NAME) as $$NODE/$$VMID ..."; \
	cd terraform && terraform import "module.vms[\"$(NAME)\"].proxmox_virtual_environment_vm.this" "$$NODE/$$VMID"
