<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 Georges Martin -->
# pve-openapi

OpenAPI 3.1 specifications for the Proxmox Virtual Environment (PVE) REST API, extracted from official PVE sources. Versions are discovered dynamically from the Proxmox apt repository (currently PVE 7.0 through 9.1).

## What This Is

PVE's API is defined in Perl via `PVE::RESTHandler::register_method()` and documented through the `extractapi.pl` script that ships with `pve-docs`. This project:

1. **Downloads** `pve-docs` .deb packages from Proxmox apt repos and extracts the API schema (`apidoc.js`) using pure Elixir (no external tools)
2. **Converts** it to standard OpenAPI 3.1 specifications with links to the [official PVE API viewer](https://pve.proxmox.com/pve-docs/api-viewer/)
3. **Provides** an Elixir library for querying specs, version matrices, diffs, feature availability, contract testing, and schema quality analysis

## Quick Start

### Setup

OpenAPI specs are generated from Proxmox apt packages (not committed to git). Generate them before compiling:

```bash
make setup          # Download, extract, convert, generate metadata + diffs
```

Requires: Elixir 1.15+ / OTP 26+ and system `liblzma` (for XZ decompression NIF). On macOS with MacPorts:

```bash
C_INCLUDE_PATH=/opt/local/include LIBRARY_PATH=/opt/local/lib mix deps.compile xz --force
```

### As a Dependency

Add to your `mix.exs`:

```elixir
{:pve_openapi, path: "../pve-openapi"}
```

## Library API

### Querying Specs

```elixir
# List available versions
PveOpenapi.versions()
#=> ["7.0", "7.1", ..., "9.1"]

# Get the full OpenAPI spec for a version
{:ok, spec} = PveOpenapi.spec("8.3")

# Query endpoints
PveOpenapi.endpoints("8.3")
#=> [%PveOpenapi.Endpoint{path: "/access", method: :get, ...}, ...]

# Look up a specific operation
{:ok, operation} = PveOpenapi.Spec.operation(spec, "/nodes/{node}/qemu", :post)
```

### Version Matrix

```elixir
# Check endpoint availability
PveOpenapi.VersionMatrix.endpoint_available?("/nodes/{node}/qemu", :get, "8.3")
#=> true

# Find when an endpoint was added
PveOpenapi.VersionMatrix.endpoint_added_in("/cluster/ha/rules", :get)
#=> "9.0"

# Get all endpoints for a version
PveOpenapi.VersionMatrix.endpoints_for_version("9.0")
#=> MapSet of {path, method} tuples
```

### Feature Matrix

High-level feature availability derived from endpoint presence:

```elixir
PveOpenapi.FeatureMatrix.feature_available?(:sdn_fabrics, "9.0")
#=> true

PveOpenapi.FeatureMatrix.feature_added_in(:notification_system)
#=> "8.1"

PveOpenapi.FeatureMatrix.features_for_version("9.0")
#=> [:acl_management, :backup_info, ..., :vm_management]

PveOpenapi.FeatureMatrix.feature_diff("8.4", "9.0")
#=> %{added: [:ha_rules, :sdn_fabrics], removed: []}
```

The default catalog is extensible:

```elixir
my_catalog = PveOpenapi.FeatureMatrix.Catalog.default() ++ [
  {:my_feature, ["/my/custom/path"]}
]
PveOpenapi.FeatureMatrix.features_for_version("9.0", my_catalog)
```

### Version Diffs

```elixir
# Endpoint-level diffs
PveOpenapi.Diff.added_endpoints("8.3", "9.0")
#=> [{"/cluster/ha/rules", :get}, ...]

# Parameter-level changes
PveOpenapi.Diff.parameter_changes("8.3", "8.4")
#=> [%{path: "/access/domains", method: :post, changes: [%{type: :constraint_changed, ...}]}]

# Breaking changes (removed endpoints, removed params, type changes)
PveOpenapi.Diff.breaking_changes("7.4", "8.0")
#=> [%{type: :endpoint_removed, path: ..., method: ...}, ...]

# Complete structured diff
PveOpenapi.Diff.full_diff("8.3", "9.0")

# Load pre-computed diff (falls back to runtime if not persisted)
PveOpenapi.Diff.load_diff("8.3", "8.4")
```

### Spec Queries

```elixir
spec = PveOpenapi.spec!("8.3")

# Structured parameter list
{:ok, params} = PveOpenapi.Spec.parameters_for(spec, "/nodes/{node}/qemu", :post)
#=> {:ok, [%{name: "vmid", type: "integer", required: true, in: "body", schema: ...}, ...]}

# Required parameters
{:ok, required} = PveOpenapi.Spec.required_parameters(spec, "/nodes/{node}/qemu", :post)
#=> {:ok, ["node", "vmid"]}

# Response schema
{:ok, schema} = PveOpenapi.Spec.response_schema(spec, "/version", :get, 200)

# Response property types
{:ok, props} = PveOpenapi.Spec.response_properties(spec, "/version", :get, 200)
#=> {:ok, %{"release" => "string", "version" => "string", ...}}
```

### Contract Validation

Type-aware request validation against OpenAPI parameter schemas:

```elixir
# Validates presence AND types/constraints
PveOpenapi.Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
  "vmid" => 100,
  "node" => "pve1"
})
#=> :ok

PveOpenapi.Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
  "vmid" => "not_an_int",
  "node" => "pve1"
})
#=> {:error, [%{param: "vmid", error: "Expected type integer, got \"not_an_int\""}]}

# Coverage analysis
PveOpenapi.Contract.validate_coverage("8.3", implemented_endpoints)
#=> {:ok, %{total: 605, covered: 37, missing: [...], coverage_pct: 6.1}}
```

### Schema Quality Analysis

Response schema completeness classification:

```elixir
spec = PveOpenapi.spec!("9.0")

PveOpenapi.SchemaQuality.analyze_endpoint(spec, "/version", :get)
#=> {:rich, %{type: "object", property_count: 5}}

PveOpenapi.SchemaQuality.quality_summary("9.0")
#=> %{rich: 390, partial: 54, opaque: 202, total: 646, version: "9.0"}
```

Or from the command line:

```bash
mix pve_openapi.quality
# Response Schema Quality by PVE Version
# Version   Rich    Partial   Opaque    Total   Rich %
# 7.0       298     62        147       507     58.8%
# ...
# 9.1       390     54        202       646     60.4%
```

## Mix Tasks

| Task | Description |
|------|-------------|
| `mix pve_openapi.extract` | Download and convert all PVE versions |
| `mix pve_openapi.fetch` | Download pve-docs .deb for a version |
| `mix pve_openapi.normalize` | Extract JSON from apidoc.js |
| `mix pve_openapi.convert` | Convert PVE JSON to OpenAPI 3.1 |
| `mix pve_openapi.validate` | Validate OpenAPI specs structurally |
| `mix pve_openapi.metadata` | Generate specs/metadata.json |
| `mix pve_openapi.diff` | Generate version diff JSON files |
| `mix pve_openapi.quality` | Analyze response schema quality |
| `mix pve_openapi.fetch_host` | Fetch API schema from a live PVE host |
| `mix pve_openapi.clean` | Remove all generated artifacts |

## Covered Versions

| Version | Debian | Paths | Operations |
|---------|--------|-------|------------|
| 7.0-7.4 | Bullseye | 340-364 | 507-540 |
| 8.0-8.4 | Bookworm | 368-398 | 549-605 |
| 9.0-9.1 | Trixie | 428 | 646 |

New PVE versions are auto-discovered from the Proxmox apt repository. No code changes required.

## License

This project's source code (extraction scripts, converter, Elixir library) is licensed under [Apache-2.0](LICENSE).

The generated OpenAPI specifications contain API descriptions extracted from [pve-docs](https://git.proxmox.com/?p=pve-docs.git), which is licensed under [AGPL-3.0-or-later](https://www.gnu.org/licenses/agpl-3.0.html) by [Proxmox Server Solutions GmbH](https://www.proxmox.com). Each operation includes an `externalDocs` link to the [official PVE API viewer](https://pve.proxmox.com/pve-docs/api-viewer/).
