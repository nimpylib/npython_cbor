
import std/sugar
import std/math
import std/[tables, sets]
import ./npy
export npy

import ./cbor
defineCborPair(PyNoneObject, writeValue(s, cborNull)):
  var v: CborVoid
  readValue(s, v)
  val = pyNone

#XXX:typst use float for big ints to avoid overflow
#  typst doesn't support cbor tags
defineCborPair PyIntObject:
 {.gcSafe.}:
  var i: BiggestUInt
  if val.absToUInt i:
    var num: CborNumber
    num.integer = i
    if val.negative:
      num.sign = CborSign.Neg
    writeValue(s, num)
  else:
    # for big ints, serialize as string to avoid overflow
    writeValue(s, val.toFloat)
do:
  case s.parser.cborKind()
  of Unsigned, CborValueKind.Negative, CborValueKind.Simple:
    var num: CborNumber
    readValue(s, num)
    val = newPyInt(num.integer)
    if num.sign == CborSign.Neg:
      val.negate()
  of CborValueKind.Float:
    var f: float64
    readValue(s, f)
    if floor(f) != f:
      raise newException(CborError, "float is not an integer")
    let i = newPyInt(f)
    if i.isThrownException:
      raise newException(CborError, $i)
    val = PyIntObject i
  else:
    raise newException(CborError, "invalid CBOR type for PyIntObject")

CborAgainst(bool,   b)
CborAgainst(float,  v)
CborAgainst(list, items)
CborAgainst(Tuple,items)

template handlePyExcIt(E; errMsg: string; body) =
  handleHashExc do (it: PyBaseErrorObject):
    raise newException(E,
      errMsg)
  do: body

proc dollar(p: PyObject): string =
  handlePyExcIt(IOError, "failed to convert PyObject to string for type " & p.typeName) do:
   {.gcSafe.}:
    result = $p

#XXX:cbor_serialization-BUG: it only supports string keys, but cbor supports more types for keys
# for `write` to use. (a.k.a. Cbor_encode)
# template `$`(x: PyObject): string = dollar x
defineCborWrite Table[PyObject, PyObject]:
  s.beginObject()
  for key, v in val:
    s.writeField key.dollar, v
  s.endObject()

proc dollar(x: PyStrObject): string{.gcSafe.} = $x.str

template to*(a: string, _: type PyObject): PyStrObject =
  ## internal. for `read` to use. (a.k.a. Cbor_decode)
  {.gcSafe.}:
    newPyStr(a)

CborAgainst(dict, table)
CborAgainst(str,  dollar)
CborAgainst(bytes,items)

proc incl*(s: var HashSet[PyObject], item: PyObject){.raises: [SerializationError].} =
  handleHashExc do (x: PyBaseErrorObject):
    raise newException(SerializationError,
      "unhashable type in set: " & item.typeName)
  do: {.gcSafe.}:
    sets.incl(s, item)

CborAgainst(set,  items)
CborAgainst(frozenset,  items)

proc writeValue*(w: var CborWriter, value: PyObject) {.raises: [IOError],
    gcSafe.} =
  template ret(T) =
    writeValue(w, `Py T Object`(value))
  if value.isNil:
    write(w, cborNull)
    return
  case value.pyType.kind
  of None:  ret None
  of Bool:  ret Bool
  of Int:   ret Int
  of Float: ret Float
  of List:  ret List
  of Tuple: ret Tuple
  of Dict:  ret Dict
  of Str:   ret Str
  of Bytes: ret Bytes
  of Set:   ret Set
  of Frozenset:ret Frozenset
  else:
    #raise newException(CborError, "unsupported type")
    #TODO:cbor
    doAssert false, "TODO:cbor: unsupported type " & value.typeName

proc cborToPy(v: CborValueRef): PyObject{.raises: [].} =
 {.cast(gcSafe).}:
  template ret(T, a) =
    return `new Py T`(v.a)
  case v.kind
  of Null:  return pyNone
  of Undefined: return pyNone  # treat undefined as None?
  of Bool:  ret Bool,  boolVal
  of Simple:
    template simpleUint8(x): uint8 =
      x.simpleVal.uint8
    ret Int, simpleUint8
  of Unsigned: return newPyInt v.numVal.integer
  of CborValueKind.Negative:
    let res = newPyInt v.numVal.integer
    return -res
  of Float: ret Float, floatVal
  of Array:
    return newPyList: collect:
      for item in v.arrayVal:
        cborToPy(item)
  of Object:
    return newPyDict: collect:
      for k, v in v.objVal:
        (newPyStr(k), cborToPy(v))
  of String: ret Str, strVal
  of Bytes:  ret Bytes,bytesVal
  # cbor has no set, tuple
  of Tag:
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
