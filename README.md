<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 Georges Martin -->
# pve-openapi

OpenAPI 3.1 specifications for the Proxmox Virtual Environment (PVE) REST API, extracted from official PVE sources. Versions are discovered dynamically from the Proxmox apt repository (currently PVE 7.0 through 9.1).

## What This Is

PVE's API is defined in Perl via `PVE::RESTHandler::register_method()` and documented through the `extractapi.pl` script that ships with `pve-docs`. This project:

1. **Downloads** `pve-docs` .deb packages from Proxmox apt repos and extracts the API schema (`apidoc.js`) using pure Elixir (no external tools)
2. **Converts** it to standard OpenAPI 3.1 specifications with links to the [official PVE API viewer](https://pve.proxmox.com/pve-docs/api-viewer/)
3. **Provides** an Elixir library for querying specs, version matrices, and contract testing

## Quick Start

### Setup

OpenAPI specs are generated from Proxmox apt packages (not committed to git). Generate them before compiling:

```bash
make setup          # Download, extract, convert all PVE versions + generate metadata
mix deps.get        # Install Elixir dependencies
mix compile         # Compile (loads specs at compile time)
```

Requires: system `liblzma` (for XZ decompression NIF)

### Elixir Library

Add to your `mix.exs`:

```elixir
{:pve_openapi, path: "../pve-openapi"}
```

```elixir
# List available versions
PveOpenapi.versions()
#=> ["7.0", "7.1", ..., "9.0"]

# Query endpoints for a version
PveOpenapi.endpoints("8.3")

# Check endpoint availability
PveOpenapi.VersionMatrix.endpoint_available?("/nodes/{node}/qemu", :get, "8.3")

# Find when an endpoint was added
PveOpenapi.VersionMatrix.endpoint_added_in("/cluster/ha/rules", :get)
#=> "9.0"

# Diff between versions
PveOpenapi.Diff.added_endpoints("8.3", "9.0")

# Contract validation
PveOpenapi.Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, params)
```

### Regenerating Specs

```bash
make extract        # Download pve-docs .deb packages and convert to OpenAPI 3.1
make convert        # Re-convert only (without re-downloading)
make metadata       # Regenerate specs/metadata.json
make validate-specs # Validate all OpenAPI specs
make validate       # Full quality pipeline (format, compile, credo, dialyzer, test, specs)
```

## Covered Versions

| Version | Debian | Paths | Operations |
|---------|--------|-------|------------|
| 7.0-7.4 | Bullseye | 340-364 | 507-540 |
| 8.0-8.4 | Bookworm | 368-398 | 549-605 |
| 9.0-9.1 | Trixie | 428 | 646 |

## License

This project's source code (extraction scripts, converter, Elixir library) is licensed under [Apache-2.0](LICENSE).

The generated OpenAPI specifications contain API descriptions extracted from [pve-docs](https://git.proxmox.com/?p=pve-docs.git), which is licensed under [AGPL-3.0-or-later](https://www.gnu.org/licenses/agpl-3.0.html) by [Proxmox Server Solutions GmbH](https://www.proxmox.com). Each operation includes an `externalDocs` link to the [official PVE API viewer](https://pve.proxmox.com/pve-docs/api-viewer/).
