# Generic Clock (compatible)

Hardware = require("./emulator").Hardware

class Clock extends Hardware
  id: 0x12d0b402
  version: 1
  manufacturer: 0x904b3115

  SET_FREQUENCY: 0
  GET_TICKS: 1
  SET_INTERRUPT: 2

  constructor: ->
    super(@id, @version, @manufacturer)
    @reset()

  reset: ->
    # heartbeat: # of msec between clock ticks
    @heartbeat = 0
    @ticks = 0

  start: ->
    @stop()
    @timer = setInterval((=> @tick()), 2)
    @last = Date.now()

  stop: ->
    if @timer?
      clearInterval(@timer)
      @timer = null

  tick: ->
    if not @heartbeat then return
    now = Date.now()
    while now - @last >= @heartbeat
      @ticks += 1
      if @message > 0 then @emulator.queueInterrupt(@message)
      @last += @heartbeat

  request: (emulator) ->
    switch emulator.registers.A
      when @SET_FREQUENCY
        @reset()
        @heartbeat = 100 * emulator.registers.B / 6
        # can't seem to make this work any other way (why?)
        @emulator = emulator
      when @GET_TICKS
        emulator.registers.C = @ticks
      when @SET_INTERRUPT
        @message = emulator.registers.B
    0


exports.Clock = Clock
