# Sprint 2 Retrospective

**Delivered**: yes — type-aware contract validation, spec query APIs, Forgejo CI, ExDoc improvements
**Dropped**: nothing
**Key insight**: The parameter extraction logic in Sprint 1's Diff module (extract_all_params) and Sprint 2's Spec module (extract_parameters) are structurally similar. If a third consumer appears, consider extracting a shared helper. For now, the slight duplication is acceptable since they serve different return shapes.
**Next candidate**: Sprint 3 — feature matrix can build on the parameter extraction and version matrix infrastructure.
