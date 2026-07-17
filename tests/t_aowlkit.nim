## t_aowlkit — test driver for the aowlkit shared library.
##
## Exercises json (escaping + builders), subprocess (capture/stdin/shell/
## missing-exe) and tempfile (uniqueness + tag/ext). Built and run by run.sh.
## Prints "aowlkit tests: PASS" on success; quit(1) on any failure.

import std/[syncio, strutils]
import aowlkit/json
import aowlkit/subprocess
import aowlkit/tempfile

var checks = 0

proc check(cond: bool; msg: string) =
  inc checks
  if not cond:
    echo "FAIL: " & msg
    quit(1)

proc eq(got, want, msg: string) =
  inc checks
  if got != want:
    echo "FAIL: " & msg
    echo "  got:  " & got
    echo "  want: " & want
    quit(1)

# ---------------------------------------------------------------- json --------

# jsonEscape produces contents only (no surrounding quotes). Expected values are
# exactly what std/json emits: short escapes \b \f \n \r \t \\ \" and lowercase
# \u00XX for the remaining control characters.
eq(jsonEscape("plain"), "plain", "jsonEscape plain passthrough")
eq(jsonEscape("a\"b"), "a\\\"b", "jsonEscape double-quote")
eq(jsonEscape("a\\b"), "a\\\\b", "jsonEscape backslash")
eq(jsonEscape("a\nb"), "a\\nb", "jsonEscape newline")
eq(jsonEscape("a\tb"), "a\\tb", "jsonEscape tab")
eq(jsonEscape("a\rb"), "a\\rb", "jsonEscape carriage return")
eq(jsonEscape("a\bb"), "a\\bb", "jsonEscape backspace short escape")
eq(jsonEscape("a\fb"), "a\\fb", "jsonEscape formfeed short escape")

# Control chars without a short escape → lowercase \u00XX.
eq(jsonEscape("\x00"), "\\u0000", "jsonEscape NUL")
eq(jsonEscape("\x01"), "\\u0001", "jsonEscape SOH")
eq(jsonEscape("\x1f"), "\\u001f", "jsonEscape unit-separator (lowercase hex)")
eq(jsonEscape("\x1b"), "\\u001b", "jsonEscape ESC (lowercase hex)")

# Bytes >= 0x20, including UTF-8 multibyte sequences, pass through verbatim
# (std/json does not \u-escape non-ASCII; it emits the raw UTF-8 bytes).
eq(jsonEscape("é"), "é", "jsonEscape utf-8 passthrough (2-byte)")
eq(jsonEscape("→"), "→", "jsonEscape utf-8 passthrough (3-byte)")

# A combined worst-case string.
eq(jsonEscape("tab\tnl\nq\"bs\\end"),
   "tab\\tnl\\nq\\\"bs\\\\end", "jsonEscape combined")

# jStr wraps jsonEscape in quotes.
eq(jStr("hi"), "\"hi\"", "jStr quotes")
eq(jStr("a\"b"), "\"a\\\"b\"", "jStr escapes inside quotes")
eq(jStr(""), "\"\"", "jStr empty")

# jBool
eq(jBool(true), "true", "jBool true")
eq(jBool(false), "false", "jBool false")

# jArr additive helper: joins pre-rendered json fragments into an array.
eq(jArr(@[]), "[]", "jArr empty")
eq(jArr(@[jStr("a")]), "[\"a\"]", "jArr single")
eq(jArr(@[jStr("a"), jBool(true), "42"]),
   "[\"a\",true,42]", "jArr mixed fragments")

# ------------------------------------------------------------ subprocess ------

block:
  let r = runCaptured("/bin/echo", @["hi"])
  check(r.ok, "runCaptured echo ok")
  check(r.exitCode == 0, "runCaptured echo exit 0")
  check(r.output.contains("hi"), "runCaptured echo output contains hi")

block:
  # A long single line must survive intact (the whole reason capture exists).
  var longline = ""
  for i in 0 ..< 5000: longline.add "x"
  let r = runCaptured("/bin/echo", @[longline])
  check(r.ok, "runCaptured long line ok")
  check(r.output.contains(longline), "runCaptured long line intact")

block:
  let r = runWithInput("/bin/cat", @[], "piped-stdin-payload")
  check(r.ok, "runWithInput cat ok")
  check(r.exitCode == 0, "runWithInput cat exit 0")
  check(r.output.contains("piped-stdin-payload"),
        "runWithInput pipes stdin through cat")

block:
  let r = captureShell("printf 'shell-out'")
  check(r.ok, "captureShell ok")
  check(r.exitCode == 0, "captureShell exit 0")
  check(r.output.contains("shell-out"), "captureShell output")

block:
  # stderr merged vs discarded. The command is wrapped in a subshell so its own
  # `1>&2` is resolved against the redirects this module appends (which reassign
  # fd1/fd2 for the outer command) rather than being clobbered by them.
  let m = captureShellMerged("(printf 'to-stderr' 1>&2)")
  check(m.ok, "captureShellMerged ok")
  check(m.output.contains("to-stderr"), "captureShellMerged keeps stderr")
  let d = captureShell("(printf 'to-stderr' 1>&2)")
  check(d.ok, "captureShell (discard) ok")
  check(not d.output.contains("to-stderr"), "captureShell discards stderr")

block:
  # A non-existent exe: the process cannot run, but the whole-file capture path
  # still completes (the empty/error output file reads fine), so `ok` stays true
  # while the non-zero exit code (127) is the failure signal to the caller. With
  # stderr discarded, the captured output is empty.
  let r = runCaptured("/no/such/exe/aowlkit_missing", @["x"], "", false)
  check(r.exitCode != 0, "missing exe non-zero exit")
  check(r.output.len == 0, "missing exe empty output (stderr discarded)")
  # Default merged path: the shell's own error text lands in output.
  let m = runCaptured("/no/such/exe/aowlkit_missing", @["x"])
  check(m.exitCode != 0, "missing exe (merged) non-zero exit")

# shellQuote hardening.
eq(shellQuote("plain"), "'plain'", "shellQuote plain")
eq(shellQuote("a'b"), "'a'\\''b'", "shellQuote embedded single-quote")

# ------------------------------------------------------------ tempfile --------

block:
  let a = tempPath("out", ".txt")
  let b = tempPath("out", ".txt")
  check(a != b, "tempPath distinct across calls")
  check(a.endsWith(".txt"), "tempPath honors ext")
  check(a.contains("_out_"), "tempPath honors tag")
  let c = tempPath("in", ".nif")
  check(c.endsWith(".nif"), "tempPath honors alt ext")
  check(c.contains("_in_"), "tempPath honors alt tag")
  check(a != c, "tempPath distinct across tags")

echo "aowlkit tests: PASS (" & $checks & " checks)"
