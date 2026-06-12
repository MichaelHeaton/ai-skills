.PHONY: help install install-system install-system-dry-run sync-from-system sync-from-system-apply \
	import-legacy bootstrap-version manifest-update unlink-legacy unlink-legacy-dry-run \
	lint lint-fix hooks-install \
	push-skills list-bundles

.DEFAULT_GOAL := help

LEGACY_REPO ?= $(abspath $(CURDIR)/../claude-skills)

help:
	@echo "ai-skills — available targets:"
	@echo ""
	@echo "  Deploy (copy-only — no symlinks):"
	@echo "    make install-system           Deploy ai/claude/ → ~/.claude/, rules → ~/.cursor/rules/"
	@echo "    make install-system-dry-run   Preview install"
	@echo "    make install                  Alias for install-system"
	@echo "    make sync-from-system         Dry-run: pull ~/.claude/ edits into repo"
	@echo "    make sync-from-system-apply   Apply sync (review diff before commit)"
	@echo ""
	@echo "  Cross-repo skill sync (for web/mobile access):"
	@echo "    make push-skills PROJECT=<path> [BUNDLE=<name>]"
	@echo "                                  Copy a skill bundle into another repo's .claude/skills/"
	@echo "    make list-bundles             Show available bundles and their skills"
	@echo ""
	@echo "  Lint (pre-commit — markdown, YAML, secrets on SKILL.md):"
	@echo "    make hooks-install            Install git commit + pre-push hooks"
	@echo "    make lint                     Run all hooks on the repo"
	@echo "    make lint-fix                 Same as lint (hooks auto-fix markdown)"
	@echo ""
	@echo "  Migration / maintenance:"
	@echo "    make import-legacy            Import ai/claude/ from claude-skills"
	@echo "    make bootstrap-version        Normalize version frontmatter"
	@echo "    make manifest-update          Regenerate .deploy/repo-manifest.json"
	@echo "    make unlink-legacy            Phase 0: materialize symlinks, migrate config"
	@echo "    make unlink-legacy-dry-run    Preview Phase 0"
	@echo ""

install: install-system

install-system:
	@bash scripts/install-system.sh

install-system-dry-run:
	@bash scripts/install-system.sh --dry-run

sync-from-system:
	@bash scripts/sync-from-system.sh --dry-run

sync-from-system-apply:
	@bash scripts/sync-from-system.sh --apply

import-legacy:
	@LEGACY_REPO="$(LEGACY_REPO)" bash scripts/import-from-legacy.sh

bootstrap-version:
	@bash scripts/bootstrap-version.sh

manifest-update:
	@bash scripts/manifest-update.sh

unlink-legacy:
	@bash scripts/unlink-legacy.sh

unlink-legacy-dry-run:
	@bash scripts/unlink-legacy.sh --dry-run

hooks-install:
	@command -v pre-commit >/dev/null || { echo "Install pre-commit: brew install pre-commit  (or pipx install pre-commit)"; exit 1; }
	pre-commit install
	pre-commit install --hook-type pre-push

lint lint-fix:
	@command -v pre-commit >/dev/null || { echo "Install pre-commit: brew install pre-commit  (or pipx install pre-commit)"; exit 1; }
	pre-commit run --all-files

push-skills:
	@test -n "$(PROJECT)" || { echo "Usage: make push-skills PROJECT=<path> [BUNDLE=<name>]"; exit 1; }
	@bash scripts/push-skills.sh "$(PROJECT)" "$(or $(BUNDLE),universal)"

list-bundles:
	@for f in skill-sets/*.txt; do \
		echo ""; \
		echo "── $$(basename $$f .txt) ──"; \
		grep -v '^#' $$f | grep -v '^$$' | sed 's/^/  /'; \
	done
	@echo ""
