# Architecture as Code

pve-openapi uses the [C4 model](https://c4model.com/) with [Structurizr DSL](https://structurizr.com/) for architecture documentation.

## Structure

```
architecture/
  workspace.dsl       # C4 model definition (source of truth)
  shared/             # Shared DSL fragments (reserved)
  diagrams/           # Generated exports (.gitignored)
  README.md           # This file
```

The `docs/` directory is mounted into the container at validation/visualization time
(see Makefile `arch-validate` and `arch-viz` targets) to resolve `!adrs docs/adr`.

## Views

| View | Level | Description |
|------|-------|-------------|
| SystemContext | C4-1 | pve-openapi with external systems and consumers |
| Containers | C4-2 | Extraction Pipeline, Conversion Engine, Library API, Mix Tasks |
| ExtractionPipelineComponents | C4-3 | Fetcher, DebExtractor, Normalizer, HostFetcher |
| ConversionEngineComponents | C4-3 | Converter, PveTypes, SpecValidator |
| LibraryApiComponents | C4-3 | Core API, Spec, Endpoint, VersionMatrix, Diff, Contract, Validator |
| MixTasksComponents | C4-3 | Extract, Metadata, Clean orchestration tasks |
| ExtractionFlow | Dynamic | How a PVE version goes from .deb to OpenAPI spec |
| ConsumerQueryFlow | Dynamic | How consumers query endpoint availability |

## Commands

```bash
make arch-validate    # Validate workspace.dsl syntax
make arch-viz         # Start Structurizr Lite viewer (localhost:8080)
```
