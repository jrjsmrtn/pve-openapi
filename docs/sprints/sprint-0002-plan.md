# Sprint 2 — Contract Validation and Release Readiness

**Target Version**: v0.2.2
**Phase**: Enrichment
**Status**: Planned
**Started**: -

## Goal

Make contract validation type-aware, expose richer spec query APIs, and add CI and documentation polish for public release readiness.

## Context

`Contract.validate_request/4` only checks required parameter presence. The `Validator` module already has `validate_value/2` with full type/enum/min/max/pattern checking, but `Contract` does not use it. Connecting them makes contract testing useful for mock-pve-api. Consumer projects also need structured parameter/response queries without navigating raw OpenAPI JSON.

With Sprint 1 and this sprint adding significant API surface, CI and ExDoc improvements ensure quality is maintained and the public mirrors (Codeberg, GitHub) present well.

## Deliverables

### 1. Enhanced `Contract` module

- `validate_request/4` validates types and constraints via `Validator.validate_value/2`, not just presence
- Structured error format: `%{param: name, error: reason}` instead of plain strings

### 2. New `Spec` query functions

- `parameters_for(spec, path, method)` — structured parameter list (name, type, required, schema)
- `response_schema(spec, path, method, status_code)` — response schema extraction
- `required_parameters(spec, path, method)` — shortcut

### 3. Honor `specs_path` config

- Use `Application.compile_env(:pve_openapi, :specs_path, ...)` instead of hardcoded path

### 4. Forgejo CI

- `.forgejo/workflows/ci.yml` — compile, format, credo, test
- Excluded from CI: dialyzer (PLT cold start too slow), spec validation (specs not committed)

### 5. ADR-0006: CI Pipeline Scope

- Documents what's in and out of CI, and why

### 6. ExDoc improvements

- Add CHANGELOG.md to extras
- Add module grouping (Core, Diff/Compatibility, Pipeline, Validation)

### 7. README updates

- Library API examples (Spec query functions)

## Files

| Action | File |
|--------|------|
| Modify | `lib/pve_openapi/contract.ex` |
| Modify | `lib/pve_openapi/spec.ex` |
| Modify | `lib/pve_openapi.ex` |
| Modify | `test/pve_openapi/contract_test.exs` |
| Modify | `test/pve_openapi/spec_test.exs` |
| Modify | `mix.exs` |
| Modify | `CHANGELOG.md` |
| Modify | `README.md` |
| Create | `.forgejo/workflows/ci.yml` |
| Create | `docs/adr/0006-ci-pipeline-scope.md` |

## Acceptance Criteria

- [ ] `Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{"vmid" => "not_an_int"})` returns a type error
- [ ] `Spec.parameters_for(spec, path, method)` returns structured parameter list
- [ ] `Spec.response_schema(spec, path, method, 200)` returns the response schema map
- [ ] Config `specs_path` is respected at compile time
- [ ] Consumer integration (mock-pve-api Mix tasks) unaffected
- [ ] `.forgejo/workflows/ci.yml` exists and is syntactically valid
- [ ] `mix docs` generates documentation with CHANGELOG and module grouping
- [ ] `make validate` passes
- [ ] CHANGELOG.md updated
- [ ] Version bumped to 0.2.2
