
import std/sugar
import pkg/Objects/[pyobject,
  exceptions,
  dictobject, listobject, setobject, tupleobject,
  numobjects,
  stringobject,
]

import ./cbor

CborAgainst(float,  v)
CborAgainst(list, items)

proc writeValue*(w: var CborWriter, value: PyObject) {.raises: [IOError].} =
  template ret(T) =
    writeValue(w, `Py T Object`(value))
  case value.pyType.kind
  of Float: ret Float
  of List:  ret List
  #TODO
  else:
    #raise newException(CborError, "unsupported type")
    #TODO:cbor
    doAssert false, "TODO:cbor: unsupported type " & value.typeName

proc cborToPy(v: CborValueRef): PyObject =
 {.cast(gcSafe).}:
  template ret(T, a) =
    return `new Py T`(v.a)
  case v.kind
  of Float: ret Float, floatVal
  of Array:
    return newPyList: collect:
      for item in v.arrayVal:
        cborToPy(item)
  else:
    #TODO:cbor:tag
    return newNotImplementedError newPyAscii"CBOR tag is not supported for now"

proc readValue*(reader: var CborReader, value: var PyObject) =
  var v: CborValueRef
  readValue(reader, v)
  let val = cborToPy(v)
  {.gcSafe.}:
   if val.isThrownException:
    raise newException(CborError, $val)
  value = val

when isMainModule:
  import std/unittest

  test "float":
    let f = 1.23
    let pf = newPyFloat(f)
    let c = Cbor_encode(pf)
    check Cbor_decode(c, PyFloatObject) == pf

  test "list":
    let l = @[1.0, 2.0, 3.0]
    let pl = collect:
      for i in l:
        newPyFloat(i)
    let pyl: PyListObject = newPyList(pl)
    let c = Cbor_encode(pyl)
    check c == Cbor_encode(l)
    check ops.`==`(Cbor_decode(c, PyListObject), pyl)
    #check pyl == Cbor_decode(c, PyListObject)

