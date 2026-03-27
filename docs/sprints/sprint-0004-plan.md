# Sprint 4 — Response Schema Quality Analysis

**Target Version**: v0.2.4
**Phase**: Enrichment
**Status**: Complete
**Started**: 2026-03-27

## Goal

Analyze response schema completeness across PVE versions so consumers can make informed decisions about which endpoints to cover with typed resources or mock responses.

## Context

PVE's `returns` definitions are often sparse — many endpoints return `{"type": "null"}` or `{"type": "any"}` even when they return structured data. Consumer projects generating mock responses (mock-pve-api) need to know which endpoints have rich schemas versus which are opaque.

## Deliverables

### 1. `PveOpenapi.SchemaQuality` module

- `analyze_endpoint(spec, path, method)` — returns `{:rich | :partial | :opaque, details}`
- `quality_report(version)` — per-endpoint assessments for entire version
- `quality_summary(version)` — aggregate stats (rich vs partial vs opaque)
- `quality_diff(from_version, to_version)` — endpoints whose response schemas improved/degraded

### 2. `mix pve_openapi.quality` task

- Summary table of response schema quality per version
- `--version VERSION` for single-version detail
- `--json` for machine-readable output
- `--opaque-only` to list only opaque endpoints

### 3. `Spec` response introspection

- `has_response_schema?(spec, path, method)` — quick boolean check
- `response_properties(spec, path, method, status_code)` — property names/types from response

## Files

| Action | File |
|--------|------|
| Create | `lib/pve_openapi/schema_quality.ex` |
| Create | `lib/mix/tasks/pve_openapi.quality.ex` |
| Modify | `lib/pve_openapi/spec.ex` |
| Create | `test/pve_openapi/schema_quality_test.exs` |
| Modify | `mix.exs` |
| Modify | `CHANGELOG.md` |
| Modify | `CLAUDE.md` |

## Acceptance Criteria

- [x] `SchemaQuality.analyze_endpoint(spec, "/version", :get)` returns `{:rich, ...}`
- [x] `SchemaQuality.quality_summary("9.0")` returns stats with counts
- [x] `mix pve_openapi.quality --version 9.0` prints a summary table
- [x] Endpoints with `type: "null"` or `type: "any"` returns classified as opaque
- [x] `make validate` passes (100 tests, 0 failures, dialyzer clean)
- [x] CHANGELOG.md updated
- [x] Version bumped to 0.2.4
