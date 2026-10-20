#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones, and for errors
# its standard error. The expected output is GNU sort's with LC_ALL=C.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
FIX=tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... as check_file does, and compares standard error;
# standard output must be empty.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want_err" "$TMP/err" && [ ! -s "$TMP/out" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
        sed 's/^/    stdout: /' "$TMP/out" | head -5
    fi
}

TRY=$'\nTry \'sort --help\' for more information.\n'
SCORES=$FIX/scores.txt

# Whole lines.
IN=<(printf 'b\nA\na\nB\n_\n') check "byte order"    0 $'A\nB\n_\na\nb\n'
IN=<(printf 'b\nA\na\nB\n_\n') check "-r"            0 $'b\na\n_\nB\nA\n'    -r
IN=<(printf 'b\nA\na\nB\n_\n') check "-f"            0 $'A\na\nB\nb\n_\n'    -f
IN=<(printf 'b\nA\na\nB\n')    check "-fu first of run" 0 $'A\nb\n'         -f -u
IN=<(printf 'b\na\nb\na\n')    check "-u"            0 $'a\nb\n'            -u
IN=<(printf 'ab\na\n\nb\n')    check "prefix first"  0 $'\na\nab\nb\n'
IN=<(printf '  b\n a\nc\n')    check "blanks count"  0 $'  b\n a\nc\n'
IN=<(printf '  b\n a\nc\n')    check "-b"            0 $' a\n  b\nc\n'      -b
IN=<(printf 'b\na')            check "no final newline" 0 $'a\nb\n'
IN=<(printf '')                check "empty input"   0 ''
IN=<(printf '\n\n')            check "empty lines"   0 $'\n\n'
IN=<(printf 'é\nz\ne\n')       check "UTF-8 by bytes" 0 $'e\nz\né\n'

# Numbers.
IN=<(printf '10\n9\n-1\nx\n2.5\n-0\n') check "-n"        0 $'-1\n-0\nx\n2.5\n9\n10\n' -n
IN=<(printf '1\n3\n2\n')         check "-nr"                 0 $'3\n2\n1\n'           -nr
IN=<(printf '.5\n0.50\n-.5\n.05\n') check "-n fractions"     0 $'-.5\n.05\n.5\n0.50\n' -n
IN=<(printf '1e3\n1,000\n7\n')   check "-n no exponent or comma" 0 $'1,000\n1e3\n7\n' -n
IN=<(printf '123456789012345678901234567891\n123456789012345678901234567890\n') \
    check "-n long numbers" 0 $'123456789012345678901234567890\n123456789012345678901234567891\n' -n
IN=<(printf '1\n01\n1.0\n')      check "-n last resort"      0 $'01\n1\n1.0\n'        -n
IN=<(printf '1\n01\n1.0\n')      check "-n -s"               0 $'1\n01\n1.0\n'        -n -s
IN=<(printf '1\n01\n2\n1.0\n')   check "-n -u"               0 $'1\n2\n'              -nu

# Keys.
check "-t: -k2,2n"           0 $'dave:8:Oslo\nbob:72:Berlin\ncarol:72:London\nalice:95:Paris\nerin:100:Rome\n' -t: -k2,2n "$SCORES"
check "-k2,2n -k1,1r"        0 $'dave:8:Oslo\ncarol:72:London\nbob:72:Berlin\nalice:95:Paris\nerin:100:Rome\n' -t : -k2,2n -k1,1r "$SCORES"
check "-k2nr -s"             0 $'erin:100:Rome\nalice:95:Paris\ncarol:72:London\nbob:72:Berlin\ndave:8:Oslo\n' --field-separator=: --key=2nr -s "$SCORES"
check "-k3 to end of line"   0 $'bob:72:Berlin\ncarol:72:London\ndave:8:Oslo\nalice:95:Paris\nerin:100:Rome\n' -t: -k3 "$SCORES"
check "-k1.2,1.2"            0 $'carol:72:London\ndave:8:Oslo\nalice:95:Paris\nbob:72:Berlin\nerin:100:Rome\n' -t: -k1.2,1.2 "$SCORES"
IN=<(printf 'b 2\na 10\nc 1\na 2\n') check "blank fields -k2n" 0 $'c 1\na 2\nb 2\na 10\n' -k2n
IN=<(printf 'b 2\na 10\nc 1\na 2\n') check "text key keeps blanks" 0 $'c 1\na 10\na 2\nb 2\n' -k2
IN=<(printf 'x  b\nx a\n')      check "leading blanks in field" 0 $'x  b\nx a\n'    -k2
IN=<(printf 'x  b\nx a\n')      check "per-key b"              0 $'x a\nx  b\n'    -k2b
IN=<(printf 'x  b\nx a\n')      check "global -b reaches keys" 0 $'x a\nx  b\n'    -b -k2
IN=<(printf 'b 1\na 1\nc 0\n')  check "-r inherited by key"    0 $'b 1\na 1\nc 0\n' -r -k2
IN=<(printf 'b 1\na 1\nc 0\n')  check "-r with key n"          0 $'c 0\nb 1\na 1\n' -k2n -r
IN=<(printf 'a b c\nb a c\n')   check "end before start"       0 $'a b c\nb a c\n' -k3,1
IN=<(printf 'aB:1\nAb:2\n')     check "-f key, last resort"    0 $'Ab:2\naB:1\n'   -t: -k1,1f
IN=<(printf 'Ab:2\naB:1\n')     check "-u on a -f key"         0 $'Ab:2\n'         -t: -k1,1f -u

