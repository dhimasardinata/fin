Stage0 conformance checks:

- `verify_stage0_grammar.ps1`: validates minimal grammar subset parsing.
- `fixtures/main_exit0.fn`: valid source, expects exit code 0.
- `fixtures/main_exit7.fn`: valid source, expects exit code 7.
- `fixtures/invalid_missing_main.fn`: invalid source, parser must reject.
