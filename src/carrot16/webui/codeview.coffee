
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
  # FIXME: profiling reveals that this takes way longer than actually assembling. :(
  buildDump: ->
    x1 = Date.now()
    @div.listing.find("div").remove()
    x2 = Date.now()
    @updatePcHighlight()
    if not @assembled? then return
    # wrap in extra divs so empty() doesn't take forever.
    outer = $("<div/>")
    outer.css("height", "100%")
    @div.listing.append(outer)
    x3 = Date.now()
    for info in @assembled.lines
      div = $("<div/>")
      if info.data.length > 0
        addr = info.org
        span = $("<span />")
        span.text(sprintf("%04x", addr))
        span.addClass("pointer")
        do (addr) =>
          span.click(=> webui.MemView.scrollTo(addr))
        div.append(span)
        div.append(": ")
        div.append((for x in info.data then sprintf("%04x", x)).join(" "))
      outer.append(div)
    x4 = Date.now()
    console.log("fuck: #{x2 - x1}, #{x3 - x2}, #{x4 - x3}")

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
