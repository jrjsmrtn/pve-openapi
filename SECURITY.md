# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | Yes       |
| < 0.2   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in pve-openapi, please report it
responsibly.

**Do not open a public issue.**

### Preferred: GitHub Security Advisories

Report via [GitHub Security Advisories](https://github.com/jrjsmrtn/pve-openapi/security/advisories/new).
This is private, requires no email, and streamlines the fix-and-disclose workflow.

### Alternative: Email

Send details to <jrjsmrtn@gmail.com> with:

- A description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Any suggested fix (optional)

## Response Timeline

This project is maintained by a single person. Please allow reasonable time
for a response:

| Action | Target |
|--------|--------|
| Acknowledgment | 7 days |
| Initial assessment | 14 days |
| Fix (confirmed vulnerability) | Best effort, typically within 30 days |

If you have not received a response within 14 days, feel free to follow up.

## Scope

pve-openapi distributes OpenAPI specifications extracted from official Proxmox
VE documentation packages. Vulnerabilities in the extraction tooling,
dependency supply chain, or spec accuracy that could lead to security
misconfigurations are taken seriously.

## Safe Harbor

We consider security research conducted in good faith to be authorized.
We will not pursue legal action against researchers who follow this policy
and report vulnerabilities responsibly.

## Disclosure

Once a fix is released, the vulnerability will be documented in CHANGELOG.md
and, where appropriate, a GitHub Security Advisory will be created.
