# Design: sort

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `run` parses the
arguments into `Options` (key specifications are parsed and the global
ordering options already folded into the keys), handles `--help` and
`--version`, and calls `commands.sort.run_sort`. `run_sort` reads every
input into one byte table, sorts line numbers with a stable merge sort
driven by a comparator function, and writes the result (or, with `-c`/`-C`,
checks the order). Everything except `run_sort` returns values, so unit tests
need no captured output.

Lines are handled as **bytes**, not Loup strings: every input is read with
`readBytes` into a `list[int]`, and a line is a `(start, end)` pair of
offsets. This gives GNU's C-locale behaviour exactly (byte order, `-k 2.3`
counting bytes, invalid UTF-8 and NUL bytes kept), and the comparator works
on integers without allocating, which matters natively (see AGENTS.md).

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 ok, 1 disorder, 2 trouble) |
| `source/cli/args.loup` | `Options`, `ArgError`, `parse_args`: a getopt_long work-alike for sort's options, their cross-checks, and key inheritance |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, map exceptions to status 2 |
| `source/commands/keys.loup` | `Key`, `whole_line_key`, `parse_key`, `set_ordering` (KEYDEF grammar and messages), `inherit`, `key_start`/`key_limit` (GNU's `begfield`/`limfield`) |
| `source/commands/numeric.loup` | `numeric_compare`: GNU's `strnumcmp` for `-n`, on byte ranges |
| `source/commands/table.loup` | `Table` (bytes, line starts and ends), `append_bytes`, `append_text`, `push_line` |
| `source/commands/compare.loup` | `Comparer` (keys, separator, flags and each line's precomputed key ranges), `compare_lines` |
| `source/commands/mergesort.loup` | `merge_sort(n, cmp)`: bottom-up, stable, with a comparator function |
| `source/commands/output.loup` | `is_utf8`, `write_stdout` (`print`, or C `putchar` for invalid UTF-8), `write_file` |
| `source/commands/sort.loup` | `sorted_lines`, `unique_lines`, `render`, `sort_table`, `first_disorder`, `sort_text`, `run_sort` |

### Comparison

`compare_lines(table, comparer, i, j)` mirrors GNU's `compare`/`keycompare`:

1. For each key in turn, take the key ranges of both lines (computed once
   per line when the `Comparer` is built; an end before the start is an
   empty key). A numeric key compares with `numeric_compare`; any other
   compares bytes, through the `-f` upper-case fold if set, a shorter key
   that is a prefix of the other coming first. A non-zero result is
   returned, negated if the key has `r`.
2. If every key is equal and `-u` or `-s` is set, the lines are equal.
3. Otherwise (and when there are no keys) the whole lines are compared by
   bytes, negated by the global `-r`.

Global options apply as GNU applies them: a key with none of `b`, `f`, `n`,
`r` inherits all the global ones; with no `-k`, a global `-b`, `-f` or `-n`
creates one whole-line key; the global `-r` also reverses the last-resort
comparison.

`numeric_compare` is a port of gnulib's `strnumcmp` in the C locale
(decimal point `.`, no thousands separator): it skips leading blanks and
zeros, compares signs, then integer lengths, then digits, then fractions,
without converting to a number, so any length works. Reading past a key's
end yields 0, the NUL that GNU writes there.

### Sorting, unique, check

`merge_sort(n, cmp)` sorts the indexes `0..n` bottom-up, taking from the
left run unless the right element is strictly smaller, so it is stable.
`unique_lines` keeps the first line of each run that compares equal to the
last kept line. `first_disorder` returns the 1-based number of the first line
that compares greater than (with `-u`: not less than) the line before.

### Output

The sorted lines are concatenated into one `list[int]`. On standard output
it is printed as one string when it is valid UTF-8 (`print` writes a string's
bytes unchanged); otherwise each byte goes through C's `putchar`, which only
the native build can call. `-o FILE` uses `writeBytes`, which is byte-exact
in every lane.

## Differences from GNU sort

- Only the C locale: bytes compare as unsigned values and `-f` folds ASCII
  letters, whatever `LC_ALL`/`LANG` say (GNU sorts by the locale's collation
  unless `LC_ALL=C`).
- Not implemented: `-d`, `-g`, `-h`, `-i`, `-M`, `-R`, `-V` (also as key
  letters), `-m`, `-z`, `-S`, `-T`, `--parallel`, `--batch-size`,
  `--compress-program`, `--debug`, `--files0-from`, `--random-source`,
  `--sort=WORD` and the obsolete `+POS1 -POS2` key syntax. They are
  reported as unknown options (`-k` letters as `stray character in field
  spec`).
- Long options can be abbreviated among the supported ones only: `--vers`
  means `--version` here, while GNU finds it ambiguous with `--version-sort`.
- All input is held in memory (8 bytes per input byte); there are no
  temporary files.
- A file that exists but cannot be read (permission denied) stops the native
  program with Loup's own `IoError` message and status 1: the Loup 1.26.0
  native runtime does not let the program catch it. Missing files and
  directories get GNU's messages. A `-o` file in a directory that exists but
  is not writable is not reported.
- The line shown by `-c` after `disorder:` has invalid UTF-8 replaced by
  U+FFFD.
- `--version` prints one line; `--help` lists the supported options only.

## Error handling

`parse_args` returns `Err(ArgError)`: a message without the `sort: ` prefix,
whether to add the `Try 'sort --help'` line (getopt errors) and the exit
status (2; 1 for an invalid `--check` argument, as GNU). Before reading,
`run_sort` checks that each input exists (`cannot read`), then that the `-o`
file's directory exists and the file is not a directory (`open failed`), then
reads the inputs, reporting directories (`read failed`). These checks come
first because the native runtime cannot catch `IoError`. Exceptions that do
reach `run` (Stage0) are printed as `sort: message` with status 2.

## Testing

- `tests/args_test.loup`: option syntax, abbreviations, values, cross-checks,
  each message and status, key inheritance.
- `tests/keys_test.loup`: KEYDEF parsing and errors; key ranges with and
  without `-t`, `b`, character offsets, and ends before starts.
- `tests/numeric_test.loup`: signs, zeros, fractions, long numbers,
  non-numbers.
- `tests/mergesort_test.loup`: ordering and stability with a comparator.
- `tests/sort_test.loup`: whole-line, `-r`, `-f`, `-n`, keys, `-u`, `-s`,
  last resort, `first_disorder`, UTF-8 detection.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: runs the native binary on fixtures and standard input and
  compares output (and messages) byte for byte, including NUL bytes, invalid
  UTF-8, `-o` onto an input file and every error status.
