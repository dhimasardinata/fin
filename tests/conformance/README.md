Stage0 conformance checks:

- `verify_stage0_grammar.ps1`: validates minimal grammar subset parsing.
- `verify_finobj_roundtrip.ps1`: validates stage0 finobj deterministic writer/reader roundtrip and malformed-object rejection cases; uses PID-scoped temp workspace hygiene under `artifacts/tmp`.
- `fixtures/main_exit0.fn`: valid source, expects exit code 0.
- `fixtures/main_exit7.fn`: valid source, expects exit code 7.
- `fixtures/main_exit_let7.fn`: valid source with `let` binding and identifier exit.
- `fixtures/main_exit_var_assign.fn`: valid source with `var` mutation before exit.
- `fixtures/main_exit_comments.fn`: valid source with `#` and `//` comments.
- `fixtures/main_exit_typed_u8.fn`: valid source with explicit `: u8` binding annotations.
- `fixtures/invalid_missing_main.fn`: invalid source, parser must reject.
- `fixtures/invalid_undefined_identifier.fn`: invalid source, parser must reject undefined identifier use.
- `fixtures/invalid_assign_immutable.fn`: invalid source, parser must reject assignment to `let`.
- `fixtures/invalid_unsupported_type_annotation.fn`: invalid source, parser must reject unsupported type annotations.
