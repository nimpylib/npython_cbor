
const
  unsignedTag* = 2
  negativeTag* = 3

when defined(cborious):
  import pkg/cborious
  export cborious
  type CborError* = CborInvalidHeaderError
  template writeValue*(s: Stream, val: auto) = cborPack(s, val)
  template readValue*(s: Stream, val: var auto) = cborUnpack(s, val)
  template defineCborWrite*(T; writeImpl){.dirty.} =
    proc cborPack*(s: Stream; val: T) = writeImpl
  template defineCborRead*(T; readImpl){.dirty.} =
    proc cborUnpack*(s: Stream; val: var T) = readImpl
  # def is {CborObjToArray, CborCheckHoleyEnums} instead of CborObjToMap
  const flags = {CborObjToMap, CborEnumAsString, CborCheckHoleyEnums}
  template Cbor_encode*[T](d: T): untyped =
    bind toCbor, flags
    toCbor(d, flags)
  template Cbor_decode*[T](dd; _: typedesc[T]): T =
    bind fromCbor, flags
    fromCbor(dd, T, flags)
else:
  import pkg/cbor_serialization
  import pkg/cbor_serialization/std/[sets as cbor_sets, tables as cbor_tables]
  export cbor_serialization, cbor_sets, cbor_tables
  template defineCborWrite*(T; writeImpl){.dirty.} =
    proc writeValue*(s: var CborWriter; val: T) = writeImpl
  template defineCborRead*(T; readImpl){.dirty.} =
    proc readValue*(s: var CborReader; val: var T) = readImpl
  template Cbor_encode*[T](d: T): untyped =
    bind Cbor, encode
    encode(typeof Cbor, d)
  template Cbor_decode*[T](dd; _: typedesc[T]): T =
    bind Cbor, decode
    decode(typeof Cbor, dd, T)
  
  import pkg/intobject
  proc write*(s: var CborWriter, val: IntObject) {.raises: [IOError].} =
    template toBigOrSmallInt(signEnum: CborSign; signTag, issigned) =
      var i: BiggestUInt
      if val.absToUInt(i):
        s.write CborNumber(sign: signEnum, integer: i)
      else:
        var temp: seq[byte]
        let ret = val.to_bytes(val.byteCount, bigEndian, signed = issigned, res=temp)
        case ret
        of IntObjectToBytesError.Ok: discard
        of LengthNegative, TooBigToConvert, NegativeToUnsigned: doAssert false
        s.write CborTag[seq[byte]](
          tag: signTag,
          val: temp,
        )
    case val.sign
    of IntSign.Positive:
      toBigOrSmallInt(CborSign.None, unsignedTag, false)
    of IntSign.Negative:
      toBigOrSmallInt(CborSign.Neg, negativeTag, true)
    of Zero:
      s.write 0
  proc read*(
    s: var CborReader, val: var IntObject
  ) =
    template p(): untyped =
      s.parser

    let kind = p.cborKind()
    case kind
    of {CborValueKind.Unsigned, CborValueKind.Negative}:
      var val: CborNumber
      s.read(val)
      val = newInt(val.integer)
      if val.sign == CborSign.Neg:
        inc(val, 1)
        val *= -1
    of CborValueKind.Tag:
      var tbint: CborTag[seq[byte]]
      s.read(tbint)
      if tbint.tag notin {unsignedTag, negativeTag}:
        s.parser.raiseUnexpectedValue("tag number 2 or 3", $tbint.tag)
      val = intZero
      var bintSize = 0
      var leadingZero = true
      for v in tbint.val:
        leadingZero = leadingZero and v == 0
        if not leadingZero:
          val = val shl 8
          inc(val, v.int)
          inc bintSize
          if p.conf.bigNumBytesLimit > 0 and bintSize > p.conf.bigNumBytesLimit:
            s.parser.raiseUnexpectedValue("`bigNumBytesLimit` reached")
      if tbint.tag == negativeTag:
        inc(val, 1)
        if p.conf.bigNumBytesLimit > 0 and bintSize + 1 > p.conf.bigNumBytesLimit:
          let maxVal = (newInt(1) shl (p.conf.bigNumBytesLimit * 8)) - newInt(1)
          if val > maxVal:
            s.parser.raiseUnexpectedValue("`bigNumBytesLimit` reached")
        val *= -1
    else:
      s.parser.raiseUnexpectedValue("number", $kind)


template defineCborPair*(T; writeImpl, readImpl){.dirty.} =
  defineCborWrite(T, writeImpl)
  defineCborRead(T, readImpl)

defineCborPair(char, writeValue(s, $val)):
  var v: string
  readValue(s, v)
  if v.len != 1:
    raise newException(CborError, "Expected a single-character string for char unpacking")
  val = v[0]


