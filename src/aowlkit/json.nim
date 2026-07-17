## aowlkit/json — hand-built JSON output for nimony tools.
##
## nimony's std/json reads via lazy cursors (only valid mid-iteration), so this
## covers the WRITE side that every aowl tool otherwise re-implements: correct
## string escaping plus a few tiny builders. Reading stays inline at each call
## site (extract scalars during `pairs`/`items`).

proc jsonEscape*(s: string): string =
  ## Escape a string's contents per the JSON spec (no surrounding quotes).
  result = ""
  for i in 0 ..< s.len:
    let c = s[i]
    case c
    of '"': result.add "\\\""
    of '\\': result.add "\\\\"
    of '\n': result.add "\\n"
    of '\t': result.add "\\t"
    of '\r': result.add "\\r"
    of '\b': result.add "\\b"      # 0x08 — JSON short escape (matches std/json)
    of '\f': result.add "\\f"      # 0x0C
    else:
      if c < ' ':
        const hexd = "0123456789abcdef"   # lowercase, matches std/json
        result.add "\\u00"
        result.add hexd[(ord(c) shr 4) and 0xF]
        result.add hexd[ord(c) and 0xF]
      else:
        result.add c

proc jStr*(s: string): string =
  ## A quoted, escaped JSON string literal.
  "\"" & jsonEscape(s) & "\""

proc jBool*(b: bool): string =
  if b: "true" else: "false"
