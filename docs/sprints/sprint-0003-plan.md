# Sprint 3 — Feature Matrix and Consumer Enablement

**Target Version**: v0.2.3
**Phase**: Enrichment
**Status**: Complete
**Started**: 2026-03-27

## Goal

Expose high-level feature/capability queries so consumer projects can replace hand-maintained ~500-line capability modules with pve-openapi lookups.

## Context

Consumer projects maintain hand-coded feature matrices:
- `MockPveApi.Capabilities` (481 lines) — version-to-feature mapping
- `Pvex.Compatibility` (523 lines) — hardcoded feature requirements

These overlap and can drift from the actual API. pve-openapi can auto-derive feature availability from its specs, providing a single source of truth. This sprint adds that layer; the actual consumer migration happens in those projects.

## Deliverables

### 1. `PveOpenapi.FeatureMatrix` module

- Auto-derives feature groups from OpenAPI tags and path prefixes
- `feature_available?(feature_atom, version)` — boolean
- `feature_added_in(feature_atom)` — earliest version
- `features_for_version(version)` — list of available feature atoms
- `feature_diff(from_version, to_version)` — added/removed features
- Grouping rules as data, overridable by consumers

### 2. `PveOpenapi.FeatureMatrix.Catalog` module

- Default grouping catalog aligned with existing consumer atoms: `:sdn`, `:ha_affinity`, `:backup_providers`, `:device_passthrough`, etc.
- Maps tag/path-prefix to semantic feature atom

### 3. `Diff.load_diff/2`

- Loads from persisted JSON in `specs/diffs/` if available, computes at runtime if not

### 4. ADR-0007: Feature Matrix Abstraction

## Files

| Action | File |
|--------|------|
| Create | `lib/pve_openapi/feature_matrix.ex` |
| Create | `lib/pve_openapi/feature_matrix/catalog.ex` |
| Modify | `lib/pve_openapi/diff.ex` |
| Create | `test/pve_openapi/feature_matrix_test.exs` |
| Modify | `test/pve_openapi/diff_test.exs` |
| Create | `docs/adr/0007-feature-matrix-abstraction.md` |
| Modify | `mix.exs` |
| Modify | `CHANGELOG.md` |

## Acceptance Criteria

- [x] `FeatureMatrix.feature_available?(:ha_rules, "9.0")` returns `true`
- [x] `FeatureMatrix.feature_available?(:ha_rules, "8.3")` returns `false`
- [x] `FeatureMatrix.features_for_version("9.0")` includes features from existing consumer catalogs
- [x] `FeatureMatrix.feature_added_in(:sdn)` returns `"7.0"`
- [x] Feature atom names align with existing consumer usage
- [x] `Diff.load_diff("8.3", "8.4")` returns structured diff data
- [x] `make validate` passes (86 tests, 0 failures, dialyzer clean)
- [x] CHANGELOG.md updated
- [x] Version bumped to 0.2.3
