
# turn objects into bytes
Congeal =
  # for 16-bit unicode
  spackU16: (n) -> String.fromCharCode(n)
  sunpackU16: (s, i=0) -> s.charCodeAt(i)
  spackU32: (n) -> @packU16(n & 0xffff) + @packU16(Math.floor(n / 65536))
  sunpackU32: (s, i=0) -> @unpackU16(s, i + 0) + @unpackU16(s, i + 1) * 65536
  spackU48: (n) -> @packU16(n & 0xffff) + @packU32(Math.floor(n / 65536))
  sunpackU48: (s, i=0) -> @unpackU16(s, i + 0) + @unpackU32(s, i + 1) * 65536

  # for 8 bits
  packU8: (n) -> String.fromCharCode(n)
  unpackU8: (s, i=0) -> s.charCodeAt(i)
  packU16: (n) -> @packU8(n & 0xff) + @packU8(Math.floor(n / 256))
  unpackU16: (s, i=0) -> @unpackU8(s, i + 0) + (@unpackU8(s, i + 1) * 256)
  packU32: (n) -> @packU16(n & 0xffff) + @packU16(Math.floor(n / 65536))
  unpackU32: (s, i=0) -> @unpackU16(s, i + 0) + (@unpackU16(s, i + 2) * 65536)
  packU48: (n) -> @packU16(n & 0xffff) + @packU32(Math.floor(n / 65536))
  unpackU48: (s, i=0) -> @unpackU16(s, i + 0) + (@unpackU32(s, i + 2) * 65536)

  uniqueId: ->
    x = Math.floor(Math.random() * 65536 * 65536)
    id = @packU48(Date.now()) + @packU32(x)
    # "+" and "/" are no good
    btoa(id)[0...14].replace(/\+/, "-").replace(/\//, "_")

exports.Congeal = Congeal
