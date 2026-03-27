# pve-openapi Roadmap

## Phase 1: Foundation (Complete)

Establish the extraction pipeline, core library modules, and initial consumer integration.

- [x] Pure Elixir .deb extraction pipeline (fetch, normalize, convert)
- [x] Dynamic version discovery from Proxmox apt repo
- [x] OpenAPI 3.1 spec generation for 12 PVE versions (7.0-9.1)
- [x] Core library: Spec, VersionMatrix, Diff, Contract, Validator, Endpoint
- [x] 9 Mix tasks
- [x] Consumer integration: EndpointMatrix generation for mock-pve-api
- [x] ADR-0001 through ADR-0004

**Delivered in**: v0.2.0 (Sprint 0 / initial commit)

## Phase 2: Enrichment (Planned)

Deepen the library's analytical capabilities, add CI, and enable consumers to replace hand-maintained catalogs.

- [x] Parameter-level version diffs and persisted diff JSON (Sprint 1, v0.2.1)
- [x] Type-aware contract validation and spec query APIs (Sprint 2, v0.2.2)
- [x] Forgejo CI pipeline, ExDoc improvements (Sprint 2, v0.2.2)
- [x] Feature matrix abstraction for semantic capability queries (Sprint 3, v0.2.3)
- [ ] Response schema quality analysis (Sprint 4, v0.2.4)

## Sprint History

| Sprint | Phase | Version | Status | Date |
|--------|-------|---------|--------|------|
| 0 | Foundation | v0.2.0 | Complete | 2026-02-18 |
| 1 | Enrichment | v0.2.1 | Complete | 2026-03-27 |
| 2 | Enrichment | v0.2.2 | Complete | 2026-03-27 |
| 3 | Enrichment | v0.2.3 | Complete | 2026-03-27 |
