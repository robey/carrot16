
@memoryReads = []
@memoryWrites = []

# fraction of the time slice we actually spent running the emulator
@cpuHeat = 0.0

# cpu timings
@TIME_SLICE_MSEC = 50
@CLOCK_SPEED_HZ = 100000
@CYCLES_PER_SLICE = Math.floor(@CLOCK_SPEED_HZ * @TIME_SLICE_MSEC / 1000)


# ----- things that must be accessible from html (globals)

@updateViews = (options) ->
  # FIXME: if @emulator.onFire then: show cool fire image.
  if webui.CodeViewSet.visible()
    webui.CodeViewSet.updatePcHighlight(options?.scroll)
  webui.MemView.update()
  webui.Registers.update()
  @screen.update(@emulator.memory)

@resized = ->
  # lame html/css makes us recompute the size of the scrollable region for hand-holding purposes.
  padding = $(".navbar").height() + 10
  $(".navbar-spacer").height(padding)
  $("#body").height($(window).height() - padding)
  webui.MemView.resized()
  @updateViews()

# ----- emulator buttons

@runTimer = null
@run = ->
  if @runTimer?
    @stopRun()
    return
  @clock.start()
  @runTimer = setInterval((=> @clockTick()), @TIME_SLICE_MSEC)
  $("#button_run").html("&#215; Stop (F2)")

@stopRun = ->
  @clock.stop()
  clearInterval(@runTimer)
  @runTimer = null
  @lastCycles = null
  $("#button_run").html("&#8595; Run (F2)")
  @updateViews(scroll: true)

@clockTick = ->
  if not @lastCycles? then @lastCycles = @emulator.cycles
  startTime = @prepareRun()
  loop
    if not @runTimer? then return
    @emulator.step()
    if not @runTimer? then return
    if @emulator.onFire
      @stopRun()
      return
    if webui.CodeViewSet.atBreakpoint()
      @stopRun()
      return
    if @emulator.cycles >= @lastCycles + @CYCLES_PER_SLICE
      # funny math here is because we might have done more cycles than we
      # were supposed to. so we want them to be credited to the next slice.
      @lastCycles += @CYCLES_PER_SLICE
      @cleanupRun(startTime)
      @updateViews()
      return

@step = ->
  if @runTimer?
    @stopRun()
    return
  @prepareRun()
  @emulator.step()
  # no point in updating the cpu heat, since we didn't do a full slice.
  @updateViews(scroll: true)

@prepareRun = ->
  @memoryReads = []
  @memoryWrites = []
  Date.now()

@cleanupRun = (startTime) ->
  @cpuHeat = (Date.now() - startTime) * 1.0 / @TIME_SLICE_MSEC

@reset = ->
  @memoryReads = []
  @memoryWrites = []
  @cpuHeat = 0.0
  @emulator.reset()
  @screen.reset()
  setTimeout((=> webui.CodeViewSet.assemble()), 0)
  @updateViews(scroll: true)

# ----- top-level keyboard control

Key = carrot16.Key

# return false to abort default handling of the event.
$(document).keydown (event) =>
  if webui.EditBox.keydown(event.which) then return false
  switch event.which
    when Key.TAB
      webui.Tabs.next()
      return false
    when Key.F1
      reset()
      return false
    when Key.F2
      $("#button_run").click()
      return false
    when Key.F3
      step()
      return false
  if not @runTimer?
    if webui.Tabs.activePane?.data("keydown")?
      return webui.Tabs.activePane?.data("keydown")(event.which)
    return true
  @keyboard.keydown(event.which)

$(document).keypress (event) =>
  if webui.EditBox.keypress(event.which) then return false
  if @runTimer? then return @keyboard.keypress(event.which)
  if webui.Project.keypress(event.which) then return false
  true

$(document).keyup (event) =>
  if @input? then return true
  if webui.Tabs.activePane?.data("keyup")?
    return webui.Tabs.activePane?.data("keyup")(event.which)
  if not @runTimer? then return true
  @keyboard.keyup(event.which)

$(document).ready ->
  webui.LogPane.init()
  webui.CodeViewSet.init()
  
$(document).ready =>
  @emulator = new carrot16.Emulator()
  @clock = new carrot16.Clock()
  @emulator.hardware.push(@clock)
  @screen = new carrot16.Screen($("#screen"), $("#loading_overlay"), $("#static_overlay"))
  @emulator.hardware.push(@screen)
  @keyboard = new carrot16.Keyboard()
  @emulator.hardware.push(@keyboard)
  @emulator.memory.watchReads 0, 0x10000, (addr) => @memoryReads.push(addr)
  @emulator.memory.watchWrites 0, 0x10000, (addr) => @memoryWrites.push(addr)

  webui.Project.init()
  webui.Registers.init()
  webui.Tabs.init()
  webui.MemView.init()
  webui.Tabs.openNewEditor().setCode(DEMO)

  reset()
  $(window).resize (event) -> resized()
  resized()


DEMO = """; demo
set a, 0
set b, 0x80
hwi 1
set a, 3
set b, 1
hwi 1
set a, 5
set b, 0x200
hwi 1
set [0x200], 0x666
set a, 2
set b, 0x200
hwi 1
:go
set [0x80], 0xe068
set [0x81], 0xc069
set [0x82], 0x8007
set [0x83], [0x80]
set [0xa0], 0xe0d2
set [0xa1], 0xe0cf
set [0xa2], 0xe0c2
set [0xa3], 0xe0c5
set [0xa4], 0xe0d9
jmp go
SUB PC, 1
"""

#  window.localStorage.setItem("robey", "hello")
# window.localStorage.getItem("robey")

