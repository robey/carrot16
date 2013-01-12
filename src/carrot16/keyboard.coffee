# Generic Keyboard (compatible)

Hardware = require("./emulator").Hardware
Key = require("./key").Key

class Keyboard extends Hardware
  id: 0x30cf7406
  version: 1
  manufacturer: 0x904b3115

  CLEAR_BUFFER: 0
  GET_KEY: 1
  SCAN_KEYBOARD: 2
  SET_INTERRUPT: 3

  BACKSPACE: 0x10
  ENTER: 0x11
  INSERT: 0x12
  DELETE: 0x13
  UP: 0x80
  DOWN: 0x81
  LEFT: 0x82
  RIGHT: 0x83
  SHIFT: 0x90
  CONTROL: 0x91

  constructor: ->
    super(@id, @version, @manufacturer)
    @translate = {}
    @translate[Key.BACKSPACE] = @BACKSPACE
    @translate[Key.ENTER] = @ENTER
    @translate[Key.SHIFT] = @SHIFT
    @translate[Key.CONTROL] = @CONTROL
    @translate[Key.INSERT] = @INSERT
    @translate[Key.DELETE] = @DELETE
    @translate[Key.UP] = @UP
    @translate[Key.DOWN] = @DOWN
    @translate[Key.LEFT] = @LEFT
    @translate[Key.RIGHT] = @RIGHT
    @reset()

  reset: ->
    @buffer = []
    @message = 0
    @pressed = {}

  trigger: ->
    if @message != 0 then @emulator.queueInterrupt(@message)

  send: (key) ->
    @buffer.push(key)
    if @buffer.length > 8 then @buffer.shift()
    @trigger()

  keydown: (key) ->
    @pressed[@translate[key]] = true
    @trigger()
    # have to intercept BACKSPACE & ENTER or chrome will do something weird.
    if key == Key.BACKSPACE
      @send(@BACKSPACE)
      false
    else if key == Key.ENTER
      @send(@ENTER)
      false
    else
      true

  keypress: (key) ->
    # ignore weird ones.
    if key >= 0x20 and key < 0x7f
      @send(key)

  keyup: (key) ->
    @pressed[@translate[key]] = false
    # buffer a key event for the non-ascii keys.
    if key in [ Key.UP, Key.DOWN, Key.LEFT, Key.RIGHT, Key.INSERT, Key.DELETE ]
      @send(@translate[key])
    # macs don't actually have an INSERT key, so let them use ESC.
    if key == Key.ESCAPE then @send(@INSERT)
    @trigger()

  request: (emulator) ->
    switch emulator.registers.A
      when @CLEAR_BUFFER
        @buffer = []
      when @GET_KEY
        emulator.registers.C = if @buffer.length > 0 then @buffer.shift() else 0
      when @SCAN_KEYBOARD
        emulator.registers.C = if @pressed[emulator.registers.B] then 1 else 0
      when @SET_INTERRUPT
        @message = emulator.registers.B
        # can't seem to make this work any other way (why?)
        @emulator = emulator
    0


exports.Keyboard = Keyboard
