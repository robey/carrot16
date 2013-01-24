
#
# todo:
# - undo
# - syntax highlighting
#

Array.prototype.insert = (n, x) -> @splice(n, 0, x)

class Editor
  CURSOR_RATE: 500

  constructor: (@element) ->
    @div =
      textBackground: element.find(".editor-text-background")
      scroll: element.find(".editor-scroll")
      gutter: element.find(".editor-gutter")
      lineNumbers: []
      text: element.find(".editor-text")
      lines: []
      listing: element.find(".editor-listing")
      cursor: element.find(".editor-cursor")
      cursorHighlight: element.find(".editor-cursor-highlight")
    @lines = []
    setTimeout((=> @init()), 1)

  init: ->
    @calculateEm()
    @lineHeight = parseInt(@element.css("line-height"))
    @clear()
    # force line numbers to be 5-em wide.
    @div.gutter.css("width", 5 * @em + 20)
    # force listing to be 20-em wide.
    @div.listing.css("width", 22 * @em)
    # hook up keyboard control
    @div.text.focus => @startCursor()
    @div.text.blur => @stopCursor()
    @div.text.keydown (event) => @keydown(event)
    @div.text.keypress (event) => @keypress(event)
    @div.text.click (event) => @moveCursor(event)
    # start!
    @setCursor()
    @div.text.focus()

  # fix the heights of various elements to match the current text size
  fixHeights: ->
    # make background size match editor
    @div.textBackground.css("width", @div.text.width())
    @div.textBackground.css("height", @div.text.height())# - @div.text.position().top)
    @div.textBackground.css("top", 2)
    @div.textBackground.css("left", @div.text.position().left)
    # line numbers!
    if @div.lineNumbers.length < @lines.length
      for n in [@div.lineNumbers.length ... @lines.length]
        div = $("<div />")
        div.addClass("editor-linenumber")
        div.text(n + 1)
        @div.lineNumbers.push(div)
        @div.gutter.append(div)
    else if @div.lineNumbers.length > @lines.length
      for div in @div.lineNumbers[@lines.length ...] then div.remove()
      @div.lineNumbers[@lines.length ...] = []

  calculateEm: ->
    span = $("<span>0</span>")
    @div.gutter.append(span)
    @em = span.outerWidth(true)
    span.remove()

  clear: ->
    for line in @div.lines then line.remove()
    @div.lines = [ ]
    @lines = [ ]
    @cursorX = 0
    @cursorY = 0
    @fixHeights()

  replaceText: (text) ->
    @clear()
    for line in text.split("\n")
      @lines.push line
      div = @newLine(line)
      @div.lines.push div
      @div.text.append div
    @fixHeights()

  # ----- line manipulation

  # factor out the code to make new div lines
  newLine: (line) ->
    div = $("<div />")
    div.addClass("editor-line")
    div.text(line)
    div

  refreshLine: (n) ->
    @div.lines[n].text(@lines[n])

  deleteLine: (n) ->
    @lines[n..n] = []
    div = @div.lines[n]
    @div.lines[n..n] = []
    div.remove()
    @fixHeights()

  # -----

  setCursor: ->
    @div.cursor.css("top", @cursorY * @lineHeight + 1)
    @div.cursor.css("left", @cursorX * @em - 1 + 3)
    @div.cursorHighlight.css("top", @cursorY * @lineHeight + 2)
    @div.cursor.css("display", "block")
    # is the cursor off-screen? :(
    windowTop = @element.scrollTop()
    windowBottom = windowTop + @element.height()
    cursorTop = @cursorY * @lineHeight
    cursorBottom = cursorTop + @lineHeight
    windowLines = Math.floor((windowBottom - windowTop) / @lineHeight)
    if cursorTop < windowTop
      @element.scrollTop(Math.max(0, cursorTop - @lineHeight))
    else if cursorBottom > windowBottom
      @element.scrollTop(cursorTop - @lineHeight * (windowLines - 2))

  stopCursor: ->
    if @cursorTimer? then clearInterval(@cursorTimer)
    @div.cursor.css("display", "none")

  startCursor: ->
    @stopCursor()
    @cursorTimer = setInterval((=> @blinkCursor()), @CURSOR_RATE)

  blinkCursor: ->
    @div.cursor.css("display", if @div.cursor.css("display") == "none" then "block" else "none")

  moveCursor: (event) ->
    offset = @div.text.offset()
    x = Math.round((event.pageX - offset.left) / @em - 0.3)
    y = Math.floor((event.pageY - offset.top) / @lineHeight)
    if y >= @lines.length then y = @lines.length - 1
    if x > @lines[y].length then x = @lines[y].length
    @cursorY = y
    @cursorX = x
    @setCursor()

  keydown: (event) ->
    switch event.which
      when Key.UP
        @up()
        false
      when Key.DOWN
        @down()
        false
      when Key.LEFT
        @left()
        false
      when Key.RIGHT
        @right()
        false
      when Key.BACKSPACE
        @backspace()
        false
      when Key.DELETE
        @deleteForward()
        false
      when Key.SPACE
        # chrome bug.
        @insert(Key.SPACE)
        false
      when Key.ENTER
        @enter()
        false
      else
        true

  keypress: (event) ->
    switch event.which
      when CTRL_A
        @cursorX = 0
        @setCursor()
        false
      when CTRL_B
        @left()
        false
      when CTRL_D
        @deleteForward()
        false
      when CTRL_E
        @end()
        false
      when CTRL_F
        @right()
        false
      else
        if event.which >= 0x20 and event.which <= 0x7e
          @insert(event.which)
          false
        true

  # actions

  left: ->
    if @cursorX > 0
      @cursorX -= 1
    else if @cursorY > 0
      @cursorY -= 1
      @cursorX = @lines[@cursorY].length
    @setCursor()

  right: ->
    if @cursorX < @lines[@cursorY].length
      @cursorX += 1
    else if @cursorY < @lines.length - 1
      @cursorY += 1
      @cursorX = 0
    @setCursor()

  up: ->
    if @cursorY > 0 then @cursorY -= 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  down: ->
    if @cursorY < @lines.length - 1 then @cursorY += 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  end: ->
    @cursorX = @lines[@cursorY].length
    @setCursor()

  deleteForward: ->
    if @cursorX < @lines[@cursorY].length
      @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX] + @lines[@cursorY][@cursorX + 1 ...]
      @refreshLine(@cursorY)
    else if @cursorY < @lines.length - 1
      @lines[@cursorY] = @lines[@cursorY] + @lines[@cursorY + 1]
      @refreshLine(@cursorY)
      @deleteLine(@cursorY + 1)
    false

  backspace: ->
    if @cursorX > 0
      @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX - 1] + @lines[@cursorY][@cursorX ...]
      @refreshLine(@cursorY)
      @left()
    else if @cursorY > 0
      @cursorX = @lines[@cursorY - 1].length
      @lines[@cursorY - 1] = @lines[@cursorY - 1] + @lines[@cursorY]
      @refreshLine(@cursorY - 1)
      @deleteLine(@cursorY)
      @up()

  insert: (c) ->
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX] + String.fromCharCode(c) + @lines[@cursorY][@cursorX ...]
    @refreshLine(@cursorY)
    @right()

  enter: ->
    # coffeescript syntax for array insert is bizarre.
    @lines.insert(@cursorY + 1, @lines[@cursorY][@cursorX ...])
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX]
    div = @newLine(@lines[@cursorY + 1])
    @div.lines.insert(@cursorY + 1, div)
    @div.text.append(div)
    div.insertAfter(@div.lines[@cursorY])
    @refreshLine(@cursorY)
    @refreshLine(@cursorY + 1)
    @down()
    @cursorX = 0
    @setCursor()
    @fixHeights()

#exports.Editor = Editor


# lame, but chrome doesn't define these constants.
Key =
  BACKSPACE: 8
  TAB: 9
  ENTER: 13
  SHIFT: 16
  CONTROL: 17
  OPTION: 18
  ESCAPE: 27
  SPACE: 32
  PAGE_UP: 33
  PAGE_DOWN: 34
  END: 35
  HOME: 36
  LEFT: 37
  UP: 38
  RIGHT: 39
  DOWN: 40
  INSERT: 45
  DELETE: 46
  F1: 112
  F2: 113
  F3: 114
  F4: 115
  F5: 116
  F6: 117
  F7: 118
  F8: 119
  F9: 120
  F10: 121

CTRL_A = 1
CTRL_B = 2
CTRL_C = 3
CTRL_D = 4
CTRL_E = 5
CTRL_F = 6

@text = """\
:start
  SET A, 8
  ADD X, A
  ; return
  RET
"""

$(document).ready =>
  @editor = new Editor($("#editor"))
  setTimeout((=> @editor.replaceText(@text)), 100)

