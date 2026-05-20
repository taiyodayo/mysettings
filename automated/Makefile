# Convenience wrapper around ansible-playbook. Pass extra flags with EXTRA,
# e.g. `make kit EXTRA='--check --diff'` for a dry-run.

# Ensure pipx-installed ansible is findable by recipes even when the user
# hasn't restarted their shell after `make bootstrap`. pipx ensurepath writes
# ~/.local/bin to ~/.bashrc / ~/.zshrc, but the user's CURRENT shell only
# picks that up on next login. Prepending here means `make zsh` / `make kit`
# work immediately after `make bootstrap` in the same session.
export PATH := $(HOME)/.local/bin:$(PATH)

EXTRA ?=
PLAY  = ansible-playbook $(EXTRA)

.PHONY: help bootstrap collections kitting kit mac-kit motd macbook-hw gui audit purge purge-real postboot zsh llms

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*##' '{printf "  %-15s %s\n", $$1, $$2}'

bootstrap: ## Install ansible + Galaxy collections (cross-platform — brew on Mac, pipx on Linux)
	bash $(CURDIR)/bootstrap.sh

collections: ## Install ONLY the Galaxy collections (assumes ansible already present)
	ansible-galaxy collection install -r requirements.yml

kitting: ## Full kitting — cross-platform (Ubuntu or Mac, auto-detected via os_family)
	$(PLAY) kitting.yml --ask-become-pass

kit: ## Ubuntu-only kitting (back-compat — `kitting` is the new cross-platform one)
	$(PLAY) ubuntu_kitting.yml --ask-become-pass

mac-kit: ## Mac-only kitting (brew/defaults/dock/R + common_*.yml + cargo + uv/p313)
	$(PLAY) mac_kitting.yml

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

llms: ## Update claude / codex CLIs
	$(PLAY) llms_update.yml
