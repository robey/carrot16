
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

@load = ->
  $("#load_input").click()

@loadReally = (event) ->
  file = event.target.files[0]
  # reset the chosen file, so it can be chosen again later.
  $("#load_input")[0].value = ""
  if not file.type.match("text.*")
    webui.LogPane.clear()
    webui.LogPane.log("Not a text file: " + file.name)
    return
  reader = new FileReader()
  reader.onerror = (e) =>
    webui.LogPane.clear()
    webui.LogPane.log("Error reading file: " + file.name)
  reader.onload = (e) =>
    view = new webui.CodeView()
    view.setName(file.name)
    view.setCode(e.target.result)
    view.activate()
  reader.readAsText(file)

# ----- emulator buttons

@runTimer = null
@run = ->
  if @runTimer?
    @stopRun()
    return
  @clock.start()
  @runTimer = setInterval((=> @clockTick()), @TIME_SLICE_MSEC)
  $("#button_run").html("&#215; Stop (^R)")

@stopRun = ->
  @clock.stop()
  clearInterval(@runTimer)
  @runTimer = null
  @lastCycles = null
  $("#button_run").html("&#8595; Run (^R)")
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
      $("#load_input").click()
      return false
    when Key.F4
      reset()
      return false
    when Key.F5
      $("#button_run").click()
      return false
    when Key.F6
      step()
      return false
  if not @runTimer?
    if webui.Tabs.activePane?.data("keydown")?
      return webui.Tabs.activePane?.data("keydown")(event.which)
    return true
  @keyboard.keydown(event.which)

$(document).keypress (event) =>
  if webui.EditBox.keypress(event.which) then return false
  switch event.which
    when 3 # ^C
      reset()
      return false
    when 12 # ^L
      $("#load_input").click()
      return false
    when 14 # ^N
      step()
      return false
    when 18 # ^R
      $("#button_run").click()
      return false
    when 19 # ^S
      window.URL = window.webkitURL or window.URL
      if webui.CodeViewSet.visible()
        codeview = webui.Tabs.activePane.data("codeview")
        a = $("<a/>")
        a.attr("download", codeview.getName())
        a.attr("href", window.URL.createObjectURL(codeview.save()))
        a.css("display", "hidden")
        $("#body").append(a)
        a[0].click()
        a.remove()
        return false
  if not @runTimer? then return true
  @keyboard.keypress(event.which)

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

  # thread "load" clicks through to the real file loader. (the web sucks.)
  $("#load_input").bind("change", loadReally)

  webui.Registers.init()
  webui.Tabs.init()
  webui.MemView.init()
  webui.Tabs.openNewEditor()

  reset()
  $(window).resize (event) -> resized()
  resized()



#  window.localStorage.setItem("robey", "hello")
# window.localStorage.getItem("robey")

