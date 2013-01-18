
class CodeView
  typingDelay: 1000
  typingTimer: null

  constructor: ->
    @name = CodeViewSet.nextName()
    @tabName = "tab-#{@name}"
    @pane = $("#codeview-prototype").clone()
    @pane.attr("id", @name)
    @pane.data "redraw", => @update()
    @pane.data "codeview", @
    @tab = $("#code-tab-prototype").clone()
    @tab.css("display", "block")
    @tab.attr("id", @tabName)
    $(".nav").data("robey", @tab)
    $(".nav").append(@tab)
    $("#left_panel").append(@pane)
    webui.Tabs.connect @tab, @pane
    CodeViewSet.views.push(@)
    @textarea = $("##{@name} .code-textarea")
    @textarea.bind "input", => @codeEdited()
    @textarea.bind "change", => @codeChanged()
    @linenums = $("##{@name} .code-linenums")
    @codebox = $("##{@name} .code-box")
    @pcline = $("##{@name} .code-pc-line")
    @addrDiv = $("##{@name} .code-addr")
    @dumpDiv = $("##{@name} .code-dump")
    @assembled = null
    @breakpoints = {}
    Key = carrot16.Key
    @pane.data "keydown", (key) =>
      if key == Key.ENTER
        # many things about javascript and html/css are confounding to me,
        # but this one is the *most* confounding to me. we want to start the
        # assembler "as soon as" the user hits enter, so that the editor
        # seems fairly responsive. but we want chrome to update the UI (the
        # bits on the screen) so that the user sees the effect of hitting
        # enter.
        #
        # chrome will not update the screen unless we delay by some amount
        # of time. my testing showed that 0ms is not enough, and chrome will
        # refuse to update the screen unless we wait at least 10ms, sometimes
        # even 15ms. i have no idea why. i would love to know! please write
        # me and tell me why!
        #
        # in the meantime, i'm hoping that 50ms is sufficient for chrome to
        # always be satisfied that it's okay to update the screen, but fast
        # enough that the user perceives the assembler as starting up
        # "immediately".
        setTimeout((=> @codeChanged()), 50)

  setName: (name) ->
    $("##{@tabName} a").text(name)

  getName: -> $("##{@tabName} a").text()

  setCode: (text) ->
    @textarea.empty()
    @textarea.val(text)
    @codeChanged()

  getCode: -> @textarea.val().split("\n")

  save: ->
    new window.Blob([ @textarea.val() ], type: "text/plain")

  activate: -> webui.Tabs.activate(@tab)

  visible: -> @pane.css("display") != "none"

  codeChanged: ->
    if @typingTimer? then clearTimeout(@typingTimer)
    @typingTimer = null
    @update()
    CodeViewSet.assemble()

  codeEdited: ->
    if @typingTimer? then clearTimeout(@typingTimer)
    @typingTimer = setTimeout((=> @codeChanged()), @typingDelay)

  # rebuild line number column, and resize textarea if necessary.
  update: ->
    lines = @getCode()
    @linenums.empty()
    for i in [0 ... lines.length]
      span = $("<span />")
      span.text(i + 1)
      span.addClass("linenum")
      span.attr("id", "line#{i}-#{@name}")
      do (i) =>
        span.click => @toggleBreakpoint(i)
      @linenums.append(span)
    @textarea.css("height", @linenums.css("height"))
    @resize()

  resize: ->
    # compensate for extra ceremonial baggage chrome puts around a textarea.
    @textarea.outerWidth(@codebox.width())
    @pane.height($(window).height() - @pane.offset().top - webui.LogPane.height())
    @updatePcHighlight()

  updatePcHighlight: (alsoScroll) ->
    n = @assembled?.memToLine(emulator.registers.PC)
    if n?
      @pcline.css("top", (n * @pcline.height()) + 5)
      @pcline.css("display", "block")
      if alsoScroll
        if not @visible() then @activate()
        @scrollToLine(n)
    else
      @pcline.css("display", "none")

  scrollToLine: (n) ->
    if not @visible() then return
    line = $("#line#{n}-#{@name}")
    if not line?.offset()? then return
    lineTop = line.offset().top
    lineHeight = parseInt(@pane.css("line-height"))
    top = @pane.position().top
    bottom = Math.min(top + @pane.height(), webui.LogPane.top())
    visibleLines = Math.floor((bottom - top) / lineHeight)
    if lineTop < top + lineHeight or lineTop > bottom - (3 * lineHeight)
      @pane.scrollTop(if n < 2 then 0 else (n - 2) * lineHeight)

  clearBreakpoints: ->
    @breakpoints = {}
    @update()

  setBreakpoint: (linenum, isSet) ->
    if not @assembled?.lineToMem(linenum)? then isSet = false
    line = $("#line#{linenum}-#{@name}")
    @breakpoints[linenum] = isSet
    if isSet
      line.addClass("breakpoint")
    else
      line.removeClass("breakpoint")

  toggleBreakpoint: (linenum) ->
    @setBreakpoint(linenum, not @breakpoints[linenum])

  atBreakpoint: ->
    @breakpoints[@assembled.memToLine(emulator.registers.PC)]

  logError: (n, message) ->
    linenum = $("<span />")
    linenum.addClass("line")
    linenum.addClass("pointer")
    linenum.text(sprintf("%5d", n + 1))
    linenum.click => @scrollToLine(n)
    line = $("<span />")
    line.append(linenum)
    line.append(": #{message}")
    webui.LogPane.log(line)
    $("#line#{n}-#{@name}").css("background-color", "#f88")

  assemble: ->
    @debug "assemble"
    logger = (n, pos, message) => @logError(n, message)
    asm = new d16bunny.Assembler(logger)
    @assembled = asm.compile(@getCode())
    if @assembled.errorCount > 0
      @assembled = null
      @buildDump()
      return false
    # kinda cheat by poking directly into memory.
    @assembled.createImage(emulator.memory.memory)
    # turn off breakpoints that aren't code anymore.
    for line, isSet of @breakpoints #when isSet
      @setBreakpoint(line, isSet)
    @buildDump()
    true

  # build up the dump panel (lines of "offset: words...")
  buildDump: ->
    @addrDiv.empty()
    @dumpDiv.empty()
    @updatePcHighlight()
    if not @assembled? then return
    for info in @assembled.lines
      if info.data.length > 0
        addr = info.org
        span = $("<span />")
        span.text(sprintf("%04x:", addr))
        span.addClass("pointer")
        do (addr) =>
          span.click(=> webui.MemView.scrollTo(addr))
        @addrDiv.append(span)
        @dumpDiv.append((for x in info.data then sprintf("%04x", x)).join(" "))
      @addrDiv.append("<br/>")
      @dumpDiv.append("<br/>")

  debug: (message) ->
    console.log "[#{@name}] #{message}"


CodeViewSet =
  id: 1
  views: []

  visible: ->
    webui.Tabs.activePane?.data("codeview")?
    
  init: ->
    $("#master-codeview").css("display", "none")

  nextName: ->
    rv = "codeview-#{@id}"
    @id += 1
    rv

  resizeAll: ->
    for v in @views then v.resize()

  updatePcHighlight: (scroll) ->
    for v in @views
      v.updatePcHighlight(scroll)

  assemble: ->
    webui.LogPane.clear()
    emulator.clearMemory()

    for view in @views
      if not view.assemble()
        # go to the error.
        view.activate()
        return false
    true

  atBreakpoint: ->
    for v in @views then if v.atBreakpoint() then return true
    false


exports.CodeView = CodeView
exports.CodeViewSet = CodeViewSet
