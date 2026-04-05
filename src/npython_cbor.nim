

import ./npython_cbor/private/trans_imp

impExpCwd npython_cbor, [impl, cborLib]

when isMainModule:
  import ./npython_cbor/[npy_main_module]
  template pyinit =
    Py_Initialize()
    cbor_Init()
  when defined(typst):
    import pkg/wasm_minimal_protocol
    gen_wasm_init pyinit()

    proc PyRun_String*(str: string; globals: PyDictObject): PyObject{.export_typst_conv(ncTypst).} =
      PyRun_String(str, Eval, globals, globals)
    genTypstFile()
  else:
    pyinit()
    main(init=false)
