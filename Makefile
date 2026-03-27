# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin

.PHONY: help setup extract convert metadata validate-specs validate diff clean arch-validate arch-viz

SPECS_DIR = specs/openapi
RAW_DIR = specs/raw

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: deps extract metadata diff ## Compile, extract, convert, generate metadata and diffs
	@echo ""
	@echo "Setup complete. You can now run: mix compile"

deps: ## Install and compile Elixir dependencies
	mix deps.get
	mix compile

extract: ## Extract apidata.js and convert to OpenAPI 3.1 for all PVE versions
	mix pve_openapi.extract

convert: ## Re-convert all raw specs to OpenAPI 3.1 (without re-downloading)
	@for f in $(RAW_DIR)/pve-*.json; do \
		[ -f "$$f" ] || continue; \
		v=$$(basename "$$f" .json | sed 's/^pve-//'); \
		mix pve_openapi.convert "$$f" "$(SPECS_DIR)/pve-$$v.json" --version "$$v"; \
	done

metadata: ## Generate specs/metadata.json from OpenAPI specs
	mix pve_openapi.metadata

validate-specs: ## Validate all OpenAPI specs structurally
	@mix pve_openapi.validate $(wildcard $(SPECS_DIR)/pve-*.json)

validate: ## Full quality pipeline (format, compile, credo, dialyzer, test, specs)
	mix format --check-formatted
	mix compile --warnings-as-errors
	mix credo --strict
	mix dialyzer
	mix test
	@if ls $(SPECS_DIR)/pve-*.json >/dev/null 2>&1; then \
		$(MAKE) validate-specs; \
	fi

test: ## Run tests
	mix test

diff: ## Generate version diffs for all consecutive pairs
	mix pve_openapi.diff --all

arch-validate: ## Validate C4 architecture model
	podman run --rm \
		-v "$(CURDIR)/architecture:/usr/local/structurizr:z" \
		-v "$(CURDIR)/docs:/usr/local/structurizr/docs:z,ro" \
		structurizr/cli validate -w /usr/local/structurizr/workspace.dsl

arch-viz: ## Start Structurizr Lite viewer (localhost:8080)
	podman run --rm -d -p 8080:8080 \
		-v "$(CURDIR)/architecture:/usr/local/structurizr:z" \
		-v "$(CURDIR)/docs:/usr/local/structurizr/docs:z,ro" \
		structurizr/lite
	@echo "Structurizr Lite running at http://localhost:8080"

clean: ## Clean all generated artifacts
	mix pve_openapi.clean
	mix clean
	rm -rf _build deps
