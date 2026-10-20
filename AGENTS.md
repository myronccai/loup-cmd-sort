# AGENTS.md

This repository recreates GNU `sort` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses (0, 1 disorder, 2 trouble)
│   ├── cli/
│   │   ├── args.loup            # class Options, class ArgError, parse_args(): getopt_long rules, key inheritance
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_sort, exit status
│   └── commands/
│       ├── sort.loup            # run_sort(), sort_table(), unique_lines(), first_disorder(), sort_text()
│       ├── keys.loup            # class Key, parse_key(), inherit(), key_start()/key_limit()
│       ├── numeric.loup         # numeric_compare(): GNU's strnumcmp for -n
│       ├── compare.loup         # class Comparer, compare_lines(): keys, then the last resort
│       ├── mergesort.loup       # merge_sort(n, cmp): stable, bottom-up
│       ├── table.loup           # class Table: all input bytes and line offsets
│       └── output.loup          # is_utf8(), write_stdout(), write_file()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── fixtures/                # small inputs used by the unit and e2e tests
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/sort/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-t: -k3,3n /etc/passwd"` | `loup run source/main.loup -- ARGS`; output that is not valid UTF-8 needs the native build |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter numeric"` | tests whose name contains `numeric` |
| Run one test file | `make test TEST_ARGS="--file tests/keys_test.loup"` | |
| Build | `make build` | native binary at `build/sort` |
| Run the binary | `build/sort --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/sort`: output and messages compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/sort --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

The e2e expectations are GNU sort's output with `LC_ALL=C`. Where GNU
coreutils is installed (on some machines as `gnusort`), compare new cases
with `LC_ALL=C sort ...` before adding them.

## Making a change

1. Update the spec in `specs/sort/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/sort/tasks.md`.

Keep behaviour in functions that return values (`sort_table` returns the
output bytes, `first_disorder` a line number) so unit tests can check it;
only `run_sort` prints.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Lines are bytes: `Table` holds every input byte in a `list[int]` and each
  line as offsets. Do not switch to Loup strings for comparing: natively
  string `len`/`slice` count characters (from the start, on every call) and
  per-character strings are never freed, while byte offsets give GNU's C
  locale behaviour and a comparator that does not allocate.
- Records that cross modules (`Options`, `ArgError`, `Key`, `Table`,
  `Comparer`) are classes, not structs: native builds corrupt struct values
  that cross module boundaries when another type shares field names. Build
  each with a factory or constructor in its own module.
- Sorting goes through `merge_sort(n, cmp)` on line indexes, not
  `list.sort`: it is stable (needed for `-s` and `-u`), and natively a
  `list.sort` comparator that reads a captured list of structs crashes.
- Reserved words cannot be names: `unique`, `global`, `from`, `takes`,
  `type`, ... (`Options.distinct` holds `-u`).
- Check `exists` and `isDir` before `readBytes`: the native runtime cannot
  catch the `IoError` that a missing file raises, while Stage0 (`make test`)
  throws it.
- `system.text` functions (`parseInt`, ...) and `system.env.get` do not link
  natively: parse digits by hand.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
