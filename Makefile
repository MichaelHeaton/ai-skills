.PHONY: help import-legacy bootstrap-version manifest-update unlink-legacy unlink-legacy-dry-run

.DEFAULT_GOAL := help

LEGACY_REPO ?= $(abspath $(CURDIR)/../claude-skills)

help:
	@echo "ai-skills — available targets:"
	@echo ""
	@echo "  make import-legacy          Import ai/claude/ from claude-skills (large; run when ready)"
	@echo "  make bootstrap-version      Add version frontmatter to imported SKILL.md files"
	@echo "  make manifest-update        Regenerate .deploy/repo-manifest.json"
	@echo "  make unlink-legacy          Phase 0: materialize ~/.claude, migrate config"
	@echo "  make unlink-legacy-dry-run  Preview Phase 0"
	@echo ""

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
