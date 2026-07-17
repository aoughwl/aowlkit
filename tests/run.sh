#!/usr/bin/env bash
# run.sh — build and run the aowlkit test driver with the Nimony compiler.
#
# aowlkit is a library, so the driver imports its modules via -p:src. The nimony
# toolchain serializes native codegen through one shared build lock; we take an
# flock before invoking the compiler (parallel sessions contend on it). nimony
# `c` can exit 0 even on failure, so we treat any `Error:` line as a build fail.
#
# Override the compiler with NIMONY=/path/to/nimony.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIMONY="${NIMONY:-$HOME/nimony/bin/nimony}"
LOCK="${NIMONY_BUILD_LOCK:-$HOME/.nimony-build.lock}"
cd "$ROOT"

SRC="tests/t_aowlkit.nim"

build() {
  "$NIMONY" c --base:src -p:src -d:nimony "$SRC" 2>&1
}

run_locked() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK"
    flock 9
  fi
  build
}

log="$(run_locked)"; rc=$?
if [ $rc -ne 0 ] || grep -qE '(^|[^a-zA-Z])Error:' <<<"$log"; then
  echo "$log" | grep -E 'Error:' | head -20
  echo "BUILD-FAIL"
  exit 1
fi

exe="$(find nimcache -type f -name t_aowlkit -executable -printf '%T@ %p\n' 2>/dev/null \
       | sort -rn | head -1 | cut -d' ' -f2-)"
if [ -z "${exe:-}" ]; then
  echo "run.sh: could not locate built t_aowlkit in nimcache/" >&2
  echo "BUILD-FAIL"
  exit 1
fi

"$exe"
