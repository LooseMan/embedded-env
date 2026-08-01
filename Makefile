TF_DIR      := $(CURDIR)/terraform/simple-libvirt-vm
ANSIBLE_DIR := $(CURDIR)/ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/applied_hosts.yml
PLAYBOOK    := $(ANSIBLE_DIR)/playbook/playbook.yml

.PHONY: build provision inventory configure clean

build:
	$(MAKE) provision
	$(MAKE) inventory
	$(MAKE) configure

provision:
	cd $(TF_DIR) && terraform apply -auto-approve

# TODO: jq を使用すべきかは再考の余地あり
inventory:
	cd $(TF_DIR) && terraform output -json | jq -r ' \
	.vm_connection.value as $$vm | \
	"---\nall:\n  children:\n    old_servers:\n      hosts:\n        \($$vm.name | gsub("-"; "_")):\n          ansible_host: \($$vm.ipv4_address)"' \
	> $(INVENTORY)

configure: inventory
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

clean:
	cd $(TF_DIR) && terraform destroy -auto-approve
	rm -f $(INVENTORY)