# Bytes: NUL as separator and in lines, invalid UTF-8 kept.
printf 'a\0b\nc\0a\n' > "$TMP/nul_in"
printf 'c\0a\na\0b\n' > "$TMP/nul_want"
check_file "-t '\\0'"        0 "$TMP/nul_want" -t '\0' -k2 "$TMP/nul_in"
printf 'b\0x\n\xff\xfe\na\0y\nz\n\xc3\xa9\n' > "$TMP/bin_in"
printf 'a\0y\nb\0x\nz\n\xc3\xa9\n\xff\xfe\n' > "$TMP/bin_want"
check_file "binary lines"    0 "$TMP/bin_want" "$TMP/bin_in"

# Files, standard input and -o.
printf 'x\ny' > "$TMP/f1"
printf 'b\na' > "$TMP/f2"
check "several files"        0 $'a\nb\nx\ny\n'          "$TMP/f1" "$TMP/f2"
IN=<(printf 'm\n') check "dash is stdin" 0 $'a\nb\nm\nx\ny\n' "$TMP/f2" - "$TMP/f1"
check "-o writes the file"   0 ''                       -o "$TMP/out1" "$TMP/f1" "$TMP/f2"
check "-o content"           0 $'a\nb\nx\ny\n'          "$TMP/out1"
cp "$TMP/f2" "$TMP/same"
check "-o onto an input"     0 ''                       --output="$TMP/same" "$TMP/same" "$TMP/f1"
check "-o onto an input content" 0 $'a\nb\nx\ny\n'      "$TMP/same"

# Checking order.
check "-c sorted"            0 ''                       -c "$FIX/sorted.txt"
check_err "-c disorder"      1 "sort: $SCORES:2: disorder: alice:95:Paris"$'\n' -c "$SCORES"
check_err "-C quiet"         1 ''                       -C "$SCORES"
check_err "--check=silent"   1 ''                       --check=silent "$SCORES"
check_err "-c -u equal lines" 1 "sort: $FIX/sorted.txt:3: disorder: banana"$'\n' -cu "$FIX/sorted.txt"
check "-c with keys"         0 ''                       -c -t: -k2,2nr -k1,1 <(printf 'erin:100\nbob:72\ncarol:72\n')
IN=<(printf 'a\nc\nb\n') check_err "-c stdin" 1 $'sort: -:3: disorder: b\n' -c

# Errors.
check_err "missing file"     2 $'sort: cannot read: nope: No such file or directory\n' "$TMP/f1" nope
check_err "directory"        2 $'sort: read failed: tests: Is a directory\n'          tests
check_err "-c missing file"  2 $'sort: open failed: nope: No such file or directory\n' -c nope
check_err "-o directory"     2 $'sort: open failed: tests: Is a directory\n'          -o tests "$TMP/f1"
check_err "-o no such dir"   2 $'sort: open failed: nodir/x: No such file or directory\n' -o nodir/x "$TMP/f1"
check_err "field zero"       2 $'sort: field number is zero: invalid field specification \'0\'\n' -k0
check_err "offset zero"      2 $'sort: character offset is zero: invalid field specification \'1.0\'\n' -k1.0
check_err "bad field start"  2 $'sort: invalid number at field start: invalid count at start of \'x\'\n' -k x
check_err "bad end field"    2 $'sort: invalid number after \',\': invalid count at start of \'y\'\n' -k 1,y
check_err "unsupported letter" 2 $'sort: stray character in field spec: invalid field specification \'1M\'\n' -k1M
check_err "multi-character tab" 2 $'sort: multi-character tab \'ab\'\n'               -t ab
check_err "empty tab"        2 $'sort: empty tab\n'                                  -t ''
check_err "incompatible tabs" 2 $'sort: incompatible tabs\n'                         -t: -t,
check_err "two outputs"      2 $'sort: multiple output files specified\n'            -o a -o b
check_err "-c two files"     2 $'sort: extra operand \'b\' not allowed with -c\n'     -c a b
check_err "-c with -o"       2 $'sort: options \'-co\' are incompatible\n'            -c -o x
check_err "-c with -C"       2 $'sort: options \'-cC\' are incompatible\n'            -c -C
check_err "invalid option"   2 "sort: invalid option -- 'd'$TRY"                     -d
check_err "unknown long"     2 "sort: unrecognized option '--merge'$TRY"             --merge
check_err "missing value"    2 "sort: option requires an argument -- 'k'$TRY"        -k
check_err "long missing value" 2 "sort: option '--key' requires an argument$TRY"     --key
check_err "no argument allowed" 2 "sort: option '--stable' doesn't allow an argument$TRY" --stable=1
check_err "ambiguous"        2 "sort: option '--ignore' is ambiguous; possibilities: '--ignore-leading-blanks' '--ignore-case'$TRY" --ignore
check_err "bad --check word" 1 "sort: invalid argument 'loud' for '--check'"$'\nValid arguments are:\n  - \'quiet\', \'silent\'\n  - \'diagnose-first\''"$TRY" --check=loud

# Help and version.
check "version"              0 $'sort (loup-cmd-sort) 0.1.0\n' --version
IN=<(printf 'a\nb\n') check "abbreviated --reverse" 0 $'b\na\n' --rev
"$BIN" --help > "$TMP/help" 2>&1
if [ $? -eq 0 ] && head -1 "$TMP/help" | grep -q '^Usage: sort \[OPTION\]\.\.\. \[FILE\]\.\.\.$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
