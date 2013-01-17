
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

# scroll the code-view so that the currently-running line is visible.
scrollToLine = (lineNumber) ->
  line = $("#ln#{lineNumber}")
  if (not line?) or (not line.offset()?) then return
  lineTop = line.offset().top

  codeTab = $(".pane-editor")
  if codeTab.css("display") == "none" then return
  lineHeight = parseInt(codeTab.css("line-height"))
  top = codeTab.position().top
  bottom = Math.min(top + codeTab.height(), webui.LogPane.top())
  codeTabLines = Math.floor((bottom - top) / lineHeight)
  if lineTop < top + lineHeight
    codeTab.scrollTop(if lineNumber == 0 then 0 else (lineNumber - 1) * lineHeight)
  else if lineTop > bottom - lineHeight
    codeTab.scrollTop((lineNumber + 2 - codeTabLines) * lineHeight)

positionHighlight = (lineNumber) ->
  highlight = $(".code-pc-line")
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

# build up the dump panel (lines of "offset: words...")
buildDump = ->
  $(".code-addr").empty()
  $(".code-dump").empty()
  if @assembled.errorCount > 0 then return

  for info in @assembled.lines
    if info.data.length == 0
      $(".code-addr").append("<br/>")
      $(".code-dump").append("<br/>")
    else
      $(".code-addr").append(pad(info.org.toString(16), 4) + ":<br/>")
      $(".code-dump").append((for x in info.data then pad(x.toString(16), 4)).join(" ") + "<br/>")

assemble = ->
  lines = $(".code-textarea").val().split("\n")

  linenums = (for i in [0 ... lines.length]
    "<span class=linenum id=ln#{i} onclick='toggleBreakpoint(#{i})'>#{i + 1}</span>"
  ).join("")
  $(".code-linenums").html(linenums)
  webui.LogPane.clear()

  emulator.clearMemory()

  logger = (lineno, pos, message) =>
    webui.LogPane.log("<span class='line'>#{pad(lineno + 1, 5)}:</span> #{message}")
    $("#ln#{lineno}").css("background-color", "#f88")
  asm = new d16bunny.Assembler(logger)
  @assembled = asm.compile(lines)

  if @assembled.errorCount == 0
    buffer = @assembled.createImage(@emulator.memory.memory)
    # turn off breakpoints that aren't code anymore.
    for line, isSet of @breakpoints #when isSet
      @setBreakpoint(line, isSet)

  # update UI
  buildDump()
  matchHeight($(".code-textarea"), $(".code-linenums"))
  @resized()

# ----- weird keyboard input logic

@fetchInput = (element, callback) ->
  if @input
    @cancelInput()
    return
  @input =
    element: element
    color: element.css("color")
    backgroundColor: element.css("background-color")
    flashing: true
    count: 4
    callback: callback
    blinker: setInterval((=> @blinkInput()), 250)
    # you have ten seconds to figure it out.
    timeout: setTimeout((=> @cancelInput()), 10000)
  element.css("color", "#f99")
  element.css("background-color", "#000")
  element.html("----")

@blinkInput = ->
  @input.element.css("color", if @input.flashing then "#000" else "#f99")
  @input.flashing = not @input.flashing

@cancelInput = ->
  @input.element.css("color", "")
  @input.element.css("background-color", "")
  clearTimeout(@input.timeout)
  clearInterval(@input.blinker)
  if @input.element.html() == "----" then @input.element.html("0000")
  @input.callback(parseInt(@input.element.html(), 16))
  @input = null

# ----- things that must be accessible from html (globals)

@goToPC = ->
  if $(".pane-editor").css("display") == "none"
    @webui.MemView.scrollTo(@emulator.registers.PC)
  else
    if not @assembled? then return
    lineNumber = @assembled.memToClosestLine(@emulator.registers.PC)
    if lineNumber?
      positionHighlight(lineNumber)
      scrollToLine(lineNumber)

@editPC = ->
  @fetchInput $("#regPC"), (v) => @emulator.registers.PC = v

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
  # FIXME: if @emulator.onFire then: show cool fire image.
  updateHighlight(options?.scroll)
  webui.MemView.update()
  webui.CodeViewSet.updateAll()
  updateRegisters()
  @screen.update(@emulator.memory)

