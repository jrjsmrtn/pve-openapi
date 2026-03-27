# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.2] - 2026-03-27

### Added

- `PveOpenapi.Spec.parameters_for/3` — structured parameter list (name, type, required, in, schema)
- `PveOpenapi.Spec.response_schema/4` — response schema extraction by status code
- `PveOpenapi.Spec.required_parameters/3` — shortcut for required parameter names
- Forgejo CI pipeline (`.forgejo/workflows/ci.yml`) — compile, format, credo, test
- ADR-0006: CI Pipeline Scope
- ExDoc module grouping (Core, Version Compatibility, Validation, Pipeline)

### Changed

- `PveOpenapi.Contract.validate_request/4` now validates parameter types and constraints via `Validator.validate_value/2`, not just presence checking
- `PveOpenapi.Contract` errors are now structured maps (`%{param: name, error: reason}`) instead of plain strings
- `PveOpenapi` respects `specs_path` config via `Application.compile_env/3`
- ExDoc extras now include CHANGELOG.md and all ADRs

## [0.2.1] - 2026-03-27

### Added

- `PveOpenapi.Diff.parameter_changes/2` — detects parameter-level changes between versions (added/removed params, type changes, constraint changes, optional-to-required promotions)
- `PveOpenapi.Diff.full_diff/2` — complete structured diff suitable for JSON serialization
- `mix pve_openapi.diff` task — generates `specs/diffs/diff-{from}-{to}.json` for consecutive version pairs
- Pre-computed diff JSON files added to `make setup` pipeline
- ADR-0005: Persisted Version Diffs
- CHANGELOG.md

### Changed

- `PveOpenapi.Diff.breaking_changes/2` now also detects removed parameters, type-incompatible changes, and optional-to-required promotions (previously only detected removed endpoints and new required parameters)
- `make diff` target now generates all version diffs (was placeholder)
- `make setup` includes diff generation after metadata

## [0.2.0] - 2026-02-18

### Added

- Pure Elixir extraction pipeline: dynamic version discovery from Proxmox apt repo, .deb extraction, OpenAPI 3.1 conversion
- 12 PVE versions supported (7.0 through 9.1)
- Core library modules: `PveOpenapi`, `Spec`, `VersionMatrix`, `Diff`, `Contract`, `Validator`, `Endpoint`, `PveTypes`, `DebExtractor`
- 9 Mix tasks: fetch, normalize, convert, extract, validate, metadata, clean, fetch_host
- Makefile with setup, extract, convert, metadata, validate, validate-specs, test, clean targets
- ADR-0001: Record Architecture Decisions
- ADR-0002: Adopt Development Best Practices
- ADR-0003: Use Elixir and OpenAPI 3.1
- ADR-0004: pve-openapi as Single Source of Truth
