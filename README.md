# loup-cmd-sort

GNU `sort` recreated in [Loup](https://code-craft.ai/references/loup): sort
lines by bytes, numbers or keys (`-k POS1[,POS2]` with per-key `b f n r`),
with `-t`, `-u`, `-s`, `-o FILE` and the `-c`/`-C` order check, using a stable
merge sort and GNU's last-resort comparison.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                     # native binary: build/sort
make ci                                        # check, unit tests, build, end-to-end tests
make run ARGS="-t: -k3,3n /etc/passwd"         # run from source with loup run
```

```text
$ cat tests/fixtures/scores.txt
carol:72:London
alice:95:Paris
bob:72:Berlin
dave:8:Oslo
erin:100:Rome
$ build/sort tests/fixtures/scores.txt
alice:95:Paris
bob:72:Berlin
carol:72:London
dave:8:Oslo
erin:100:Rome
$ build/sort -t: -k2,2n tests/fixtures/scores.txt
dave:8:Oslo
bob:72:Berlin
carol:72:London
alice:95:Paris
erin:100:Rome
$ build/sort -t: -k2,2nr -k1,1 tests/fixtures/scores.txt
erin:100:Rome
alice:95:Paris
bob:72:Berlin
carol:72:London
dave:8:Oslo
$ printf '10\n9\n-1.5\nx\n2\n' | build/sort -n
-1.5
x
2
9
10
$ printf 'b\nA\na\nB\n' | build/sort -f
A
a
B
b
$ printf 'b\nA\na\nB\n' | build/sort -fu
A
b
$ printf 'x 2\ny 1\nx 1\n' | build/sort -k1,1
x 1
x 2
y 1
$ printf 'x 2\ny 1\nx 1\n' | build/sort -k1,1 -s
x 2
x 1
y 1
$ build/sort -c tests/fixtures/scores.txt; echo "exit $?"
sort: tests/fixtures/scores.txt:2: disorder: alice:95:Paris
exit 1
$ build/sort -k 2.0 tests/fixtures/scores.txt; echo "exit $?"
sort: character offset is zero: invalid field specification '2.0'
exit 2
```

Without `-s`, lines whose keys are equal are ordered by their whole bytes
(`x 1` before `x 2` above); `-s` keeps them in input order, and `-u` keeps
only the first of them.

Options:

| Option | Meaning |
|---|---|
| `-b`, `--ignore-leading-blanks` | ignore leading blanks (spaces and tabs) in keys |
| `-f`, `--ignore-case` | compare `a`-`z` as `A`-`Z` |
| `-n`, `--numeric-sort` | compare leading numbers: blanks, optional `-`, digits, optional `.` fraction; anything else is 0 |
| `-r`, `--reverse` | reverse the result of comparisons |
| `-k`, `--key=POS1[,POS2]` | sort on the part of the line from POS1 to POS2 (default: the line's end); a position is `F[.C]` followed by any of the letters `b f n r`, which then replace the global options for that key; repeat for secondary keys |
| `-t`, `--field-separator=SEP` | fields are separated by the byte SEP (`'\0'` for NUL) instead of starting at each run of blanks |
| `-u`, `--unique` | output only the first of each run of equal lines; with `-c`, equal lines are disorder |
| `-s`, `--stable` | no last-resort comparison: equal lines keep their input order |
| `-o`, `--output=FILE` | write to FILE instead of standard output (FILE may be one of the inputs) |
| `-c`, `--check[=diagnose-first]` | check that the input is sorted; report the first line out of order |
| `-C`, `--check=quiet`, `--check=silent` | check without a message |
| `--help`, `--version` | print help or the version and exit |

With no FILE, or when FILE is `-`, sort reads standard input. Options may
appear anywhere, combine (`-nru`, `-t:`, `-k2,2n`), and long options may be
abbreviated (`--rev`). `--` ends the options.

Exit status: `0` if OK (and sorted, with `-c`/`-C`), `1` if `-c`/`-C` found a
line out of order (and for an invalid `--check=` word, as GNU), `2` for
trouble: a usage error, an input that cannot be read, an output that cannot
be opened.

## Differences from the original

- Only the C locale: bytes compare as unsigned values and `-f` folds ASCII
  letters, whatever `LC_ALL` or `LANG` say. GNU sort uses the locale's
  collation unless `LC_ALL=C`; the output matches `LC_ALL=C sort`.
- Not implemented: `-d`, `-g`, `-h`, `-i`, `-M`, `-R`, `-V` (and the same
  letters in `-k`), `-m`, `-z`, `-S`, `-T`, `--parallel`, `--batch-size`,
  `--compress-program`, `--debug`, `--files0-from`, `--random-source`,
  `--sort=WORD` and the obsolete `+POS1 -POS2` key syntax. They are reported
  as unknown options, or as `stray character in field spec` inside `-k`.
- Long options can be abbreviated among the supported ones only: `--vers`
  means `--version` here, while GNU finds it ambiguous with `--version-sort`;
  `--ignore` lists two possibilities, not three.
- All input is held in memory (eight bytes per input byte); there are no
  temporary files, so very large inputs need a lot of memory.
- A file that exists but cannot be read (permission denied) stops the native
  program with Loup's own `IoError` message and status 1: the Loup 1.26.0
  native runtime does not let the program catch that error. Missing files and
  directories get GNU's messages and status 2. A `-o` file in a directory
  that exists but is not writable is not reported.
- The line printed after `disorder:` by `-c` has bytes that are not valid
  UTF-8 replaced by U+FFFD. Sorted output keeps every byte.
- `--version` prints one line; `--help` lists the supported options only.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, exit statuses
source/cli/args.loup             # getopt_long-style options, checks, key inheritance
source/cli/usage.loup            # --help and --version text
source/cli/app.loup              # run(): parse, dispatch, exit status
source/commands/sort.loup        # reading, sorting, -u, -c, output
source/commands/keys.loup        # KEYDEF parsing, key start and end in a line
source/commands/numeric.loup     # -n: GNU's strnumcmp
source/commands/compare.loup     # the line comparator: keys, then last resort
source/commands/mergesort.loup   # stable merge sort with a comparator function
source/commands/table.loup       # all input as bytes, with line offsets
source/commands/output.loup      # byte-exact output to stdout or a file
tests/*_test.loup                # unit tests (make test)
tests/fixtures/                  # small inputs for the tests
tests/e2e.sh                     # end-to-end tests of build/sort (make e2e)
specs/sort/                      # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
