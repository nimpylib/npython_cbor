# Package

version       = "0.1.0"
author        = "litlighilit"
description   = "cbor library for npython"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
let srcName = "npython_cbor"
bin           = @[srcName]
binDir        =  "bin"
let srcPath = srcDir & '/' & srcName
# Dependencies

requires "nim > 2.0.8"
requires "npython >= 0.2.0"
requires "cbor_serialization"

import std/os

# copied from nimpylib.nimble
#   at 43378424222610f8ce4a10593bd719691fbb634b
func getArgs(taskName: string): seq[string] =
  ## cmdargs: 1 2 3 4 5 -> 1 4 3 2 5
  var rargs: seq[string]
  let argn = paramCount()
  for i in countdown(argn, 0):
    let arg = paramStr i
    if arg == taskName:
      break
    rargs.add arg
  if rargs.len > 1:
    swap rargs[^1], rargs[0] # the file must be the last, others' order don't matter
  return rargs

template mytask(name: untyped, taskDesc: string, body){.dirty.} =
  task name, taskDesc:
    let taskName = astToStr(name)
    body

template taskWithArgs(name, taskDesc, body){.dirty.} =
  mytask name, taskDesc:
    var args = getArgs taskName
    body

taskWithArgs buildTypst, "build .wasm(wasi) for using as typst plugin":
  requires "wasm-minimal-protocol" & " ^= 0.1.1"
  let res = gorgeEx("nim-typst-plugin -d:typst -d:wasmCustomInit -d:npy_noMain -d:gen_typst -O:" &
    binDir & ' ' & args.quoteShellCommand & ' ' & srcPath)
  if res.exitCode != 0:
    quit res.output
