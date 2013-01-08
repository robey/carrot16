
@emulator = new bunnyemu.Emulator()
@breakpoints = {}
@assembled = null
@scrollTop = []

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
  if not line? then return
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
#  Screen.resetFont(memory)

  logger = (lineno, pos, message) ->
    $("#log").css("display", "block")
    $("#log").append("<span class='line'>#{pad(lineno + 1, 5)}:</span> #{message}<br/>")
    $("#ln#{lineno}").css("background-color", "#f88")
  asm = new d16bunny.Assembler(logger)
  @assembled = asm.compile(lines)

  if @assembled.errorCount == 0
    @assembled.createImage(@emulator.memory)
    # turn off breakpoints that aren't code anymore.
    for line, isSet of @breakpoints #when isSet
      @setBreakpoint(line, isSet)

  # update UI
  buildDump()
  matchHeight($("#code"), $("#linenums"))


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
  updateHighlight(options.scroll)
#  updateMemoryView();
#  updateRegisters();
#  Screen.update(memory);
#  document.getElementById("cycles").innerHTML = cycles;
#  resizeTabs();

@resized = ->
  # lame html/css makes us recompute the size of the scrollable region for hand-holding purposes.
  $("#tab0_content").height($(window).height() - $("#tab0_content").position().top)
  $("#tab1_content").height($(window).height() - $("#tab1_content").position().top)
  $("#tab2_content").height(32 * 20 + 7)

@codeEdited = ->
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

@step = ->
  @emulator.step()
  @updateViews(scroll: true)

@reset = ->
  @emulator.reset()

  # keypointer = 0;
  # Screen.MAP_SCREEN = 0x8000; // for backward compatability... will be reset to 0 in future
  # Screen.MAP_FONT = 0x8180;
  # Screen.MAP_PALETTE = 0;
  # Screen.BORDER_COLOR = 0;
  assemble()
  updateHighlight(true)

$(document).ready ->
  reset()
  $(window).resize (event) -> resized()
  resized()

# ensure the monitor boot-screen displays for no longer than 1 second.
setTimeout((-> $("#loading_overlay").css("display", "none")), 1000)


#  window.localStorage.setItem("robey", "hello")
# window.localStorage.getItem("robey")


