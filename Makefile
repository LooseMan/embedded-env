TF_DIR      := $(CURDIR)/terraform/simple-libvirt-vm
ANSIBLE_DIR := $(CURDIR)/ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/applied_hosts.yml
PLAYBOOK    := $(ANSIBLE_DIR)/playbook/playbook.yml

.PHONY: apply plan destroy inventory configure clean

build:
	cd $(TF_DIR) && terraform apply -auto-approve
	cd $(TF_DIR) && terraform output -raw ansible_applied_hosts > $(INVENTORY)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

clean:
	cd $(TF_DIR) && terraform destroy -auto-approve
	rm -f $(INVENTORY)
