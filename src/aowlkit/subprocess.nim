## aowlkit/subprocess — capture a child process's output SAFELY.
##
## nimony's `osproc.execCmdEx` captures output line-by-line through a fixed buffer
## and mangles any line longer than it (it splices breaks mid-line) — which
## corrupts single-line JSON and long tab-separated records. Every aowl tool that
## shells out to another (aowlsuggest→aowlparser, aowllsp→nimony/aiflens) needs a
## capture that is immune to this. The fix: redirect the child's stdout to a temp
## file and read it whole. This module is that, once.

import std/[osproc, syncio, paths, dirs, strutils]
import ./tempfile

type
  CaptureResult* = object
    output*: string    ## the captured stdout (and stderr if merged)
    exitCode*: int     ## the child's exit code, or -1 if it could not be run
    ok*: bool          ## false only when the process could not run / be read

proc shellQuote*(s: string): string =
  ## Single-quote a string for safe inclusion in a `sh -c` command line.
  result = "'"
  for i in 0 ..< s.len:
    if s[i] == '\'':
      result.add "'\\''"
    else:
      result.add s[i]
  result.add "'"

proc captureShell*(command: string): CaptureResult =
  ## Run `command` through `sh -c` (execCmd already does), sending its stdout to
  ## a temp file we then read whole. `command` should NOT include a redirect —
  ## this adds one. stderr is discarded; use `captureShellMerged` to keep it.
  let outPath = tempPath("out", ".txt")
  let full = command & " > " & shellQuote(outPath) & " 2>/dev/null"
  var code = -1
  try:
    code = execCmd(full)
  except:
    return CaptureResult(output: "", exitCode: -1, ok: false)
  var outp = ""
  try:
    outp = readFile(outPath)
  except:
    return CaptureResult(output: "", exitCode: code, ok: false)
  try: removeFile(path(outPath))
  except: discard
  result = CaptureResult(output: outp, exitCode: code, ok: true)

proc captureShellMerged*(command: string): CaptureResult =
  ## Like `captureShell` but merges stderr into the captured output (`2>&1`).
  let outPath = tempPath("out", ".txt")
  let full = command & " > " & shellQuote(outPath) & " 2>&1"
  var code = -1
  try:
    code = execCmd(full)
  except:
    return CaptureResult(output: "", exitCode: -1, ok: false)
  var outp = ""
  try:
    outp = readFile(outPath)
  except:
    return CaptureResult(output: "", exitCode: code, ok: false)
  try: removeFile(path(outPath))
  except: discard
  result = CaptureResult(output: outp, exitCode: code, ok: true)

proc runCaptured*(exe: string; args: seq[string]; workdir = "";
                  mergeStderr = true): CaptureResult =
  ## Build and run `exe arg1 arg2 …` (each argument shell-quoted) optionally in
  ## `workdir`, capturing output whole. This is the high-level entry the drivers
  ## use instead of osproc directly.
  var cmd = ""
  if workdir.len > 0:
    cmd.add "cd " & shellQuote(workdir) & " && "
  cmd.add shellQuote(exe)
  for i in 0 ..< args.len:
    cmd.add " " & shellQuote(args[i])
  if mergeStderr: captureShellMerged(cmd)
  else: captureShell(cmd)
