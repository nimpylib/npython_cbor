

import ./npython_cbor/private/trans_imp

impExpCwd npython_cbor, [impl, cborLib]

when isMainModule:
  import ./npython_cbor/[npy_main_module]
  Py_Initialize()
  cbor_Init()
  main(init=false)
