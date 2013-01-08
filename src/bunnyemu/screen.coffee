# Low Energy Monitor LEM1802 (NYA_ELEKTRISKA)

Hardware = require("./emulator").Hardware

pad = (num, width) ->
  num = num.toString()
  len = num.length
  ([0 ... width - len].map -> "0").join("") + num

class Screen extends Hardware
  id: 0x7349f615
  version: 0x1802
  manufacturer: 0x1c6c8b36

  screenMap: 0 # disconnected = 0
  fontMap: 0
  paletteMap: 0
  borderColor: 0

  # how long to show static before the monitor is ready
  STATIC_TIMER: 250

  DISPLAY_WIDTH: 128
  DISPLAY_HEIGHT: 96
  PIXEL_SIZE: 3

  TEXT_WIDTH: 32
  TEXT_HEIGHT: 12
  CELL_WIDTH: 4
  CELL_HEIGHT: 8

  DEFAULT_PALETTE: [
    [0x00, 0x00, 0x00, 0xff],
    [0x00, 0x00, 0xaa, 0xff],
    [0x00, 0xaa, 0x00, 0xff],
    [0x00, 0xaa, 0xaa, 0xff],
    [0xaa, 0x00, 0x00, 0xff],
    [0xaa, 0x00, 0xaa, 0xff],
    [0xaa, 0x55, 0x00, 0xff],
    [0xaa, 0xaa, 0xaa, 0xff],
    [0x55, 0x55, 0x55, 0xff],
    [0x55, 0x55, 0xff, 0xff],
    [0x55, 0xff, 0x55, 0xff],
    [0x55, 0xff, 0xff, 0xff],
    [0xff, 0x55, 0x55, 0xff],
    [0xff, 0x55, 0xff, 0xff],
    [0xff, 0xff, 0x55, 0xff],
    [0xff, 0xff, 0xff, 0xff]
  ]

  # default font by Notch
  DEFAULT_FONT: [
    0x000f, 0x0808, 0x080f, 0x0808, 0x08f8, 0x0808, 0x00ff, 0x0808, 
    0x0808, 0x0808, 0x08ff, 0x0808, 0x00ff, 0x1414, 0xff00, 0xff08,
    0x1f10, 0x1714, 0xfc04, 0xf414, 0x1710, 0x1714, 0xf404, 0xf414,
    0xff00, 0xf714, 0x1414, 0x1414, 0xf700, 0xf714, 0x1417, 0x1414,
    0x0f08, 0x0f08, 0x14f4, 0x1414, 0xf808, 0xf808, 0x0f08, 0x0f08,
    0x001f, 0x1414, 0x00fc, 0x1414, 0xf808, 0xf808, 0xff08, 0xff08,
    0x14ff, 0x1414, 0x080f, 0x0000, 0x00f8, 0x0808, 0xffff, 0xffff, 
    0xf0f0, 0xf0f0, 0xffff, 0x0000, 0x0000, 0xffff, 0x0f0f, 0x0f0f, 
    0x0000, 0x0000, 0x005f, 0x0000, 0x0300, 0x0300, 0x3e14, 0x3e00, 
    0x266b, 0x3200, 0x611c, 0x4300, 0x3629, 0x7650, 0x0002, 0x0100, 
    0x1c22, 0x4100, 0x4122, 0x1c00, 0x2a1c, 0x2a00, 0x083e, 0x0800, 
    0x4020, 0x0000, 0x0808, 0x0800, 0x0040, 0x0000, 0x601c, 0x0300, 
    0x3e41, 0x3e00, 0x427f, 0x4000, 0x6259, 0x4600, 0x2249, 0x3600, 
    0x0f08, 0x7f00, 0x2745, 0x3900, 0x3e49, 0x3200, 0x6119, 0x0700, 
    0x3649, 0x3600, 0x2649, 0x3e00, 0x0024, 0x0000, 0x4024, 0x0000, 
    0x0814, 0x2241, 0x1414, 0x1400, 0x4122, 0x1408, 0x0259, 0x0600, 
    0x3e59, 0x5e00, 0x7e09, 0x7e00, 0x7f49, 0x3600, 0x3e41, 0x2200, 
    0x7f41, 0x3e00, 0x7f49, 0x4100, 0x7f09, 0x0100, 0x3e49, 0x3a00, 
    0x7f08, 0x7f00, 0x417f, 0x4100, 0x2040, 0x3f00, 0x7f0c, 0x7300, 
    0x7f40, 0x4000, 0x7f06, 0x7f00, 0x7f01, 0x7e00, 0x3e41, 0x3e00, 
    0x7f09, 0x0600, 0x3e41, 0xbe00, 0x7f09, 0x7600, 0x2649, 0x3200, 
    0x017f, 0x0100, 0x7f40, 0x7f00, 0x1f60, 0x1f00, 0x7f30, 0x7f00, 
    0x7708, 0x7700, 0x0778, 0x0700, 0x7149, 0x4700, 0x007f, 0x4100, 
    0x031c, 0x6000, 0x0041, 0x7f00, 0x0201, 0x0200, 0x8080, 0x8000, 
    0x0001, 0x0200, 0x2454, 0x7800, 0x7f44, 0x3800, 0x3844, 0x2800, 
    0x3844, 0x7f00, 0x3854, 0x5800, 0x087e, 0x0900, 0x4854, 0x3c00, 
    0x7f04, 0x7800, 0x447d, 0x4000, 0x2040, 0x3d00, 0x7f10, 0x6c00, 
    0x417f, 0x4000, 0x7c18, 0x7c00, 0x7c04, 0x7800, 0x3844, 0x3800, 
    0x7c14, 0x0800, 0x0814, 0x7c00, 0x7c04, 0x0800, 0x4854, 0x2400, 
    0x043e, 0x4400, 0x3c40, 0x7c00, 0x1c60, 0x1c00, 0x7c30, 0x7c00, 
    0x6c10, 0x6c00, 0x4c50, 0x3c00, 0x6454, 0x4c00, 0x0836, 0x4100, 
    0x0077, 0x0000, 0x4136, 0x0800, 0x0201, 0x0201, 0x704c, 0x7000
  ]

  constructor: (@screenElement, @loadingElement, @staticElement) ->
    super(@id, @version, @manufacturer)
    @screen = @screenElement[0].getContext("2d")
    @image = @screen.createImageData(@DISPLAY_WIDTH * @PIXEL_SIZE, @DISPLAY_HEIGHT * @PIXEL_SIZE)
    @reset()

  reset: ->
    @screenMap = 0
    @fontMap = 0
    @paletteMap = 0
    @borderColor = 0
    for x in [0 ... @DISPLAY_WIDTH * @PIXEL_SIZE]
      for y in [0 ... @DISPLAY_HEIGHT * @PIXEL_SIZE]
        for i in [0 ... 3]
          @image.data[(y * @DISPLAY_WIDTH * @PIXEL_SIZE + x) * 4 + i] = 0
        # alpha:
        @image.data[(y * @DISPLAY_WIDTH * @PIXEL_SIZE + x) * 4 + 3] = 0xff
    @timings = []
    @update()

  blankOn: ->
    @loadingElement.css("display", "block")

  blankOff: ->
    @loadingElement.css("display", "none")

  staticOn: ->
    @staticElement.css("display", "block")
    setTimeout((=> @staticOff()), @STATIC_TIMER)

  staticOff: ->
    @staticElement.css("display", "none")

  request: (emulator) ->
    switch emulator.registers.A
      when 0 # MEM_MAP_SCREEN
        map = emulator.registers.B
        if map == 0
          @blankOn()
        else
          @blankOff()
          if @screenMap == 0
            # when the screen first comes on, you get a burst of static.
            @staticOn()
        @screenMap = map
      when 1 # MEM_MAP_FONT
        @fontMap = emulator.registers.B
      when 2 # MEM_MAP_PALETTE
        @paletteMap = emulator.registers.B
      when 3 # SET_BORDER_COLOR
        @borderColor = emulator.registers.B & 0xf

  update: (memory) ->
    if @screenMap == 0
      @blankOn()
      return

    startTime = Date.now()
    palette = @DEFAULT_PALETTE
    if @paletteMap > 0
      palette = []
      for i in [@paletteMap ... @paletteMap + 16]
        color = memory[i & 0xffff] & 0xffff
        palette.push([
          ((color >> 8) & 0xf) << 4,
          ((color >> 4) & 0xf) << 4,
          ((color)      & 0xf) << 4,
          0xff
        ])

    map = @screenMap
    lineSize = @DISPLAY_WIDTH * @PIXEL_SIZE * 4
    $("#log").empty()
    for y in [0 ... @TEXT_HEIGHT]
      for x in [0 ... @TEXT_WIDTH]
        cell = memory[map & 0xffff]
        fc = palette[(cell >> 12) & 0xf]
        bc = palette[(cell >> 8) & 0xf]
        fontOffset = (cell & 0x7f) << 1
        fontWord = if @fontMap == 0
          (@DEFAULT_FONT[fontOffset] << 16) | @DEFAULT_FONT[fontOffset + 1]
        else
          (memory[@fontMap + fontOffset] << 16) | memory[@fontMap + fontOffset + 1]
        blink = (cell & 0x80) != 0

        # "blit" the character out.
        bit = (1 << 31)
        for cx in [0 ... @CELL_WIDTH]
          xbase = (x * @CELL_WIDTH + cx) * @PIXEL_SIZE
          for cy in [0 ... @CELL_HEIGHT]
            ybase = ((y + 1) * @CELL_HEIGHT - cy - 1) * @PIXEL_SIZE
            color = if (fontWord & bit) == bit then fc else bc
            for px in [0 ... @PIXEL_SIZE]
              for py in [0 ... @PIXEL_SIZE]
                offset = (ybase + py) * lineSize + ((xbase + px) * 4)
                @image.data[offset + 0] = color[0]
                @image.data[offset + 1] = color[1]
                @image.data[offset + 2] = color[2]
                @image.data[offset + 3] = color[3]
            bit = (bit >> 1) & 0x7fffffff
        map += 1

    @screen.putImageData(@image, 0, 0)

    color = palette[@borderColor]
    @screenElement.css("background-color", "#" + pad(color[0].toString(16), 2) + pad(color[1].toString(16), 2) + pad(color[2].toString(16), 2))

    duration = Date.now() - startTime
    @timings.push(duration)
    if @timings.length > 25 then @timings.shift()
    $("#log").css("display", "block")
    $("#log").html("screen: " + @timings.join(" "))

exports.Screen = Screen

