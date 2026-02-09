
import std/unittest
import std/[sugar, tables, sets]
import npython_cbor

when true:
  Py_Initialize()
  test "none":
    let pnone = pyNone
    let c = Cbor_encode(pnone)
    check Cbor_decode(c, PyNoneObject) == pnone
  
  suite "int":
    template t(i; eq: untyped = `==`) =
      let pi = newPyInt(i)
      let c = Cbor_encode(pi)
      check eq(Cbor_decode(c, PyIntObject), pi)
    test "small":
      t 123
      t "1234567890"
    test "negative":
      t -456
    template `==~`(a, b: PyIntObject): bool =
      a.toFloat == b.toFloat
    test "big":
      t "12345678901234567890", `==~`
    test "very big":
      when defined(npythonGoodIntFromBigFloat):
        t "123456789011121314151617181920", `==~`
      else:
        skip()

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
  test "dict":
    let d = {"ac": 1.0, "bd": 2.3}.toTable
    let sd = Cbor_encode(d)
    check d == Cbor_decode(sd, Table[string, float])
    let pd = newPyDict: collect:
      for k, v in d.pairs():
        (newPyStr(k), newPyFloat(v))
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

