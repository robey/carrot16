
# typing has to pause for this long (in milliseconds) before we'll try to recompile.
@typingDelay = 250
@typingTimer = null

@breakpoints = {}
@assembled = null
@scrollTop = []
@memoryReads = []
@memoryWrites = []

# fraction of the time slice we actually spent running the emulator
@cpuHeat = 0.0

# cpu timings
@TIME_SLICE_MSEC = 50
@CLOCK_SPEED_HZ = 100000
@CYCLES_PER_SLICE = Math.floor(@CLOCK_SPEED_HZ * 1.0 / @TIME_SLICE_MSEC)

pad = (num, width) ->
  num = num.toString()
  len = num.length
  ([0 ... width - len].map -> "0").join("") + num

# jquery makes this kinda trivial.
matchHeight = (dest, source) ->
  dest.css("height", source.css("height"))

@log = (message) ->
  $("#log").css("display", "block")
  $("#log").append(message)

# scroll the code-view so that the currently-running line is visible.
scrollToLine = (lineNumber) ->
  line = $("#ln#{lineNumber}")
  if (not line?) or (not line.offset()?) then return
  lineTop = line.offset().top

  codeTab = $("#tab0_content")
  if codeTab.css("display") == "none" then return
  lineHeight = parseInt(codeTab.css("line-height"))
  log = $("#log")
  top = codeTab.position().top
  bottom = top + codeTab.height()
  if log.css("display") != "none" then bottom = Math.min(bottom, log.position().top)
  codeTabLines = Math.floor((bottom - top) / lineHeight)
  if lineTop < top + lineHeight
    codeTab.scrollTop(if lineNumber == 0 then 0 else (lineNumber - 1) * lineHeight)
  else if lineTop > bottom - lineHeight
    codeTab.scrollTop((lineNumber + 2 - codeTabLines) * lineHeight)

positionHighlight = (lineNumber) ->
  highlight = $("#line_highlight")
  if lineNumber?
    highlight.css("top", (lineNumber * highlight.height() + 5) + "px")
    highlight.css("display", "block")
  else
    highlight.css("display", "none")

updateHighlight = (alsoScroll) ->
  if @assembled?
    lineNumber = @assembled.memToLine(@emulator.registers.PC)
    positionHighlight(lineNumber)
    if (alsoScroll) then scrollToLine(lineNumber)
  else
    positionHighlight(null)

updateRegisters = ->
  for r, v of @emulator.registers
    $("#reg#{r}").html(pad(v.toString(16), 4))
  $("#cycles").html(@emulator.cycles)
  # update cpu heat meter
  lowColor = [ 127, 0, 0 ]
  hiColor = [ 255, 0, 0 ]
  # my kingdom for Array.zip
  color = [0...3].map (i) =>
    Math.floor(lowColor[i] + @cpuHeat * (hiColor[i] - lowColor[i]))
  canvas = $("#cpu_heat")[0].getContext("2d")
  canvas.fillStyle = "#fff"
  canvas.fillRect(0, 0, 1, 100)
  canvas.fillStyle = "rgb(#{color[0]},#{color[1]},#{color[2]})"
  canvas.fillRect(0, Math.floor(100 * (1.0 - @cpuHeat)), 1, 100)

@updateMemoryView = ->
  if $("#tab2_content").css("display") == "none" then return
  offset = $("#tab2_content").scrollTop() * 8
  lines = $("#memory_lines")
  dump = $("#memory_dump")
  lines.css("top", offset / 8)
  dump.css("top", offset / 8)
  lines.empty()
  dump.empty()
  for addr in [offset ... Math.min(0x10000, offset + 256)]
    if addr % 8 == 0
      lines.append(pad(addr.toString(16), 4) + ":")
      lines.append($(document.createElement("br")))
    dump.append(" ")
    value = @emulator.memory.peek(addr)
    hex = $(document.createElement("span"))
    hex.append(pad(value.toString(16), 4))
    if addr == @emulator.registers.PC
      hex.addClass("r_pc")
    else if addr == @emulator.registers.SP
      hex.addClass("r_sp")
    else if addr != 0 and addr == @emulator.registers.IA
      hex.addClass("r_ia")
    else if addr in @memoryWrites
      hex.addClass("memory_write")
    else if addr in @memoryReads
      hex.addClass("memory_read")
    dump.append(hex)
    if addr % 8 == 7 then dump.append($(document.createElement("br")))

