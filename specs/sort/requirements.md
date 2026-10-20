# Requirements: sort

## Introduction

`sort` writes the lines of its input files in sorted order. This repository
recreates the core of GNU coreutils `sort` in Loup, in the C locale (bytes
compare as unsigned values): whole-line and keyed sorting with `-k`, field
separators, the ordering options `-b`, `-f`, `-n`, `-r` globally and per key,
`-u`, `-s`, `-o FILE` and the `-c`/`-C` order check, with GNU's
last-resort comparison, messages and exit statuses. Shell users and scripts
use it to order and de-duplicate text.

## Requirements

### Requirement 1: Input and output

**User Story:** As a shell user, I want sort to read files and standard
input like other filters so that it fits in pipelines.

#### Acceptance Criteria

1. WHEN no FILE is given, or a FILE is `-`, THE program SHALL read standard
   input.
2. WHEN several FILEs are given, THE program SHALL sort the lines of all of
   them together.
3. THE program SHALL treat a last line without a newline as a whole line and
   end every output line with a newline.
4. THE program SHALL keep every byte of a line, including NUL bytes and
   bytes that are not valid UTF-8.
5. WHEN `-o FILE` is given, THE program SHALL write the result to FILE
   instead of standard output, after reading all input, so FILE may also be
   an input.
6. WHEN an input cannot be found, THE program SHALL print
   `sort: cannot read: FILE: No such file or directory` before sorting
   anything and exit with status 2; for a directory it SHALL print
   `sort: read failed: FILE: Is a directory` and exit with status 2.
7. WHEN the directory of the `-o` FILE does not exist, or FILE is a
   directory, THE program SHALL print `sort: open failed: FILE: ...` and exit
   with status 2.

### Requirement 2: Default ordering

**User Story:** As a shell user, I want lines in byte order so that the
output is the same on every machine.

#### Acceptance Criteria

1. WHEN no ordering option is given, THE program SHALL order lines by
   comparing their bytes as unsigned values, a line that is a prefix of
   another coming first (GNU sort with `LC_ALL=C`).
2. WHEN `-r` is given, THE program SHALL reverse the result of every
   comparison that has no ordering options of its own.
3. WHEN `-f` is given, THE program SHALL compare as if `a` to `z` were `A`
   to `Z`.
4. WHEN `-b` is given, THE program SHALL ignore leading blanks (spaces and
   tabs) in each key.
5. WHEN `-n` is given, THE program SHALL compare the leading numbers of the
   keys as GNU does: optional blanks, an optional `-`, digits and an
   optional `.` fraction, of any length; a key with no number counts as 0.
6. WHEN lines compare equal on all keys, THE program SHALL compare the whole
   lines by bytes as a last resort, reversed by a global `-r`, unless `-s` or
   `-u` is given.

### Requirement 3: Keys

**User Story:** As a shell user, I want to sort tables on chosen columns,
each with its own ordering, so that I can sort by name and then by number.

#### Acceptance Criteria

1. WHEN `-k POS1[,POS2]` is given, THE program SHALL compare the part of
   each line from POS1 to POS2 (to the end of the line when POS2 is
   omitted), where a position is `F[.C]`, field F and character C counted
   from 1; C defaults to the start of the field in POS1 and to the end of
   the field (also `.0`) in POS2.
2. WHEN `-t SEP` is not given, THE program SHALL split fields at the
   transition from a non-blank to a blank, with the blanks belonging to the
   field that follows them.
3. WHEN `-t SEP` is given, THE program SHALL split fields at each SEP byte;
   `-t '\0'` SHALL mean the NUL byte.
4. WHEN several `-k` options are given, THE program SHALL compare by each
   key in turn, moving to the next only when the previous ones are equal.
5. WHEN a key has ordering letters (`b`, `f`, `n`, `r`), THE program SHALL
   use only those for it; `b` after POS1 skips blanks at the start and after
   POS2 at the end. WHEN a key has none, it SHALL inherit the global `-b`,
   `-f`, `-n` and `-r`.
6. WHEN a key specification is malformed, THE program SHALL print GNU sort's
   message for it (`field number is zero`, `character offset is zero`,
   `invalid number at field start`, `invalid number after '.'`,
   `invalid number after ','`, `stray character in field spec`) and exit with
   status 2.

### Requirement 4: Unique and stable

**User Story:** As a shell user, I want to drop duplicates or keep the
input order of equal lines so that I can build sets and multi-pass sorts.

#### Acceptance Criteria

1. WHEN `-u` is given, THE program SHALL output only the first line of each
   run of lines that compare equal on the keys (on the whole line when there
   are no keys).
2. WHEN `-s` is given, THE program SHALL keep lines that compare equal on
   the keys in their input order.
3. THE sort SHALL be stable, so that 4.1 and 4.2 pick lines by input order.

### Requirement 5: Checking order

**User Story:** As a script author, I want to test whether a file is
already sorted without rewriting it.

#### Acceptance Criteria

1. WHEN `-c` (or `--check`, `--check=diagnose-first`) is given, THE program
   SHALL print nothing to standard output, and exit with status 0 if the
   input is sorted under the given options, or print
   `sort: FILE:N: disorder: LINE` for the first line out of order and exit
   with status 1.
2. WHEN `-C` (or `--check=quiet`, `--check=silent`) is given, THE program
   SHALL behave as with `-c` but print no message.
3. WHEN `-u` is given with a check, THE program SHALL also report two equal
   adjacent lines as disorder.
4. WHEN a check is given with more than one FILE, or with `-o`, or `-c` with
   `-C`, THE program SHALL print GNU's message and exit with status 2.

### Requirement 6: Command line

**User Story:** As a shell user, I want sort's usual option syntax and
messages so that existing commands and scripts work.

#### Acceptance Criteria

1. THE program SHALL accept options and operands in any order, clustered
   short options (`-nr`, `-t:`, `-k2,2n`), values in the same or the next
   argument, long options (`--key=2`, `--key 2`) abbreviated to any
   unambiguous prefix, and `--` to end the options.
2. WHEN an option is unknown, ambiguous or missing its value, THE program
   SHALL print getopt's message and `Try 'sort --help' for more
   information.` and exit with status 2.
3. WHEN `-t` is given an empty or multi-byte value, two different `-t`
   values, or two different `-o` files, THE program SHALL print GNU's message
   and exit with status 2.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or `sort (loup-cmd-sort) 0.1.0` and exit with status 0.
