# LockSmith demo — Makefile (Unix/macOS/Linux). Windows: use scripts\demo-day.ps1.
.DEFAULT_GOAL := help

SHELL := /bin/bash

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(patsubst %/,%,$(MAKEFILE_DIR))

# Override on the command line, e.g. `make locksmith-up PYTHON_BIN=python3.13`
PYTHON_BIN ?=
LOCKSMITH_BASE ?= locksmith-demo

export LOCKSMITH_BASE

.PHONY: help locksmith-up locksmith-down locksmith-reset-state locksmith-verify

help: ## Show available make targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

locksmith-up: ## Install deps, run smoke tests, launch LockSmith (scripts/demo-day.sh)
	cd "$(REPO_ROOT)" && \
		LOCKSMITH_BASE="$(LOCKSMITH_BASE)" \
		$(if $(strip $(PYTHON_BIN)),PYTHON_BIN="$(PYTHON_BIN)") \
		./scripts/demo-day.sh

locksmith-down: ## Stop a dev-launched LockSmith (matches python .../src/locksmith/main.py)
	-pkill -f '[/]src/locksmith/main\.py' 2>/dev/null || true

locksmith-reset-state: ## Delete on-disk demo data for LOCKSMITH_BASE (quit the app first)
	cd "$(REPO_ROOT)" && \
		LOCKSMITH_BASE="$(LOCKSMITH_BASE)" \
		./scripts/reset-demo-state.sh

locksmith-verify: ## Setup, Qt resources, smoke tests only — no GUI (SETUP_ONLY=1)
	cd "$(REPO_ROOT)" && \
		LOCKSMITH_BASE="$(LOCKSMITH_BASE)" \
		$(if $(strip $(PYTHON_BIN)),PYTHON_BIN="$(PYTHON_BIN)") \
		SETUP_ONLY=1 \
		./scripts/demo-day.sh
