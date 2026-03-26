# CLAUDE.md - pve-openapi

## Project Overview

**pve-openapi** is a standalone project that extracts, converts, and serves Proxmox VE API definitions as OpenAPI 3.1 specs. It provides a single source of truth for PVE API endpoint availability, parameters, and response types across supported PVE versions.

**App name:** `:pve_openapi`
**Branch:** `main`
**License:** Apache-2.0 (source code); generated specs contain AGPL-3.0 content from pve-docs
**Elixir:** 1.15+ / OTP 26+

## First-Time Setup

OpenAPI specs are not committed — they are generated artifacts:

```bash
make setup            # deps.get + extract all versions + generate metadata
```

Requires: system `liblzma` (for XZ decompression NIF). On macOS with MacPorts:

```bash
C_INCLUDE_PATH=/opt/local/include LIBRARY_PATH=/opt/local/lib mix deps.compile xz --force
```

## How It Works

The entire pipeline is native Elixir — no external tools (curl, ar, tar, Deno) required.

1. **Discovery**: `Fetch.discover_versions/0` queries the Proxmox apt repo (`Packages.gz` indexes from all distros), parses `pve-docs` entries, groups by major.minor, selects the latest patch per minor version, and filters by `@min_version {7, 0}`. No hardcoded version list.
2. **Fetch** (`mix pve_openapi.fetch`): Downloads `pve-docs` .deb via `:httpc`, extracts `apidoc.js` using `DebExtractor` (pure Elixir AR parsing, `:erl_tar`, XZ/gzip/zstd decompression via NIFs)
3. **Normalize** (`mix pve_openapi.normalize`): Strips the JS wrapper from `apidoc.js`, outputs clean JSON
4. **Convert** (`mix pve_openapi.convert`): Transforms PVE JSON schema tree into OpenAPI 3.1
5. **Validate** (`mix pve_openapi.validate`): Structural validation of generated OpenAPI 3.1 specs
6. **Metadata** (`mix pve_openapi.metadata`): Generates `specs/metadata.json` index
7. **Extract** (`mix pve_openapi.extract`): Orchestrator — runs fetch + normalize + convert for all (or specified) versions
8. **Clean** (`mix pve_openapi.clean`): Removes all generated spec artifacts
9. **Fetch Host** (`mix pve_openapi.fetch_host`): Fetches API schema from a live PVE host via `:httpc`

## Development Commands

```bash
mix deps.get              # Install dependencies
mix test                  # Run tests (45 tests)
mix format                # Format code
mix credo --strict        # Static analysis
mix dialyzer              # Type checking
make validate             # Full quality pipeline (format, compile, credo, dialyzer, test, specs)
```

### Extraction and Conversion

```bash
make setup                # Full setup (deps + extract + metadata)
make extract              # Extract and convert all PVE versions
make convert              # Re-convert only (without re-downloading)
make metadata             # Regenerate specs/metadata.json
make validate-specs       # Validate all OpenAPI specs
mix pve_openapi.clean     # Remove generated specs
```

## Version Discovery

Versions are discovered dynamically from the Proxmox apt repo at runtime:
- Distros listed from `http://download.proxmox.com/debian/pve/dists/`
- `Packages.gz` fetched and parsed for each distro
- PVE major version is in the package version string itself (no static major→distro mapping)
- Filtered by `@min_version {7, 0}` — only PVE 7.x+ included
- Adding a new PVE version requires zero code changes (auto-discovered)

## Architecture

```
pve-openapi/
  specs/                  # All .gitignored (generated via make setup)
    raw/                  # Downloaded apidoc.js + normalized JSON
    openapi/              # OpenAPI 3.1 specs (one per version)
    diffs/                # Pre-computed version diffs (placeholder)
    metadata.json         # Index of versions and endpoint counts
  lib/
    pve_openapi/          # Library modules
      deb_extractor.ex    # Pure Elixir .deb/AR/tar extraction
      pve_types.ex        # PVE format → OpenAPI type mapping
      spec.ex             # Spec loading and querying
      version_matrix.ex   # Endpoint availability across versions
      diff.ex             # Version diff computation
      contract.ex         # Contract validation
      endpoint.ex         # Endpoint struct
      validator.ex        # Structural OpenAPI validation
    mix/tasks/            # 9 Mix tasks (fetch, normalize, convert, extract, validate, metadata, clean, fetch_host)
  architecture/
    workspace.dsl         # C4 model (Structurizr DSL)
    shared/               # Shared DSL fragments
    README.md             # Architecture-as-code documentation
  test/                   # Tests (45)
  docs/
    adr/                  # Architecture Decision Records
    sprints/              # Sprint plans and retrospectives
    roadmap/              # Roadmap and phase tracking
```

## Key Conventions

- Apache-2.0 license with SPDX headers on all source files
- OpenAPI 3.1 (not 3.0) for proper JSON Schema alignment
- `x-pve-*` extensions preserve PVE-specific metadata
- `externalDocs` links on every operation point to official PVE API viewer
- Stable `operationId` format across versions for diffing
- All specs are .gitignored (reproducible via `make setup`)
- Pure Elixir pipeline — no shell scripts or external tool dependencies

## Consumers

- `mock-pve-api` — capability matrix, endpoint validation
- `pvex_admin` — (indirect, via pvex)

## Current Development Status

- **Current Sprint**: Between sprints (v0.2.0 complete)
- **Latest Release**: v0.2.0
- **Next Sprint**: Sprint 1 (see `docs/sprints/sprint-0001-plan.md`)
- **Next Milestone**: v0.2.1

## ADR Format

Use adr-tools title format: `# N. [title]` where N is the integer ADR number. This is required for Structurizr `!adrs` integration. Cross-references use `ADR-N` (e.g., "as decided in ADR-4").

Foundational ADRs (1-3) follow the project-orchestration-skills framework. Project-specific ADRs start at 4.