@resized = ->
  # lame html/css makes us recompute the size of the scrollable region for hand-holding purposes.
  padding = $(".navbar").height() + 10
  $(".navbar-spacer").height(padding)
  $("#body").height($(window).height() - padding)
  $(".pane-editor").height($(window).height() - $(".pane-editor").offset().top - webui.LogPane.height())
  $("#pane-memory").height(32 * 20 + 7)
  # compensate for extra ceremonial baggage chrome puts around a textarea
  $(".code-textarea").outerWidth($(".code-box").width())
  @updateViews()

@codeEdited = ->
  if @typingTimer? then clearTimeout(@typingTimer)
  @typingTimer = setTimeout(@codeChanged, @typingDelay)

@codeChanged = ->
  @typingTimer = null
  @emulator.reset()
  @screen.reset()
  assemble()

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
  setTimeout((=> webui.CodeViewSet.assemble()), 0)
  @updateViews(scroll: true)

Key = carrot16.Key

# return false to abort default handling of the event.
$(document).keydown (event) =>
  if @input?
    # weird chrome bug.
    if event.which == 8
      @input.count += 1
      if @input.count > 4 then @input.count = 4
      @input.element.html(@input.element.html().slice(0, -1))
      @input.callback(parseInt(@input.element.html(), 16))
      @updateViews()
      return false
    return true
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
  if not @runTimer? then return true
  @keyboard.keydown(event.which)

$(document).keypress (event) =>
  if @input?
    if (event.which in [0x30...0x3a]) or (event.which in [0x41...0x47]) or (event.which in [0x61...0x67])
      if @input.element.html() == "----" then @input.element.html("")
      @input.element.html(@input.element.html() + String.fromCharCode(event.which))
      @input.count -= 1
    else if (event.which == 13) or (event.which == 10)
      @input.count = 0
    @input.callback(parseInt(@input.element.html(), 16))
    if @input.count == 0 then @cancelInput()
    @updateViews()
    return false
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
  if not @runTimer? then return true
  @keyboard.keypress(event.which)

$(document).keyup (event) =>
  if @input? then return true
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

  # click on a register to view it in the memory dump (or listing, for PC)
  $("#PC").click(=> goToPC())
  $("#regPC").click(=> @fetchInput $("#regPC"), (v) => @emulator.registers.PC = v)
  $("#SP").click(=> webui.MemView.scrollTo(emulator.registers.SP))
  $("#regSP").click(=> @fetchInput $("#regSP"), (v) => @emulator.registers.SP = v)
  $("#IA").click(=> webui.MemView.scrollTo(emulator.registers.IA))
  $("#regIA").click(=> @fetchInput $("#regIA"), (v) => @emulator.registers.IA = v)
  $("#A").click(=> webui.MemView.scrollTo(emulator.registers.A))
  $("#regA").click(=> @fetchInput $("#regA"), (v) => @emulator.registers.A = v)
  $("#B").click(=> webui.MemView.scrollTo(emulator.registers.B))
  $("#regB").click(=> @fetchInput $("#regB"), (v) => @emulator.registers.B = v)
  $("#C").click(=> webui.MemView.scrollTo(emulator.registers.C))
  $("#regC").click(=> @fetchInput $("#regC"), (v) => @emulator.registers.C = v)
  $("#X").click(=> webui.MemView.scrollTo(emulator.registers.X))
  $("#regX").click(=> @fetchInput $("#regX"), (v) => @emulator.registers.X = v)
  $("#Y").click(=> webui.MemView.scrollTo(emulator.registers.Y))
  $("#regY").click(=> @fetchInput $("#regY"), (v) => @emulator.registers.Y = v)
  $("#Z").click(=> webui.MemView.scrollTo(emulator.registers.Z))
  $("#regZ").click(=> @fetchInput $("#regZ"), (v) => @emulator.registers.Z = v)
  $("#I").click(=> webui.MemView.scrollTo(emulator.registers.I))
  $("#regI").click(=> @fetchInput $("#regI"), (v) => @emulator.registers.I = v)
  $("#J").click(=> webui.MemView.scrollTo(emulator.registers.J))
  $("#regJ").click(=> @fetchInput $("#regJ"), (v) => @emulator.registers.J = v)
  $("#EX").click(=> webui.MemView.scrollTo(emulator.registers.EX))
  $("#regEX").click(=> @fetchInput $("#regEX"), (v) => @emulator.registers.EX = v)

  webui.Tabs.init()

  reset()
  $(window).resize (event) -> resized()
  resized()



#  window.localStorage.setItem("robey", "hello")
# window.localStorage.getItem("robey")

