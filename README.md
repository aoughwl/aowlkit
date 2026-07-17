# aowlkit

A small **shared utility library for the aoughwl nimony tools** — the generic
pieces every tool otherwise re-implements. Consumed via `-p:$HOME/aowlkit/src`
(the same way `aowlhl` is), so there is one copy, tested once.

| module | what |
|--------|------|
| `aowlkit/json` | JSON string escaping + tiny builders (`jStr`, `jsonEscape`, `jBool`). nimony's `std/json` reads via lazy cursors; this is the WRITE side. |
| `aowlkit/subprocess` | capture a child's output SAFELY via a temp-file redirect — immune to nimony's `execCmdEx` long-line mangling that corrupts JSON / long records. |
| `aowlkit/tempfile` | a per-process-unique temp path (`tempPath(tag, ext)`). |

Used by [aowllsp](https://github.com/aoughwl/aowllsp) and
[aowlsuggest](https://github.com/aoughwl/aowlsuggest).

```nim
import aowlkit/json, aowlkit/subprocess
echo jStr("a\"b")                     # -> "a\"b"
let r = runCaptured("nimony", @["check", "x.nim"], "/proj", true)
echo r.exitCode, r.output
```
