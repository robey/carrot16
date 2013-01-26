
#
# todo:
# - undo
# - syntax highlighting
# - double-click select
# - triple-click select
# - copy / paste
#

Array.prototype.insert = (n, x) -> @splice(n, 0, x)

class Editor
  # cursor blink rate (msec)
  CURSOR_RATE: 500

  # rate at which scrolling should happen when the mouse button is held past the edge of the editor (msec)
  AUTO_SCROLL_RATE: 100

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
    @selection = null
    @selectionIndex = 0
    setTimeout((=> @init()), 1)

  init: ->
    @calculateEm()
    @lineHeight = parseInt(@element.css("line-height"))
    @windowLines = Math.floor(@element.height() / @lineHeight)
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
    @div.text.click (event) => @moveCursorByMouse(event)
    @div.text.mousedown (event) => @mouseDownEvent(event)
    @div.text.mouseup (event) => @mouseUpEvent(event)
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
    if n < 0 or n >= @lines.length then return
    @div.lines[n].empty()
    @div.lines[n].text(@lines[n])
    # check for selection
    if @selection? and n >= @selection[0].y and n <= @selection[1].y
      x0 = if n > @selection[0].y then 0 else @selection[0].x
      x1 = if n < @selection[1].y then @lines[n].length else @selection[1].x
      box = $("<div />")
      box.addClass("editor-selection")
      @div.lines[n].append(box)
      box.css("left", x0 * @em)
      box.css("width", (x1 - x0) * @em)

  deleteLine: (n) ->
    @lines[n..n] = []
    div = @div.lines[n]
    @div.lines[n..n] = []
    div.remove()
    @fixHeights()

  # ----- cursor

  moveCursor: ->
    @div.cursor.css("top", @cursorY * @lineHeight + 1)
    @div.cursor.css("left", @cursorX * @em - 1 + 3)
    @div.cursorHighlight.css("top", @cursorY * @lineHeight + 2)
    @div.cursor.css("display", "block")

  setCursor: ->
    @moveCursor()
    # is the cursor off-screen? :(
    windowTop = @element.scrollTop()
    windowBottom = windowTop + @element.height()
    cursorTop = @cursorY * @lineHeight
    cursorBottom = cursorTop + @lineHeight
    if cursorTop < windowTop
      @element.scrollTop(Math.max(0, cursorTop - @lineHeight))
    else if cursorBottom > windowBottom
      @element.scrollTop(cursorTop - @lineHeight * (@windowLines - 1))

  stopCursor: ->
    if @cursorTimer? then clearInterval(@cursorTimer)
    @div.cursor.css("display", "none")

  startCursor: ->
    @stopCursor()
    @cursorTimer = setInterval((=> @blinkCursor()), @CURSOR_RATE)

  blinkCursor: ->
    @div.cursor.css("display", if @div.cursor.css("display") == "none" then "block" else "none")

  mouseToPosition: (event) ->
    offset = @div.text.offset()
    x = Math.round((event.pageX - offset.left) / @em - 0.3)
    y = Math.floor((event.pageY - offset.top) / @lineHeight)
    if y >= @lines.length then y = @lines.length - 1
    if y < 0 then y = 0
    if x > @lines[y].length then x = @lines[y].length
    [ x, y ]

  mouseDownEvent: (event) ->
    [ x, y ] = @mouseToPosition(event)
    if event.shiftKey
      @addSelection(x, y)
    else
      @cancelSelection()
      @startSelection(@SELECTION_RIGHT, x, y)
    @div.text.mousemove (event) => @mouseMoveEvent(event)
    @div.text.mouseout (event) => @mouseOutEvent(event)
    @div.text.mouseover (event) => @mouseOverEvent(event)
    $(window).mouseup (event) => @cancelSelection()
    false

  mouseUpEvent: (event) ->
    [ x, y ] = @mouseToPosition(event)
    [ @cursorX, @cursorY ] = [ x, y ]
    @setCursor()
    if not @selection? then return
    @div.text.unbind("mousemove")
    @div.text.unbind("mouseout")
    @div.text.unbind("mouseover")
    clearTimeout(@autoScrollTimer)
    @autoScrollTimer = null
    @addSelection(x, y)
    false

  mouseMoveEvent: (event) ->
    [ x, y ] = @mouseToPosition(event)
    [ @cursorX, @cursorY ] = [ x, y ]
    if @selection? then @addSelection(x, y)
    @moveCursor()

  mouseOutEvent: (event) =>
    # weird chrome bug makes it send us a blur for moving between lines.
    if event.toElement.parentElement is @div.text[0] then return
    [ x, y ] = @mouseToPosition(event)
    [ @cursorX, @cursorY ] = [ x, y ]
    @setCursor()
    @addSelection(x, y)
    # okay, so we want to slowly scroll the text area to let the user keep selecting.
    if @autoScrollTimer? then return
    if event.pageY <= @element.offset().top
      @autoScrollTimer = setInterval((=> @autoScroll(-1)), @AUTO_SCROLL_RATE)
    else if event.pageY >= @element.offset().top + @element.height() - 2
      @autoScrollTimer = setInterval((=> @autoScroll(1)), @AUTO_SCROLL_RATE)
    else
      @cancelSelection()

  mouseOverEvent: (event) =>
    # weird chrome bug makes it send us a blur for moving between lines.
    if event.fromElement.parentElement is @div.text[0] then return
    clearInterval(@autoScrollTimer)
    @autoScrollTimer = null

  autoScroll: (direction) =>
    if direction > 0 then @moveDown() else @moveUp()
    @addSelection(@cursorX, @cursorY)

  moveCursorByMouse: (event) ->
    [ @cursorX, @cursorY ] = @mouseToPosition(event)
    @cancelSelection()
    @setCursor()

  moveUp: ->
    if @cursorY > 0 then @cursorY -= 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  moveDown: ->
    if @cursorY < @lines.length - 1 then @cursorY += 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  moveLeft: ->
    if @cursorX > 0
      @cursorX -= 1
    else if @cursorY > 0
      @cursorY -= 1
      @cursorX = @lines[@cursorY].length
    @setCursor()

  moveRight: ->
    if @cursorX < @lines[@cursorY].length
      @cursorX += 1
    else if @cursorY < @lines.length - 1
      @cursorY += 1
      @cursorX = 0
    @setCursor()

  # ----- key bindings

  keydown: (event) ->
    switch event.which
      when Key.UP
        if event.shiftKey then @selectUp() else @up()
        false
      when Key.DOWN
        if event.shiftKey then @selectDown() else @down()
        false
      when Key.LEFT
        if event.shiftKey then @selectLeft() else @left()
        false
      when Key.RIGHT
        if event.shiftKey then @selectRight() else @right()
        false
      when Key.PAGE_UP
        @pageUp()
        false
      when Key.PAGE_DOWN
        @pageDown()
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
        @home()
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
      when CTRL_H
        @backspace()
        false
      when CTRL_K
        @deleteToEol()
        false
      when CTRL_L
        @centerLine()
        false
      when CTRL_N
        @down()
        false
      when CTRL_P
        @up()
        false
      else
        if event.which >= 0x20 and event.which <= 0x7e
          @insert(event.which)
          false
        true

  # ----- actions

  left: ->
    @cancelSelection()
    @moveLeft()

  right: ->
    @cancelSelection()
    @moveRight()

  up: ->
    @cancelSelection()
    @moveUp()

  down: ->
    @cancelSelection()
    @moveDown()

  home: ->
    @cursorX = 0
    @setCursor()

  end: ->
    @cursorX = @lines[@cursorY].length
    @setCursor()

  pageUp: ->
    @cursorY -= @windowLines
    if @cursorY < 0 then @cursorY = 0
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  pageDown: ->
    @cursorY += @windowLines
    if @cursorY > @lines.length - 1 then @cursorY = @lines.length - 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
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

  deleteToEol: ->
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX]
    @refreshLine(@cursorY)

  centerLine: ->
    topLine = Math.max(@cursorY - Math.floor((@windowLines - 1) / 2), 0)
    @element.scrollTop(topLine * @lineHeight)

  insert: (c) ->
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX] + String.fromCharCode(c) + @lines[@cursorY][@cursorX ...]
    @refreshLine(@cursorY)
    @right()

  enter: ->
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

  # ----- selection

  SELECTION_LEFT: 0
  SELECTION_RIGHT: 1

  # start a selection if one isn't already ongoing
  startSelection: (index, x, y) ->
    if @selection? then return
    @selection = [ { x: x, y: y }, { x: x, y: y } ]
    @selectionIndex = index

  cancelSelection: ->
    if not @selection? then return
    y0 = @selection[0].y
    y1 = @selection[1].y
    @selection = null
    for n in [y0..y1] then @refreshLine(n)
    @div.text.unbind("mousemove")
    @div.text.unbind("mouseout")
    @div.text.unbind("mouseover")
    clearInterval(@autoScrollTimer)
    @autoScrollTimer = null

  addSelection: (x, y) ->
    if not @selection?
      @cancelSelection()
      return
    oldx = @selection[@selectionIndex].x
    oldy = @selection[@selectionIndex].y
    @selection[@selectionIndex].x = x
    @selection[@selectionIndex].y = y
    # might need to reverse the order
    if @selection[1].y < @selection[0].y or (@selection[1].y == @selection[0].y and @selection[1].x < @selection[0].x)
      [ @selection[0], @selection[1] ] = [ @selection[1], @selection[0] ]
      @selectionIndex = 1 - @selectionIndex
    for n in [Math.min(@selection[0].y, oldy) .. Math.max(@selection[1].y, oldy)] then @refreshLine(n)

  selectUp: ->
    @startSelection(@SELECTION_LEFT, @cursorX, @cursorY)
    @moveUp()
    @addSelection(@cursorX, @cursorY)

  selectDown: ->
    @startSelection(@SELECTION_RIGHT, @cursorX, @cursorY)
    @moveDown()
    @addSelection(@cursorX, @cursorY)

  selectLeft: ->
    @startSelection(@SELECTION_LEFT, @cursorX, @cursorY)
    @moveLeft()
    @addSelection(@cursorX, @cursorY)

  selectRight: ->
    @startSelection(@SELECTION_RIGHT, @cursorX, @cursorY)
    @moveRight()
    @addSelection(@cursorX, @cursorY)

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
CTRL_G = 7
CTRL_H = 8
CTRL_I = 9
CTRL_J = 10
CTRL_K = 11
CTRL_L = 12
CTRL_M = 13
CTRL_N = 14
CTRL_O = 15
CTRL_P = 16

@text = """\
:start
  SET A, 8
  ADD X, A
  ; return
  RET
  a
  b
  c
  d
  e
  f
  g
  h
"""

$(document).ready =>
  @editor = new Editor($("#editor"))
  setTimeout((=> @editor.replaceText(@text)), 100)

