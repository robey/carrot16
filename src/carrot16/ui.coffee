
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
  $("#fire_overlay").css("display", if @emulator.onFire then "block" else "none")
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
  webui.CodeViewSet.resizeAll()
  @updateViews()

# ----- emulator buttons

@runTimer = null
@runUntilPc = null
@run = ->
  if @runTimer?
    @stopRun()
    return
  @runUntilPc = null
  @startRun()

@startRun = ->
  @clock.start()
  @runTimer = setInterval((=> @clockTick()), @TIME_SLICE_MSEC)
  $("#button_run").html("&#215; Stop (F2)")

@stopRun = ->
  @clock.stop()
  clearInterval(@runTimer)
  @runTimer = null
  @lastCycles = null
  $("#button_run").html("&#8595; Run (F2)")
  @emulator.halting = false
  @updateViews(scroll: true)

@clockTick = ->
  if not @lastCycles? then @lastCycles = @emulator.cycles
  startTime = @prepareRun()
  loop
    if not @runTimer? then return
    @emulator.step()
    if not @runTimer? then return
    if @emulator.onFire or (@emulator.registers.PC == @runUntilPc) or webui.CodeViewSet.atBreakpoint()
      @stopRun()
      return
    if @emulator.halting or (@emulator.cycles >= @lastCycles + @CYCLES_PER_SLICE)
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

@stepOver = ->
  if @runTimer?
    @stopRun()
    return
  @runUntilPc = @emulator.nextInstructionPc()
  @startRun()

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
  if not @runTimer? then return true
  @keyboard.keydown(event.which)

$(document).keypress (event) =>
  if webui.EditBox.keypress(event.which) then return false
  if not @runTimer? then return true
  @keyboard.keypress(event.which)

$(document).keyup (event) =>
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

  $(document).bind "keydown", "alt+n", => (webui.Project.openNew(); webui.Project.saveSession(); false)
  $(document).bind "keydown", "alt+o", => (webui.Project.load(); false)
  $(document).bind "keydown", "alt+r", => (webui.Project.rename(); false)
  $(document).bind "keydown", "alt+s", => (webui.Project.save(); false)
  $(document).bind "keydown", "alt+w", => (webui.Project.closeTab(); webui.Project.saveSession(); false)

  $(document).bind "keydown", "f1", => (reset(); false)
  $(document).bind "keydown", "f2", => (run(); false)
  $(document).bind "keydown", "f3", => (step(); false)
  $(document).bind "keydown", "f4", => (stepOver(); false)
  $(document).bind "keydown", "alt+tab", => (webui.Tabs.next(); false)
  $(document).bind "keydown", "alt+shift+tab", => (webui.Tabs.previous(); false)

  if not webui.Project.loadSession()
    # load the demo.
    pane = webui.Tabs.openNewEditor()
    pane.setCode(webui.DEMO_CODE)
    pane.setName("demo")

  reset()
  $(window).resize (event) -> resized()
  resized()
