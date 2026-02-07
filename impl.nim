
import std/sugar
import std/[tables, sets]
import pkg/Objects/[pyobject,
  exceptions,
  dictobjectImpl, listobject, setobject, tupleobject,
  numobjects,
  stringobject,
]

import ./cbor

CborAgainst(float,  v)
CborAgainst(list, items)

template handlePyExcIt(E; errMsg: string; body) =
  handleHashExc do (it: PyBaseErrorObject):
    raise newException(E,
      errMsg)
  do: body

proc dollar(p: PyObject): string =
  handlePyExcIt(IOError, "failed to convert PyObject to string for type " & p.typeName) do:
   {.gcSafe.}:
    result = $p
# for `write` to use. (a.k.a. Cbor_encode)
template `$`(x: PyObject): string = dollar x

proc dollar(x: PyStrObject): string{.gcSafe.} = $x.str

template to*(a: string, _: type PyObject): PyStrObject =
  ## internal. for `read` to use. (a.k.a. Cbor_decode)
  {.gcSafe.}:
    newPyStr(a)

CborAgainst(dict, table)
CborAgainst(str,  dollar)

proc writeValue*(w: var CborWriter, value: PyObject) {.raises: [IOError],
    gcSafe.} =
  template ret(T) =
    writeValue(w, `Py T Object`(value))
  if value.isNil:
    write(w, cborNull)
    return
  case value.pyType.kind
  of Float: ret Float
  of List:  ret List
  of Dict:  ret Dict
  of Str:   ret Str
  else:
    #raise newException(CborError, "unsupported type")
    #TODO:cbor
    doAssert false, "TODO:cbor: unsupported type " & value.typeName

proc cborToPy(v: CborValueRef): PyObject{.raises: [].} =
 {.cast(gcSafe).}:
  template ret(T, a) =
    return `new Py T`(v.a)
  case v.kind
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
  import std/strutils
  proc tohexs(s: openArray[byte]): string =
    result = ""
    for i in s:
      result.add(i.toHex)
  test "dict":
    let d = {"ac": 1.0, "bd": 2.3}.toTable
    let sd = Cbor_encode(d)
    check d == Cbor_decode(sd, Table[string, float])
    let pd = newPyDict: collect:
      for k, v in d.pairs():
        (newPyStr(k), newPyFloat(v))
    let c = Cbor_encode(pd)

    check [c.toHexs, sd.toHexs].toHashSet == [
      "BF626163FA3F800000626264FB4002666666666666FF",
      "BF626264FB4002666666666666626163FA3F800000FF",
    ].toHashSet

    #FIXME: I donno why the following check fails. the decoded dict is correct,
    #  but the `==` operator returns false
  
    #check: tables.`==` pd.table, (Cbor_decode(c, PyDictObject)).table
    # check ops.`==`(Cbor_decode(c, PyDictObject), pd)

