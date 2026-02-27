# Seed Artifact

`seed/` defines the audited bootstrap trust anchor for Fin.

## Files

- `manifest.toml`: immutable metadata for seed artifact identity.
- `SHA256SUMS`: expected hashes.
- `stage0-closure-baseline.txt`: expected closure proxy witness keys for stage0 deterministic gate.
- `README.md`: policy and verification process.

## Policy

- Seed hash changes require a dedicated FIP update and release notes.
- Seed artifacts must be reproducible or accompanied by provenance attestations.
