
class CodeView
  typingDelay: 250
  typingTimer: null

  constructor: ->
    @name = CodeViewSet.nextName()
    @tabName = "tab-#{@name}"
    @pane = $("#codeview-prototype").clone()
    @pane.attr("id", @name)
    @pane.data "redraw", => @update()
    @tab = $(".code-tab-prototype").clone()
    @tab.attr("id", @tabName)
    $(".nav").data("robey", @tab)
    $(".nav").append(@tab)
    $("#left_panel").append(@pane)
    webui.Tabs.connect @tab, @pane
    CodeViewSet.views.push(@)
    @textarea = $("##{@name} .code-textarea")
    @textarea.bind "oninput", => @codeEdited()
    @textarea.bind "onchange", => @codeChanged()
    @linenums = $("##{@name} .code-linenums")
    @codebox = $("##{@name} .code-box")
    @pcline = $("##{@name} .code-pc-line")

  setName: (name) ->
    $("##{@tabName} a").text(name)

  setCode: (text) ->
    @textarea.empty()
    @textarea.val(text)
    @codeChanged()

  getCode: -> @textarea.val().split("\n")

  activate: -> webui.Tabs.activate(@tab)

  visible: -> @pane.css("display") != "none"

  codeChanged: ->
    @typingTimer = null
    reset()

  codeEdited: ->
    if @typingTimer? then clearTimeout(@typingTimer)
    @typingTimer = setTimeout(@codeChanged, @typingDelay)

  # rebuild line number column, and resize textarea if necessary.
  update: ->
    console.log "redraw!"
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
    @textarea.outerWidth(@codebox.width())
    @pane.height($(window).height() - @pane.offset().top - webui.LogPane.height())
    @updatePcHighlight()

  updatePcHighlight: ->
    n = assembled?.memToLine(emulator.registers.PC)
    if n?
      @pcline.css("top", (n * @pcline.height()) + 5)
      @pcline.css("display", "block")
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
    if lineTop < top + lineHeight
      @pane.scrollTop(if n == 0 then 0 else (n - 1) * lineHeight)
    else if lineTop > bottom - (3 * lineHeight)
      @pane.scrollTop((n + 3 - visibleLines) * lineHeight)


CodeViewSet =
  id: 1
  views: []

  init: ->
    $("#master-codeview").css("display", "none")

  nextName: ->
    rv = "codeview-#{@id}"
    @id += 1
    rv

  resizeAll: ->
    for v in @views then v.resize()

  assemble: ->
    webui.LogPane.clear()
    emulator.clearMemory()
  #   for view in views




  # logger = (lineno, pos, message) =>
  #   span = $("<span />")
  #   span.addClass("line")
  #   span.addClass("pointer")
  #   span.text(sprintf("%5d", lineno + 1))
  #   line = $("<span />")
  #   line.append(span)
  #   line.append(": " + message)
  #   webui.LogPane.log(line)
  #   $("#ln#{lineno}").css("background-color", "#f88")
  # asm = new d16bunny.Assembler(logger)
  # @assembled = asm.compile(lines)

  # if @assembled.errorCount == 0
  #   buffer = @assembled.createImage(@emulator.memory.memory)
  #   # turn off breakpoints that aren't code anymore.
  #   for line, isSet of @breakpoints #when isSet
  #     @setBreakpoint(line, isSet)

  # # update UI
  # buildDump()
  # matchHeight($(".code-textarea"), $(".code-linenums"))
  # @resized()



exports.CodeView = CodeView
exports.CodeViewSet = CodeViewSet
