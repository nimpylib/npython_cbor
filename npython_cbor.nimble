# Package

version       = "0.1.0"
author        = "litlighilit"
description   = "cbor library for npython"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["npython_cbor"]
binDir        =  "bin"

# Dependencies

requires "nim > 2.0.8"
requires "npython"
requires "cbor_serialization"
