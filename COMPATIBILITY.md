# Compatibility Policy

## Versioning

Fin uses semantic versioning for toolchain releases and language editions when introduced.

## Stability Buckets

- Stable: behavior guaranteed across patch/minor updates.
- Experimental: gated behind explicit feature switches.
- Internal: not a public contract.

## Breaking Change Rules

- Breaking syntax/semantic/ABI changes require an accepted FIP and migration notes.
- Breaking changes must include compatibility tests and explicit release notes.

## Edition Policy

- Editions are optional migration boundaries.
- Default behavior is backward compatibility within the same major release.

## Reproducibility Requirement

Published releases must include deterministic build evidence and seed/provenance metadata.
