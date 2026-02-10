
import ./private/trans_imp
impExp pkg/Objects, [pyobject,
  moduleobjectImpl, typeobject,
  exceptions, boolobject, noneobject,
  dictobjectImpl, listobject, setobject, tupleobject,
  numobjects,
  stringobject, byteobjects,
]

impExp pkg/Python, [npython, pythonrun, sysmodule_instance]
# import pkg/Python/getargs/[vargs, va_and_kw, dispatch]

import ./[impl, cborLib]
export impl, cborLib

declarePyType CborModule(base(Module)):
  discard

implCborModuleMethod loads(obj):
  let bytesObj = PyBytes_FromObject obj
  retIfExc bytesObj
  let bytes = PyBytesObject(bytesObj)
  try:
    result = Cbor_decode(bytes.items.toOpenArrayByte(0, bytes.items.high), PyObject)
  except SerializationError as e:
    return newValueError newPyAscii("failed to decode CBOR data: " & e.msg)

implCborModuleMethod dumps(obj):
  newPyBytes Cbor_encode(obj)

var npysys{.exportc.}: typeof sys
proc cbor_Init* =
  npysys = sys
  let moduObj = PyModule_CreateInitialized(cbor)
  if moduObj.isThrownException:
    raise newException(IOError, "failed to initialize CBOR module: " & $moduObj)
  let modu = PyModuleObject(moduObj)
  sys.modules[modu.name] = modu
  # Python's popular pkg for CBOR is named cbor2
  #  so also add it under that name for compatibility with cbor2-using code
  sys.modules[modu.name & '2'] = modu


