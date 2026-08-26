# Publishing `quaynor` on crates.io

The Rust crate is the engine itself — `quaynor/core/` — plus its two grammar
support crates. Three packages go to crates.io:

| Package | Path | Crate name in code |
|---------|------|--------------------|
| `quaynor-gbnf` | `quaynor/grammar/gbnf/` | `gbnf` (via `[lib] name`) |
| `quaynor-gbnf-macro` | `quaynor/grammar/gbnf-macro/` | `gbnf_macro` (via `[lib] name`) |
| `quaynor` | `quaynor/core/` | `quaynor` |

## 0. Run the install test

The "Rust crate install test" workflow (Actions tab → Run workflow) builds the
crate on Ubuntu, macOS, Windows, and Nix the way a consumer would. It is
manual-only because each job compiles llama.cpp from scratch — run it before
publishing and wait for green.

## 1. Log in once

Create an API token at https://crates.io/settings/tokens (scope: `publish-new`
and `publish-update`), then:

```sh
cargo login
```

## 2. Publish in dependency order

Order matters: the macro depends on `quaynor-gbnf`, and `quaynor` depends on
both. From the workspace root (`quaynor/`):

```sh
cargo publish -p quaynor-gbnf
cargo publish -p quaynor-gbnf-macro
cargo publish -p quaynor
```

Notes:

- `quaynor-gbnf`'s dev-dependency on the macro is **path-only on purpose** —
  cargo strips it from the published manifest, which is what breaks the
  circular dependency. Don't add a `version` to it.
- The `quaynor` publish step compiles llama.cpp during verification, so it
  takes several minutes. `--no-verify` skips that if you have just built the
  exact same tree.
- After the first publish of the grammar crates, later `quaynor` releases only
  need `cargo publish -p quaynor` unless the grammar crates changed (bump
  their versions and publish them first in that case).

## 3. Version bumps

Bump `version` in `quaynor/core/Cargo.toml` for the engine; bump the grammar
crates only when their code changes. crates.io versions are immutable — a
mistake needs a new version (or `cargo yank` to hide one).

## Dependency pins worth knowing

- `llama-cpp-2` is pinned exactly (`=0.1.x`) because upstream ships breaking
  changes in patch releases. Bumping it is a deliberate, tested change.
- `monty` requires rustc ≥ 1.95.
- `get-size2` is held at 0.10.1 in `Cargo.lock` (transitive, via monty →
  ruff_python_ast, which needs `compact_str ^0.9`; get-size2 ≥ 0.10.2 moved to
  `^0.10` and breaks the build). If a fresh `cargo update` breaks on
  `GetSize`/`CompactString`, re-pin: `cargo update get-size2 --precise 0.10.1`.
