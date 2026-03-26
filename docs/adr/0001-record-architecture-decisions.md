# 1. Record Architecture Decisions

## Date

2026-02-18

## Status

Accepted

## Context

As pve-openapi evolves across multiple sprints, architectural decisions accumulate. Without a record, future contributors (including AI assistants resuming work in new sessions) lack the reasoning behind key choices and may revisit settled questions or make contradictory decisions.

This project is part of the pvex-suite, where multiple projects share conventions. A lightweight, version-controlled decision log keeps the cost of documentation low while preserving the "why" behind structural choices.

## Decision

We will use Architecture Decision Records (ADRs) as described by Michael Nygard in "Documenting Architecture Decisions".

**Format:**
- Files named `NNNN-title-with-hyphens.md` (four-digit sequential, no gaps)
- Title line uses adr-tools format: `# N. Title` (required for Structurizr `!adrs` integration)
- Cross-references use `ADR-N` (e.g., "as decided in ADR-2")

**Sections** (Nygard template):
1. **Date** — when the decision was made (YYYY-MM-DD)
2. **Status** — Proposed, Accepted, Deprecated, or Superseded by ADR-N
3. **Context** — forces at play, including technical, political, and project-specific
4. **Decision** — what we decided and why
5. **Consequences** — resulting effects, subdivided into Positive, Negative, and optionally Neutral or Risks

**What warrants an ADR:**
- Technology or framework choices
- Data format or protocol decisions
- Structural choices (module boundaries, pipeline design)
- Decisions that constrain future options
- Trade-offs where the rejected alternative was reasonable

**What does not warrant an ADR:**
- Implementation details that are obvious from the code
- Decisions imposed by external constraints with no real alternative
- Trivial choices (naming conventions, formatting)

## Consequences

### Positive

- Decisions are documented and discoverable in version control
- New contributors can understand the reasoning behind architectural choices
- AI assistants resuming work in new sessions have full context
- Structurizr `!adrs` integration works with the adr-tools title format

### Negative

- Small overhead per decision (mitigated by keeping ADRs concise)
