# 2. Adopt Development Best Practices

## Date

2026-02-18

## Status

Accepted

## Context

pve-openapi is a library and toolchain project in the pvex-suite. We need consistent development practices that enable high-quality, maintainable code while supporting AI-assisted development workflows.

## Decision

### 1. Testing Strategy

- **Framework**: ExUnit (async: true by default)
- **Coverage target**: >80% for core logic
- **Test organization**: `test/pve_openapi/` mirrors `lib/pve_openapi/`
- **Tagged tests**: `:integration` for tests requiring network or generated specs (excluded by default)
- **JUnit XML reports**: via `junit_formatter` for CI/CD integration

### 2. Semantic Versioning

- Follow [SemVer 2.0.0](https://semver.org/)
- During development: 0.2.x (increment patch per sprint)
- No stable 1.0 until the API surface is validated by all consumers
- Version defined in `mix.exs` `@version` module attribute

### 3. Git Workflow

- **Branch**: `main` (single branch, no gitflow — small library project)
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- **Tags**: `v0.2.x` annotated tags per sprint release

### 4. Change Documentation

- **Keep a Changelog** format in `CHANGELOG.md`
- Categories: Added, Changed, Deprecated, Removed, Fixed, Security
- Updated with each version bump (sprint wrapup)

### 5. Architecture as Code

- **C4 DSL** models in `architecture/` (when needed)
- Validated with structurizr/cli container
- ADRs use adr-tools `# N. Title` format for Structurizr `!adrs` integration

### 6. Documentation Framework

**Diataxis** structure in `docs/`:
- `tutorials/` — learning-oriented (when needed)
- `howto/` — problem-oriented (when needed)
- `reference/` — information-oriented (when needed)
- `explanation/` — understanding-oriented (when needed)

Project management directories:
- `adr/` — architecture decision records
- `sprints/` — sprint plans and retrospectives
- `roadmap/` — roadmap and phase tracking

### 7. Sprint-Based Development

- Lightweight sprints aligned with roadmap phases
- Sprint plans in `docs/sprints/sprint-NNNN-plan.md`
- Retrospectives in `docs/sprints/sprint-NNNN-retrospective.md` (or `.yml`)
- Roadmap in `docs/roadmap/roadmap.md`

### 8. Quality Automation

- **Code formatting**: `mix format`
- **Static analysis**: `mix credo --strict`
- **Type checking**: Dialyzer via `dialyxir`
- **Compilation**: `--warnings-as-errors`
- **Full pipeline**: `make validate` (format + compile + credo + dialyzer + test + spec validation)

### 9. Licensing and Copyright

- **Apache-2.0** for source code; generated specs contain AGPL-3.0 content from pve-docs
- SPDX headers (`SPDX-License-Identifier`, `Copyright`) on all source files

### 10. Code Conventions

- All specs are `.gitignored` — reproducible via `make setup`
- Pure Elixir pipeline — no shell scripts or external tool dependencies
- `x-pve-*` extensions preserve PVE-specific metadata in OpenAPI specs
- Stable `operationId` format across versions for meaningful diffs

## Consequences

### Positive

- Consistent practices across development sessions
- AI assistants have clear guidance on standards
- `make validate` catches issues early in a single command
- Sprint workflow provides structure without overhead

### Negative

- Dialyzer PLT build time on first run (~2-3 minutes)
- No pre-commit hooks yet (planned for CI sprint)

## References

- [AI-Assisted Project Orchestration](https://github.com/jrjsmrtn/ai-assisted-project-orchestration)
- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
