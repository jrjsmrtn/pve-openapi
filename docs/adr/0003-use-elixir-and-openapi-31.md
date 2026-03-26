# 3. Use Elixir and OpenAPI 3.1

## Date

2026-02-18

## Status

Accepted

## Context

pve-openapi needs to extract PVE API definitions from Debian packages, convert them to a standard machine-readable format, and provide a queryable library for consumer projects in the pvex-suite.

Key requirements:
- Parse `.deb` archives (AR format, tar, XZ/gzip/zstd compression)
- Download files over HTTP with SSL verification
- Convert PVE's custom JSON schema tree to a standard API specification format
- Provide compile-time loading for zero-runtime-overhead queries
- Integrate as a path dependency with other Elixir projects in the suite

## Decision

We will use **Elixir 1.15+ / OTP 26+** as the implementation language and **OpenAPI 3.1** as the output format.

**Core Technologies**:
- **Language**: Elixir 1.15+ / OTP 26+
- **Output format**: OpenAPI 3.1 JSON specs
- **HTTP**: Erlang `:httpc` (stdlib, no external dependency)
- **Archive parsing**: Pure Elixir binary pattern matching for AR format, `:erl_tar` for tar
- **Decompression**: `xz` NIF (XZ), `:zlib` (gzip), `ezstd` NIF (zstd)
- **JSON**: Jason
- **Documentation**: ExDoc

**Rationale**:
- Elixir is the language of the entire pvex-suite — no polyglot overhead
- OTP's `:httpc` and `:erl_tar` eliminate external HTTP/archive tool dependencies
- Elixir's binary pattern matching makes AR archive parsing straightforward
- Compile-time module attributes with `@external_resource` enable zero-cost spec loading
- Mix tasks provide a natural CLI interface for the extraction pipeline

**OpenAPI 3.1 (not 3.0) Rationale**:
- Full JSON Schema alignment (3.0 uses a modified subset)
- Native `type: ["string", "null"]` instead of `nullable: true` workaround
- Better representation of PVE's complex parameter types

**Alternatives Considered**:

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Elixir + OpenAPI 3.1 | Suite consistency, compile-time loading, pure binary parsing | NIF dependencies for XZ/zstd | Selected |
| Deno/TypeScript | JSON-native, existing community converters | Polyglot, no compile-time integration, separate runtime | Rejected |
| Python | Rich OpenAPI tooling ecosystem | Polyglot, no compile-time loading, separate runtime | Rejected |
| OpenAPI 3.0 | Wider tooling support | No proper JSON Schema alignment, nullable workarounds | Rejected |

## Consequences

### Positive

- Single language across the entire pvex-suite
- No external tools required (no curl, ar, tar, Deno)
- Compile-time spec loading enables zero-runtime overhead for version queries
- OpenAPI 3.1 provides proper JSON Schema alignment for PVE's type system

### Negative

- NIF dependencies (xz, ezstd) require system libraries (`liblzma`) at compile time
- Smaller OpenAPI 3.1 tooling ecosystem compared to 3.0
- Elixir is less common for spec-generation tooling than TypeScript/Python

### Risks

- Proxmox could change `.deb` package format or compression → mitigated by supporting all three formats (XZ, gzip, zstd)
- OpenAPI 3.1 tooling gaps → mitigated by generating standard-compliant JSON that 3.0 tools can mostly consume

## References

- [OpenAPI 3.1 Specification](https://spec.openapis.org/oas/v3.1.0)
- [OpenAPI 3.1 vs 3.0](https://www.openapis.org/blog/2021/02/16/migrating-from-openapi-3-0-to-3-1-0)
- [Erlang :httpc documentation](https://www.erlang.org/doc/man/httpc)
