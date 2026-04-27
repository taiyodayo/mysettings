# Convenience wrapper around ansible-playbook. Pass extra flags with EXTRA,
# e.g. `make kit EXTRA='--check --diff'` for a dry-run.

EXTRA ?=
PLAY  = ansible-playbook $(EXTRA)

.PHONY: help bootstrap kit motd macbook-hw gui audit purge purge-real postboot zsh llms

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*##' '{printf "  %-15s %s\n", $$1, $$2}'

bootstrap: ## Install required Ansible collections (one-time)
	ansible-galaxy collection install -r requirements.yml

kit: ## Full Ubuntu server kitting
	$(PLAY) ubuntu_kitting.yml --ask-become-pass

motd: ## Strip Ubuntu MOTD ads
	$(PLAY) ubuntu_motd.yml --ask-become-pass

macbook-hw: ## MacBook10,1 SPI keyboard + audio fixes
	$(PLAY) ubuntu_macbook_hw.yml --ask-become-pass

gui: ## Workstation GUI tools (Chrome, Android Studio, JDK, Fira Code)
	$(PLAY) ubuntu_gui_tools.yml --ask-become-pass

audit: ## Pre-reboot safety audit (read-only)
	$(PLAY) ubuntu_superclean.yml --ask-become-pass

purge: ## DESTRUCTIVE: mark-and-nuke preview (no changes)
	$(PLAY) ubuntu_superclean.yml --ask-become-pass --tags purge

purge-real: ## DESTRUCTIVE: mark-and-nuke + apt autoremove --purge
	$(PLAY) ubuntu_superclean.yml --ask-become-pass --tags purge -e apply_purge=true

postboot: ## Post-boot smoke test (docker hello-world)
	$(PLAY) ubuntu_superclean.yml --ask-become-pass --tags postboot

zsh: ## zsh + (optional) GitHub key import. Pass GH=<github_user>
	$(PLAY) zsh_and_keys.yml --ask-become-pass $(if $(GH),-e github_username=$(GH))

llms: ## Update gemini / claude / codex CLIs
	$(PLAY) llms_update.yml
