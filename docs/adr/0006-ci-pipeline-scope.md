# 6. CI Pipeline Scope

## Date

2026-03-27

## Status

Accepted

## Context

pve-openapi needs automated quality checks on push and pull requests. The project has several quality gates (`make validate`) but not all are suitable for CI cold starts.

## Decision

The Forgejo CI pipeline (`.forgejo/workflows/ci.yml`) runs on push/PR to `main` and includes:

**Included:**
- `mix compile --warnings-as-errors`
- `mix format --check-formatted`
- `mix credo --strict`
- `mix test`

**Excluded:**
- **Dialyzer** — PLT build takes 2-3 minutes on cold start with no caching benefit across CI runs. Run locally via `make validate`.
- **Spec validation** (`mix pve_openapi.validate`) — specs are `.gitignored` and not available in CI. Validated locally after `make setup`.
- **Diff generation** — requires specs to be present. Run locally via `make diff`.
- **Architecture validation** (`make arch-validate`) — requires Podman and structurizr/cli container. Run locally.

## Consequences

### Positive

- Fast CI feedback (~1-2 minutes) on every push
- Catches formatting, compilation warnings, lint issues, and test failures
- No Podman/container dependency in CI

### Negative

- Dialyzer type errors caught only locally (mitigated: developers run `make validate`)
- Spec and architecture validation not automated (mitigated: reproducible via `make setup && make validate`)
