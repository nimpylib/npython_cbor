
import std/unittest
import std/[sugar, tables, sets]
import npython_cbor


test "list":
  let l = @[1.0, 2.0, 3.0]
  let pl = collect:
    for i in l:
      newPyFloat(i)
  let pyl: PyListObject = newPyList(pl)
  let c = Cbor_encode(pyl)
  check c == Cbor_encode(l)
  check ops.`==`(Cbor_decode(c, PyListObject), pyl)
test "dict":
  let d = {"ac": -1, "bd": 2}.toTable
  let sd = Cbor_encode(d)
  check d == Cbor_decode(sd, Table[string, int])
  let pd = newPyDict: collect:
    for k, v in d.pairs():
      (newPyStr(k), newPyInt(v))
  let c = Cbor_encode(pd)

  check pd == Cbor_decode(c, PyDictObject)

test "set":
  let s = ["a", "b", "c"].toHashSet
  let ps = newPySet: collect:
    for i in s:
      PyObject newPyStr(i)
  let c = Cbor_encode(ps)
  check c == Cbor_encode(s)
  let ss = Cbor_decode(c, PySetObject)
  check ss == ps
