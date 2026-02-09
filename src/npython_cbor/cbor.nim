
import ./cborLib
export cborLib


template CborAgainst*(bareTyp; fieldIdent: untyped): untyped{.dirty.} =

  template writeValue*(w: var CborWriter, value: `Py bareTyp Object`) =
  # template Cbor_encode*(d: `Py bareTyp Object`): untyped =
  #   bind Cbor_encode
    # Cbor_encode(d.fieldIdent)
    writeValue(w, value.fieldIdent)

  # template Cbor_decode*(dd; _: typedesc[`Py bareTyp Object`]): `Py bareTyp Object` =
  #   bind Cbor_decode
  #   let v = Cbor_decode(dd, typeof `Py bareTyp Object`.fieldIdent)
  #   `new Py bareTyp`(v)
  template readValue*(reader: var CborReader, value: var `Py bareTyp Object`) =
    var v: typeof(value.fieldIdent)
    readValue(reader, v)
    value = `new Py bareTyp`(v)

