# 7. Feature Matrix Abstraction

## Date

2026-03-27

## Status

Accepted

## Context

Consumer projects maintain hand-coded feature-to-version mappings:
- `MockPveApi.Capabilities` — 481 lines mapping PVE versions to feature atoms
- `Pvex.Compatibility` — 523 lines mapping feature atoms to minimum version tuples

These overlap and drift from the actual API. pve-openapi already has `VersionMatrix` for endpoint-level queries, but consumers need higher-level semantic queries like "is SDN available in this version?" rather than "does `/cluster/sdn/vnets` exist?"

## Decision

Add `PveOpenapi.FeatureMatrix` and `PveOpenapi.FeatureMatrix.Catalog` modules.

**Feature detection strategy**: A feature is available in a version if any of its indicator endpoints exist in that version's spec. This is a path-presence check, not a parameter or response check.

**Catalog as data**: The default catalog (`Catalog.default/0`) maps feature atoms to indicator paths. It is a list of `{atom, [path]}` tuples, overridable by consumers via `features_for_version/2`.

**Compile-time computation**: Feature availability is computed at compile time from the version matrix, like `VersionMatrix` itself. Zero runtime overhead.

**Feature atom alignment**: Atoms are chosen to match existing consumer usage where possible (`:sdn`, `:notification_system`, `:ha_rules`, `:resource_mappings`).

## Consequences

### Positive

- Consumers can query feature availability without maintaining their own version maps
- Single source of truth for "when was feature X introduced?"
- `feature_diff/2` enables automated migration guides between versions
- Custom catalogs allow consumers to define project-specific features

### Negative

- Path-presence detection may not capture features that exist under the same path but with different behavior across versions (mitigated: consumers can still use endpoint-level queries for fine-grained checks)
- Catalog needs manual curation when new PVE features are added (mitigated: auto-discovery of new paths via `Diff` module)
