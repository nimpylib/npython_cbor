
import std/unittest
import std/math
import npython_cbor

template chkSingleton[T](v: T, k) =
  let pySingleton = v
  let c = Cbor_encode(pySingleton)
  check Cbor_decode(c, CborValueRef).kind == CborValueKind.k
  check Cbor_decode(c, T) == pySingleton

import std/macros
macro newPy(t: typed):untyped =
  let cb = ident("newPy" &
    $t.getType
  )
  newCall(cb, t)
template chk(x){.dirty.} =
  block hideT:
    let ori = x
    type T = typeof(x)
    let pf = newPy(ori)
    let c = Cbor_encode(pf)
    let ff = Cbor_decode(c, T)
    let pff = Cbor_decode(c, typeof(pf))
    block checkEq:
      when T is SomeFloat:
        if ori.isNaN:
          check ff.isNaN
          check pff.v.isNaN
          break checkEq
      check ff == ori
      check pff == pf

when true:
  Py_Initialize()
  test "none":
    chkSingleton(pyNone, Null)
  test "bool":
    chkSingleton(pyFalseObj, Bool)
    chkSingleton(pyTrueObj, Bool)
  
  suite "int":
    test "small":
      check Cbor_decode("\x01", PyIntObject) == pyIntOne
      chk 123
      chk 1234567890
    test "negative":
      chk -456
    when defined(npyCborIntBigFloat):
      template `==`(a, b: PyIntObject): bool =
        a.toFloat == b.toFloat
    template t(i) =
      let pi = newPyInt(i)
      let c = Cbor_encode(pi)
      check Cbor_decode(c, PyIntObject) == pi
    test "big":
      t "12345678901234567890"
    test "very big":
      when defined(npythonGoodIntFromBigFloat):
        t "123456789011121314151617181920"
      else:
        skip()

  test "float":
    chk 1.23
    chk 1e100
    chk 1e-100
    chk NaN
    chk NegInf
