# Sprint 1 Retrospective

**Delivered**: yes — parameter-level diffs and persisted diff JSON
**Dropped**: nothing
**Key insight**: The PVE API evolves mostly by adding parameters to existing endpoints rather than adding/removing endpoints. The 7.4→8.0 transition has the most breaking changes (13), mostly parameter removals. Constraint changes (pattern, enum) are the most common non-breaking change type.
**Next candidate**: Sprint 2 — contract validation can now leverage the parameter extraction infrastructure built here.
