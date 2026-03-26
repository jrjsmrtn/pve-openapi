workspace {
    name "pve-openapi Architecture"
    description "C4 Architecture Model for pve-openapi — OpenAPI 3.1 specs for PVE API"

    !identifiers hierarchical
    !adrs docs/adr

    model {
        properties {
            "structurizr.groupSeparator" "/"
        }

        # External Actors
        developer = person "Suite Developer" "Developer working on pvex-suite projects" "Developer"
        communityUser = person "Community User" "External user consuming OpenAPI specs" "CommunityUser"

        # External Systems
        proxmoxRepo = softwareSystem "Proxmox Apt Repository" "Debian package repository hosting pve-docs .deb packages" "External"
        pveHost = softwareSystem "PVE Host" "Live Proxmox VE server with API schema endpoint" "External"

        # Consumer Systems
        mockPveApi = softwareSystem "mock-pve-api" "Mock PVE API server — uses endpoint matrix for version-aware simulation" "Consumer"
        pvex = softwareSystem "pvex" "Core PVE API client library — future consumer for feature compatibility" "Consumer"

        # Main System
        pveOpenapi = softwareSystem "pve-openapi" "Extracts, converts, and serves Proxmox VE API definitions as OpenAPI 3.1 specs across 12 PVE versions (7.0-9.1)" {
            tags "PveOpenapi"

            # Containers
            extractionPipeline = container "Extraction Pipeline" "Downloads pve-docs .deb packages, extracts apidoc.js, normalizes JSON" "Elixir, :httpc, DebExtractor" {
                tags "Pipeline"

                fetcher = component "Fetcher" "Discovers PVE versions from apt repo, downloads .deb packages" "Mix.Tasks.PveOpenapi.Fetch"
                debExtractor = component "Deb Extractor" "Pure Elixir AR/tar parsing with XZ/gzip/zstd decompression" "PveOpenapi.DebExtractor"
                normalizer = component "Normalizer" "Strips JS wrapper from apidoc.js, outputs clean JSON" "Mix.Tasks.PveOpenapi.Normalize"
                hostFetcher = component "Host Fetcher" "Fetches API schema from live PVE host via HTTPS" "Mix.Tasks.PveOpenapi.FetchHost"
            }

            conversionEngine = container "Conversion Engine" "Transforms PVE JSON schema tree into OpenAPI 3.1 specs" "Elixir, Jason" {
                tags "Engine"

                converter = component "Converter" "Walks PVE schema tree, builds OpenAPI 3.1 paths/operations/parameters" "Mix.Tasks.PveOpenapi.Convert"
                pveTypes = component "PVE Types" "Maps PVE custom formats to OpenAPI types, preserves x-pve-* extensions" "PveOpenapi.PveTypes"
                specValidator = component "Spec Validator" "Structural validation of generated OpenAPI 3.1 specs" "Mix.Tasks.PveOpenapi.Validate"
            }

            libraryApi = container "Library API" "Compile-time loaded specs with query, diff, contract, and version matrix functions" "Elixir" {
                tags "Library"

                coreApi = component "Core API" "Loads specs at compile time, provides versions/spec/endpoints/metadata queries" "PveOpenapi"
                spec = component "Spec" "Single-spec querying: endpoints, stats, operations, parameters" "PveOpenapi.Spec"
                endpoint = component "Endpoint" "Endpoint struct: path, method, parameters, responses, extensions" "PveOpenapi.Endpoint"
                versionMatrix = component "Version Matrix" "Compile-time endpoint availability across all PVE versions" "PveOpenapi.VersionMatrix"
                diff = component "Diff" "Version diff computation: added/removed endpoints, breaking changes" "PveOpenapi.Diff"
                contract = component "Contract" "Coverage validation, request/response validation against specs" "PveOpenapi.Contract"
                validator = component "Validator" "Parameter value validation: type, enum, min/max, pattern" "PveOpenapi.Validator"
            }

            mixTasks = container "Mix Tasks / CLI" "Orchestration tasks for extraction, conversion, metadata, and cleanup" "Elixir Mix Tasks" {
                tags "CLI"

                extractTask = component "Extract Task" "Orchestrator: fetch + normalize + convert for all or specified versions" "Mix.Tasks.PveOpenapi.Extract"
                metadataTask = component "Metadata Task" "Generates specs/metadata.json index from OpenAPI specs" "Mix.Tasks.PveOpenapi.Metadata"
                cleanTask = component "Clean Task" "Removes all generated spec artifacts" "Mix.Tasks.PveOpenapi.Clean"
            }
        }

        # Relationships - External to System
        developer -> pveOpenapi "Runs extraction pipeline and queries specs" "Mix Tasks / Elixir API"
        communityUser -> pveOpenapi "Consumes generated OpenAPI specs" "JSON files"

        # Relationships - System to External
        pveOpenapi -> proxmoxRepo "Downloads pve-docs .deb packages from" "HTTP/HTTPS"
        pveOpenapi -> pveHost "Fetches live API schema from" "HTTPS"

        # Relationships - Consumer Systems
        mockPveApi -> pveOpenapi "Generates EndpointMatrix from" "Path dependency (dev)"
        pvex -> pveOpenapi "Future: replace Pvex.Compatibility with" "Path dependency"

        # Relationships - Container to Container
        pveOpenapi.extractionPipeline -> proxmoxRepo "Downloads .deb packages from" "HTTP/HTTPS"
        pveOpenapi.extractionPipeline -> pveHost "Fetches API schema from" "HTTPS"
        pveOpenapi.conversionEngine -> pveOpenapi.extractionPipeline "Reads normalized JSON from" "File system (specs/raw/)"
        pveOpenapi.libraryApi -> pveOpenapi.conversionEngine "Loads generated OpenAPI specs from" "File system (specs/openapi/)"
        pveOpenapi.mixTasks -> pveOpenapi.extractionPipeline "Orchestrates fetch + normalize" "Function calls"
        pveOpenapi.mixTasks -> pveOpenapi.conversionEngine "Orchestrates convert + validate" "Function calls"
        pveOpenapi.mixTasks -> pveOpenapi.libraryApi "Generates metadata from" "Function calls"

        # Relationships - Within Extraction Pipeline
        pveOpenapi.extractionPipeline.fetcher -> proxmoxRepo "Discovers versions, downloads .deb" "HTTP/HTTPS"
        pveOpenapi.extractionPipeline.fetcher -> pveOpenapi.extractionPipeline.debExtractor "Extracts apidoc.js from .deb" "Function calls"
        pveOpenapi.extractionPipeline.hostFetcher -> pveHost "Fetches /api2/json schema" "HTTPS"
        pveOpenapi.extractionPipeline.normalizer -> pveOpenapi.extractionPipeline.fetcher "Reads raw apidoc.js from" "File system"

        # Relationships - Within Conversion Engine
        pveOpenapi.conversionEngine.converter -> pveOpenapi.conversionEngine.pveTypes "Maps PVE types to OpenAPI schemas" "Function calls"
        pveOpenapi.conversionEngine.specValidator -> pveOpenapi.conversionEngine.converter "Validates generated specs from" "File system"

        # Relationships - Within Library API
        pveOpenapi.libraryApi.coreApi -> pveOpenapi.libraryApi.spec "Delegates spec queries to" "Function calls"
        pveOpenapi.libraryApi.spec -> pveOpenapi.libraryApi.endpoint "Builds endpoint structs" "Function calls"
        pveOpenapi.libraryApi.versionMatrix -> pveOpenapi.libraryApi.coreApi "Loads specs at compile time from" "Module attributes"
        pveOpenapi.libraryApi.diff -> pveOpenapi.libraryApi.versionMatrix "Computes endpoint set differences using" "Function calls"
        pveOpenapi.libraryApi.contract -> pveOpenapi.libraryApi.versionMatrix "Validates coverage against" "Function calls"
        pveOpenapi.libraryApi.contract -> pveOpenapi.libraryApi.validator "Validates parameter values with" "Function calls"
        pveOpenapi.libraryApi.contract -> pveOpenapi.libraryApi.spec "Queries operations from" "Function calls"

        # Relationships - Within Mix Tasks / cross-container
        pveOpenapi.mixTasks.extractTask -> pveOpenapi.extractionPipeline.fetcher "Invokes fetch for each version" "Function calls"
        pveOpenapi.mixTasks.extractTask -> pveOpenapi.extractionPipeline.normalizer "Invokes normalize for each version" "Function calls"
        pveOpenapi.mixTasks.extractTask -> pveOpenapi.conversionEngine.converter "Invokes convert for each version" "Function calls"
        pveOpenapi.mixTasks.metadataTask -> pveOpenapi.libraryApi.spec "Reads spec stats from" "Function calls"
    }

    views {
        # System Context View
        systemContext pveOpenapi "SystemContext" {
            title "pve-openapi — System Context"
            description "pve-openapi and its relationships with external systems and consumers"
            include *
            autoLayout lr
        }

        # Container View
        container pveOpenapi "Containers" {
            title "pve-openapi — Container View"
            description "Logical containers: extraction pipeline, conversion engine, library API, and CLI"
            include *
            autoLayout tb
        }

        # Component View - Extraction Pipeline
        component pveOpenapi.extractionPipeline "ExtractionPipelineComponents" {
            title "Extraction Pipeline — Component View"
            description "Version discovery, .deb download, AR/tar extraction, JSON normalization"
            include *
            autoLayout tb
        }

        # Component View - Conversion Engine
        component pveOpenapi.conversionEngine "ConversionEngineComponents" {
            title "Conversion Engine — Component View"
            description "PVE schema to OpenAPI 3.1 transformation and validation"
            include *
            autoLayout tb
        }

        # Component View - Library API
        component pveOpenapi.libraryApi "LibraryApiComponents" {
            title "Library API — Component View"
            description "Compile-time loaded specs with query, diff, contract, and version matrix"
            include *
            autoLayout tb
        }

        # Component View - Mix Tasks
        component pveOpenapi.mixTasks "MixTasksComponents" {
            title "Mix Tasks — Component View"
            description "Orchestration tasks for the extraction and conversion pipeline"
            include *
            autoLayout tb
        }

        # Dynamic View - Extraction Flow (container level)
        dynamic pveOpenapi "ExtractionFlow" {
            title "Extraction Pipeline Flow"
            description "How a PVE version is extracted from .deb to OpenAPI spec"

            pveOpenapi.mixTasks -> pveOpenapi.extractionPipeline "1. Fetch .deb and extract apidoc.js"
            pveOpenapi.extractionPipeline -> proxmoxRepo "2. Download pve-docs .deb"
            pveOpenapi.mixTasks -> pveOpenapi.extractionPipeline "3. Normalize apidoc.js to JSON"
            pveOpenapi.mixTasks -> pveOpenapi.conversionEngine "4. Convert JSON to OpenAPI 3.1"
            pveOpenapi.conversionEngine -> pveOpenapi.extractionPipeline "5. Read normalized JSON"

            autoLayout lr
        }

        # Dynamic View - Consumer Query Flow (container level)
        dynamic pveOpenapi "ConsumerQueryFlow" {
            title "Consumer Query Flow"
            description "How a consumer project queries endpoint availability"

            pveOpenapi.libraryApi -> pveOpenapi.conversionEngine "1. Load generated OpenAPI specs at compile time"
            pveOpenapi.mixTasks -> pveOpenapi.libraryApi "2. Generate metadata from loaded specs"

            autoLayout lr
        }

        styles {
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Developer" {
                background #1168bd
            }
            element "CommunityUser" {
                background #6b8e23
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "PveOpenapi" {
                background #2e8b57
                color #ffffff
            }
            element "External" {
                background #95a5a6
                color #ffffff
            }
            element "Consumer" {
                background #e67e22
                color #ffffff
            }
            element "Container" {
                background #3498db
                color #ffffff
            }
            element "Pipeline" {
                background #e74c3c
                color #ffffff
            }
            element "Engine" {
                background #9b59b6
                color #ffffff
            }
            element "Library" {
                background #2ecc71
                color #000000
            }
            element "CLI" {
                background #f1c40f
                color #000000
            }
            element "Component" {
                background #85c1e9
                color #000000
            }
            relationship "Relationship" {
                routing orthogonal
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}
