
Key = carrot16.Key

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
    $(".nav").append(@tab)
    $("#left_panel").append(@pane)
    webui.Tabs.connect @tab, @pane
    CodeViewSet.add(@)
    @editor = new webui.Editor($("##{@name} .editor"))
    @editor.updateCallback = (=> @codeChanged())
    @div =
      listing: $("##{@name} .editor-listing")
      pcline: $("##{@name} .code-pc-line")
    @assembled = null
    @breakpoints = {}

  setName: (name) ->
    $("##{@tabName} a").text(name)

  getName: -> $("##{@tabName} a").text()

  editName: ->
    # js makes this kinda ridiculously complex. :(
    edit = $("<input type=text />")
    oldName = @getName()
    edit.val(oldName)
    edit.css("width", "5em")
    edit.css("class", "navbar-form")
    $("##{@tabName} a").empty()
    edit.submit =>
      @setName(edit.val())
      edit.remove()
    edit.blur =>
      @setName(oldName)
      edit.remove()
    edit.keydown (event) =>
      if (event.which == 9) or (event.which == 27)
        edit.blur()
        return false
      if event.which == 13
        edit.submit()
        return false
    $("##{@tabName} a").append(edit)
    edit.focus()
    edit.select()

  setCode: (text) ->
    @editor.replaceText(text)
    @codeChanged()

  getCode: -> @editor.lines

  save: ->
    new window.Blob([ @textarea.val() ], type: "text/plain")

  activate: -> webui.Tabs.activate(@tab)

  visible: -> @pane.css("display") != "none"

  codeChanged: ->
    @update()
    CodeViewSet.assemble()

  # rebuild line number column, and resize textarea if necessary.
  update: ->
    @editor.foreachLine (i, text) =>
      @editor.onLineNumberClick i, => @toggleBreakpoint(i)
    @resize()

  resize: ->
    @pane.height($(window).height() - @pane.offset().top - webui.LogPane.height())
    @editor.setCursor()
    @updatePcHighlight()

  updatePcHighlight: (alsoScroll) ->
    n = @assembled?.memToLine(emulator.registers.PC)
    if n?
      @div.pcline.css("display", "block")
      @editor.moveDivToLine(@div.pcline, n)
      if alsoScroll
        if not @visible() then @activate()
        @scrollToLine(n)
    else
      @div.pcline.css("display", "none")

  scrollToLine: (n) ->
    if not @visible() then return
    @editor.scrollToLine(n)

  clearBreakpoints: ->
    @breakpoints = {}
    @editor.clearLineNumberMarks()
    @update()

  setBreakpoint: (linenum, isSet) ->
    if not @assembled?.lineToMem(linenum)? then isSet = false
    @breakpoints[linenum] = isSet
    @editor.setLineNumberMarked(linenum, isSet)

  toggleBreakpoint: (linenum) ->
    @setBreakpoint(linenum, not @breakpoints[linenum])

  atBreakpoint: ->
    @breakpoints[@assembled.memToLine(emulator.registers.PC)]

  highlightError: (y, x) ->
    @scrollToLine(y)
    line = @editor.getLine(y)
    [ x0, x1 ] = [ x, x ]
    while x1 < line.length and line[x1].match(/\w/)? then x1 += 1
    if x1 == x0 then x1 += 1
    @editor.setSelection(x0, y, x1, y)
    @editor.focus()

  logError: (y, x, message) ->
    linenum = $("<span />")
    linenum.addClass("line")
    linenum.addClass("pointer")
    linenum.text(sprintf("%5d", y + 1))
    linenum.click => @highlightError(y, x)
    line = $("<span />")
    line.append(linenum)
    line.append(": #{message}")
    webui.LogPane.log(line)
    @editor.setLineNumberError(y)

  assemble: ->
    @debug "start assembly of #{@getName()}"
    @editor.clearLineNumberErrors()
    startTime = Date.now()
    logger = (n, pos, message) => @logError(n, pos, message)
    asm = new d16bunny.Assembler(logger)
    @assembled = asm.compile(@getCode())
    if @assembled.errorCount > 0
      @assembled = null
    else
      # kinda cheat by poking directly into memory.
      @assembled.createImage(emulator.memory.memory)
      # turn off breakpoints that aren't code anymore.
      for line, isSet of @breakpoints #when isSet
        @setBreakpoint(line, isSet)
    @debug "finished assembly of #{@getName()} in #{Date.now() - startTime} msec"
    @buildDump()
    @debug "finished assembly & dump of #{@getName()} in #{Date.now() - startTime} msec"
    @assembled?

  # build up the dump panel (lines of "offset: words...")
  # for large code, this can take a long time and may block the UI thread, so
  # some care is taken to chop up the work.
  buildDump: ->
    startTime = Date.now()
    if @buildDumpTimer? then clearTimeout(@buildDumpTimer)
    @updatePcHighlight()
    if not @assembled?
      @div.listing.empty()
      return
    # wrap in an extra div so clearing it doesn't take forever.
    @div.listingWrapper = $("<div/>")
    @div.listingWrapper.css("height", "100%")
    @buildDumpTimer = setTimeout((=> @buildDumpContinue(0, startTime, Date.now() - startTime)), 10)

  buildDumpContinue: (n, originalStartTime, totalTime) ->
    @buildDumpTimer = null
    if not @assembled? then return
    startTime = Date.now()
    while n < @assembled.lines.length
      info = @assembled.lines[n]
      line = $("<div/>")
      if info.data.length > 0
        addr = info.org
        span = $("<span />")
        span.text(sprintf("%04x", addr))
        span.addClass("pointer")
        do (addr) =>
          span.click(=> webui.MemView.scrollTo(addr))
        line.append(span)
        line.append(": ")
        line.append((for x in info.data then sprintf("%04x", x)).join(" "))
      @div.listingWrapper.append(line)
      n += 1
      # consume only 25ms out of every 50ms
      elapsed = Date.now() - startTime
      if elapsed >= 25
        @buildDumpTimer = setTimeout((=> @buildDumpContinue(n, originalStartTime, totalTime + elapsed)), 25)
        return
    @div.listing.empty()
    @div.listing.append(@div.listingWrapper)
    @div.listingWrapper = null
    totalTime += elapsed
    wallTime = Date.now() - originalStartTime
    @debug "finished dump of #{@getName()} in #{totalTime} msec (across #{wallTime} msec)"

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

  add: (view) ->
    @views.push(view)

  remove: (view) ->
    @views = @views.filter (x) -> x isnt view


exports.CodeView = CodeView
exports.CodeViewSet = CodeViewSet
