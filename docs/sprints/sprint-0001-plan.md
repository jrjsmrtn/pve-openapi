# Sprint 1 — Diff Infrastructure

**Target Version**: v0.2.1
**Phase**: Enrichment
**Status**: In Progress
**Started**: 2026-03-27

## Goal

Add parameter-level diff detection and persist version diffs as JSON files, making API evolution machine-readable for consumers and the public.

## Context

The `Diff` module detects added/removed endpoints and new required params at runtime, but `specs/diffs/` is empty and the Makefile `diff` target is a placeholder. Persisted diffs are foundational for everything downstream: feature matrix, consumer migration, and public release value.

## Deliverables

### 1. Enhanced `Diff` module

- `parameter_changes/2` — for common endpoints: added/removed params, type changes, constraint changes, optional-to-required promotions
- `full_diff/2` — complete structured diff as a serializable map
- Expand `breaking_changes/2` to include removed params and type-incompatible changes
- Existing functions unchanged (backward compatible)

### 2. New `mix pve_openapi.diff` task

- `--all` generates `specs/diffs/diff-{from}-{to}.json` for all consecutive version pairs
- `--from VERSION --to VERSION` for a single pair
- JSON format: `{from, to, generated_at, added_endpoints, removed_endpoints, parameter_changes, summary}`

### 3. Makefile updates

- Update `diff` target to call `mix pve_openapi.diff --all`
- Add diff generation to `setup` target (after metadata)

### 4. ADR-0005: Persisted Version Diffs

- Diff JSON format and rationale

### 5. CHANGELOG.md

- Create with Keep a Changelog format
- Retroactive v0.2.0 entry, plus v0.2.1 section

## Files

| Action | File |
|--------|------|
| Modify | `lib/pve_openapi/diff.ex` |
| Create | `lib/mix/tasks/pve_openapi.diff.ex` |
| Modify | `test/pve_openapi/diff_test.exs` |
| Modify | `Makefile` |
| Modify | `mix.exs` |
| Modify | `CLAUDE.md` |
| Create | `docs/adr/0005-persisted-version-diffs.md` |
| Create | `CHANGELOG.md` |

## Acceptance Criteria

- [ ] `mix pve_openapi.diff --all` produces one JSON file per consecutive version pair in `specs/diffs/`
- [ ] `PveOpenapi.Diff.parameter_changes("8.3", "8.4")` returns structured parameter-level changes
- [ ] `PveOpenapi.Diff.breaking_changes/2` reports removed parameters and type-breaking changes
- [ ] All existing tests pass; new tests cover new functions
- [ ] `make validate` passes
- [ ] CHANGELOG.md exists with v0.2.0 and v0.2.1 entries
- [ ] Version bumped to 0.2.1