# build up the dump panel (lines of "offset: words...")
buildDump = ->
  $("#offsets").empty()
  $("#dump").empty()
  if @assembled.errorCount > 0 then return

  for info in @assembled.lines
    if info.data.length == 0
      $("#offsets").append("<br/>")
      $("#dump").append("<br/>")
    else
      $("#offsets").append(pad(info.org.toString(16), 4) + ":<br/>")
      $("#dump").append((for x in info.data then pad(x.toString(16), 4)).join(" ") + "<br/>")

assemble = ->
  lines = $("#code").val().split("\n")

  linenums = (for i in [0 ... lines.length]
    "<span class=linenum id=ln#{i} onclick='toggleBreakpoint(#{i})'>#{i + 1}</span>"
  ).join("")
  $("#linenums").html(linenums)
  $("#log").empty()
  $("#log").css("display", "none")

  emulator.clearMemory()

  logger = (lineno, pos, message) =>
    @log("<span class='line'>#{pad(lineno + 1, 5)}:</span> #{message}<br/>")
    $("#ln#{lineno}").css("background-color", "#f88")
  asm = new d16bunny.Assembler(logger)
  @assembled = asm.compile(lines)

  if @assembled.errorCount == 0
    buffer = @assembled.createImage()
    @emulator.memory.flash(buffer)
    # turn off breakpoints that aren't code anymore.
    for line, isSet of @breakpoints #when isSet
      @setBreakpoint(line, isSet)

  # update UI
  buildDump()
  matchHeight($("#code"), $("#linenums"))
  @resized()

# ----- things that must be accessible from html (globals)

@setBreakpoint = (line, isSet) ->
  if not @assembled.lineToMem(line)? then isSet = false
  @breakpoints[line] = isSet
  if isSet
    $("#ln#{line}").addClass("breakpoint")
  else
    $("#ln#{line}").removeClass("breakpoint")

@toggleBreakpoint = (line) ->
  @setBreakpoint(line, not @breakpoints[line])

@updateViews = (options) ->
  # if @emulator.onFire then: show cool fire image.
  updateHighlight(options?.scroll)
  @updateMemoryView()
  updateRegisters()
  @screen.update(@emulator.memory)

@resized = ->
  # lame html/css makes us recompute the size of the scrollable region for hand-holding purposes.
  extra = if $("#log").css("display") == "none" then 0 else $("#log").outerHeight(true)
  $("#tab0_content").height($(window).height() - $("#tab0_content").position().top - extra)
  $("#tab1_content").height($(window).height() - $("#tab1_content").position().top - extra)
  $("#tab2_content").height(32 * 20 + 7)
  # compensate for extra ceremonial baggage chrome puts around a textarea
  $("#code").outerWidth($("#codebox").width())
  @updateViews()

@codeEdited = ->
  if @typingTimer? then clearTimeout(@typingTimer)
  @typingTimer = setTimeout(@codeChanged, @typingDelay)

@codeChanged = ->
  @typingTimer = null
  assemble()

@toggleTab = (index) ->
  # save scroll position
  for i in [0...3]
    tabContent = $("#tab#{i}_content")
    tab = $("#tab#{i}")
    if tabContent.css("display") != "none" then @scrollTop[i] = tabContent.scrollTop()
    if i == index
      tabContent.css("display", "block")
      tabContent.scrollTop(@scrollTop[i])
      tab.addClass("tab_active")
      tab.removeClass("tab_inactive")
    else
      tabContent.css("display", "none")
      tab.removeClass("tab_active")
      tab.addClass("tab_inactive")
  @updateViews()

@runTimer = null
@run = ->
  if @runTimer?
    @stopRun()
    return
  # Clock.start()
  @runTimer = setInterval((=> @clockTick()), @TIME_SLICE_MSEC)
  $("#button_run").html("&#215; Stop (F5)")

@stopRun = ->
  # Clock.stop()
  clearInterval(@runTimer)
  @runTimer = null
  @lastCycles = null
  $("#button_run").html("&#8595; Run (F5)")
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
    if @breakpoints[@assembled.memToLine(@emulator.registers.PC)]
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
  # keypointer = 0;
  assemble()
  @updateViews(scroll: true)

$(document).ready =>
  @emulator = new carrot16.Emulator()
  @screen = new carrot16.Screen($("#screen"), $("#loading_overlay"), $("#static_overlay"))
  @emulator.hardware.push(@screen)
  @emulator.memory.watchReads 0, 0x10000, (addr) => @memoryReads.push(addr)
  @emulator.memory.watchWrites 0, 0x10000, (addr) => @memoryWrites.push(addr)

  reset()
  $(window).resize (event) -> resized()
  resized()



#  window.localStorage.setItem("robey", "hello")
# window.localStorage.getItem("robey")


