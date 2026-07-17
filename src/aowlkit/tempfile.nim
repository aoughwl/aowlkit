## aowlkit/tempfile — per-process-unique temp path helper.

import std/[appdirs, paths, strutils, monotimes]

var gTmpCounter = 0

proc tempPath*(tag, ext: string): string =
  ## A temp path combining the temp dir, a monotonic tick, and an incrementing
  ## counter — repeated calls within one run never collide.
  inc gTmpCounter
  var ticks = 0'i64
  try:
    ticks = getMonoTime().ticks
  except:
    ticks = 0
  var td = "/tmp"
  try:
    td = $getTempDir()
  except:
    td = "/tmp"
  if td.len > 0 and td[td.len - 1] == '/':
    td = substr(td, 0, td.len - 2)
  result = td & "/aowlkit_" & tag & "_" & $ticks & "_" & $gTmpCounter & ext
