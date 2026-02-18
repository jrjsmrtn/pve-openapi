# ADR-0002: pve-openapi as Single Source of Truth for PVE API Definitions

## Status

Accepted

## Date

2026-02-18

## Context

Multiple projects in the pvex-suite maintain hand-curated PVE API endpoint catalogs:

- `MockPveApi.Capabilities` — version-to-endpoint capability mapping
- `MockPveApi.Coverage.*` — endpoint definitions with parameters
- `PvexAsh.VersionCompatibility` — feature-to-minimum-version mapping
- `PvexAsh.ApiCoverage.*` — endpoint definitions with Ash resource mappings

These overlap, can drift from each other and from the actual PVE API, and don't carry parameter schemas or response types.

PVE is open source. The API is defined in Perl via `PVE::RESTHandler::register_method()` and the `extractapi.pl` script in pve-docs generates the full API schema as `apidata.js`. This schema includes paths, HTTP methods, parameters with types and constraints, permissions, and return types.

Existing community efforts (LUMASERV/proxmox-ve-openapi, akikungz/pve-openapi) are unmaintained and single-version only.

## Decision

Create `pve-openapi` as a standalone project that:

1. **Extracts** `apidata.js` from historical `pve-docs` packages for PVE 7.0 through 9.0
2. **Converts** the PVE JSON schema tree to OpenAPI 3.1 specifications
3. **Provides** an Elixir library for querying specs, version matrices, and contract testing
4. **Generates** one OpenAPI 3.1 JSON spec per PVE version (not committed; reproducible via `make setup`)

Key technical choices:

- **Apache-2.0** for project source code (scripts, converter, Elixir library); generated specs contain descriptions from AGPL-3.0-licensed pve-docs
- **OpenAPI 3.1** (not 3.0) for proper JSON Schema alignment and nullable type support
- **`x-pve-*` extensions** to preserve PVE-specific metadata (permissions, protected flag, allowtoken, custom formats like `pve-vmid`)
- **`externalDocs` links** on every operation pointing to the official PVE API viewer
- **Stable `operationId`** format across versions for meaningful diffs
- **Extraction from `.deb` packages** directly from Proxmox no-subscription apt repos (no containers needed)
- **Mix tasks** for normalization, conversion, validation, and metadata generation (pure Elixir, no external runtime)
- **Standalone repo** with its own release cycle, consumable as a path dependency
- **Specs are .gitignored** — they are generated artifacts, keeping the repo lightweight

## Consequences

### Positive

- Single authoritative source for PVE API definitions across 11 versions
- Machine-readable version diffs enable automated compatibility checking
- Contract testing validates pvex and mock-pve-api against actual API specs
- Parameter schemas and response types available for validation and code generation
- Can be open-sourced independently as a community resource

### Negative

- Extraction pipeline depends on Proxmox apt repo availability
- OpenAPI conversion may not capture 100% of PVE's custom schema semantics
- Additional project to maintain in the suite

### Neutral

- Hand-maintained modules in pvex and mock-pve-api continue to exist for project-specific metadata (ash_resource, handler_module, example_response), but endpoint definitions delegate to pve-openapi
