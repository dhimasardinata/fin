# Release and Provenance

Each release must publish:

- Source archive.
- Seed hash and attestations.
- Reproducibility statement.
- Compatibility notes derived from `COMPATIBILITY.md`.

Release workflow is tracked by FIP-0020 and enforced through CI gates.
Compatibility notes must identify any breaking syntax, semantic, ABI, or package
contract change and link the governing FIP.
