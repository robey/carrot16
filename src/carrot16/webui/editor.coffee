
#
# todo:
# - syntax highlighting
# - copy / paste
# - C-y
# - when going up/down, remember "virtual x" on short lines
# - shift click select
#

Array.prototype.insert = (n, x) -> @splice(n, 0, x)

class Editor
  # cursor blink rate (msec)
  CURSOR_RATE: 500

  # rate at which scrolling should happen when the mouse button is held past the edge of the editor (msec)
  AUTO_SCROLL_RATE: 100

  DOUBLE_CLICK_RATE: 200

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
    @undoBuffer = []
    @redoBuffer = []
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
    @div.text.mousedown (event) => @mouseDownEvent(event)
    @div.text.mouseup (event) => @mouseUpEvent(event)
    @div.text.keypress (event) =>
      if event.which >= 0x20 and event.which <= 0x7e then (@insertChar(event.which); false)
    # new-style key bindings
    @div.text.bind "keydown", "up", => (@up(); false)
    @div.text.bind "keydown", "shift+up", => (@moveSelection(@SELECTION_LEFT, => @moveUp()); false)
    @div.text.bind "keydown", "down", => (@down(); false)
    @div.text.bind "keydown", "shift+down", => (@moveSelection(@SELECTION_RIGHT, => @moveDown()); false)
    @div.text.bind "keydown", "left", => (@left(); false)
    @div.text.bind "keydown", "shift+left", => (@moveSelection(@SELECTION_LEFT, => @moveLeft()); false)
    @div.text.bind "keydown", "right", => (@right(); false)
    @div.text.bind "keydown", "shift+right", => (@moveSelection(@SELECTION_RIGHT, => @moveRight()); false)
    @div.text.bind "keydown", "pageup", => (@pageUp(); false)
    @div.text.bind "keydown", "shift+pageup", => (@moveSelection(@SELECTION_LEFT, => @movePageUp()); false)
    @div.text.bind "keydown", "pagedown", => (@pageDown(); false)
    @div.text.bind "keydown", "shift+pagedown", => (@moveSelection(@SELECTION_RIGHT, => @movePageDown()); false)
    @div.text.bind "keydown", "backspace", => (@backspace(); false)
    @div.text.bind "keydown", "del", => (@deleteForward(); false)
    @div.text.bind "keydown", "space", => (@insertChar(32); false)
    @div.text.bind "keydown", "return", => (@enter(); false)
    @div.text.bind "keydown", "meta+z", => (@undo(); false)
    @div.text.bind "keydown", "meta+shift+z", => (@redo(); false)
    # hello emacs users!
    @div.text.bind "keydown", "ctrl+a", => (@home(); false)
    @div.text.bind "keydown", "ctrl+b", => (@left(); false)
    @div.text.bind "keydown", "ctrl+d", => (@deleteForward(); false)
    @div.text.bind "keydown", "ctrl+e", => (@end(); false)
    @div.text.bind "keydown", "ctrl+f", => (@right(); false)
    @div.text.bind "keydown", "ctrl+h", => (@backspace(); false)
    @div.text.bind "keydown", "ctrl+k", => (@deleteToEol(); false)
    @div.text.bind "keydown", "ctrl+l", => (@centerLine(); false)
    @div.text.bind "keydown", "ctrl+n", => (@down(); false)
    @div.text.bind "keydown", "ctrl+p", => (@up(); false)
    @div.text.bind "keydown", "ctrl+z", => (@undo(); false)
    @div.text.bind "keydown", "ctrl+shift+z", => (@redo(); false)
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
    @div.lines = []
    @lines = []
    @undoBuffer = []
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

  setCursor: (x, y) ->
    if x? then @cursorX = x
    if y? then @cursorY = y
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
    if @lastMouseUp? and (not event.shiftKey) and Date.now() - @lastMouseUp < @DOUBLE_CLICK_RATE
      @cancelSelection()
      @lastMouseUpClicks += 1
      if @lastMouseUpClicks == 3
        @selectLine()
        @lastMouseUpClicks = 1
      else
        @selectWord()
      @lastMouseUp = Date.now()
      return false
    @lastMouseUp = Date.now()
    @lastMouseUpClicks = 1
    if not @selection? then return
    @div.text.unbind("mousemove")
    @div.text.unbind("mouseout")
    @div.text.unbind("mouseover")
    clearTimeout(@autoScrollTimer)
    @autoScrollTimer = null
    @addSelection(x, y)
    if @selection? and @selection[0].y == @selection[1].y and @selection[0].x == @selection[1].x
      @cancelSelection()
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

  movePageUp: ->
    @cursorY -= @windowLines
    if @cursorY < 0 then @cursorY = 0
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @centerLine()
    @setCursor()

  movePageDown: ->
    @cursorY += @windowLines
    if @cursorY > @lines.length - 1 then @cursorY = @lines.length - 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @centerLine()
    @setCursor()

  # ----- operations on the text

  # remove characters from a line
  deleteText: (x, y, count) ->
    @lines[y] = @lines[y][0...x] + @lines[y][x + count ...]
    @refreshLine(y)

  # merge line with the line below it.
  mergeLines: (y) ->
    @lines[y] = @lines[y] + @lines[y + 1]
    @refreshLine(y)
    @deleteLine(y + 1)

  insertTextSegment: (x, y, text) ->
    @lines[y] = @lines[y][0...x] + text + @lines[y][x...]
    @refreshLine(y)
    [ x + text.length, y ]

  insertText: (x, y, text) ->
    lines = text.split("\n")
    for line in lines[...-1]
      [ x, y ] = @insertTextSegment(x, y, line)
      [ x, y ] = @insertLF(x, y)
    @insertTextSegment(x, y, lines[lines.length - 1])

  insertLF: (x, y) ->
    @lines.insert(y + 1, @lines[y][x...])
    @lines[y] = @lines[y][0...x]
    div = @newLine(@lines[y + 1])
    @div.lines.insert(y + 1, div)
    @div.text.append(div)
    div.insertAfter(@div.lines[y])
    @refreshLine(y)
    @refreshLine(y + 1)
    @fixHeights()
    [ 0, y + 1 ]

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
    @cancelSelection()
    @movePageUp()

  pageDown: ->
    @cancelSelection()
    @movePageDown()

  deleteForward: ->
    if @selection?
      @deleteSelection()
      return
    if @cursorX < @lines[@cursorY].length
      @addUndo(Undo.INSERT, @cursorX, @cursorY, @lines[@cursorY][@cursorX], @cursorX, @cursorY)
      @deleteText(@cursorX, @cursorY, 1)
    else if @cursorY < @lines.length - 1
      @addUndo(Undo.INSERT, @cursorX, @cursorY, "\n", @cursorX, @cursorY)
      @mergeLines(@cursorY)

  backspace: ->
    if @selection?
      @deleteSelection()
      return
    if @cursorX > 0
      @addUndo(Undo.INSERT, @cursorX - 1, @cursorY, @lines[@cursorY][@cursorX - 1], @cursorX, @cursorY)
      @deleteText(@cursorX - 1, @cursorY, 1)
      @moveLeft()
    else if @cursorY > 0
      @setCursor(@lines[@cursorY - 1].length, @cursorY - 1)
      @addUndo(Undo.INSERT, @cursorX, @cursorY, "\n", 0, @cursorY + 1)
      @mergeLines(@cursorY)

  deleteToEol: ->
    # FIXME: add to clipboard
    @addUndo(Undo.INSERT, @cursorX, @cursorY, @lines[@cursorY][@cursorX ...], @cursorX, @cursorY)
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX]
    @refreshLine(@cursorY)

  centerLine: ->
    topLine = Math.max(@cursorY - Math.floor((@windowLines - 1) / 2), 0)
    @element.scrollTop(topLine * @lineHeight)

  insertChar: (c) ->
    @insert(String.fromCharCode(c))

  insert: (text) ->
    if @selection? then @deleteSelection()
    [ x, y ] = @insertText(@cursorX, @cursorY, text)
    @addUndo(Undo.DELETE, @cursorX, @cursorY, text, x, y)
    @setCursor(x, y)

  enter: ->
    @addUndo(Undo.MERGE, @cursorX, @cursorY)
    [ x, y ] = @insertLF(@cursorX, @cursorY)
    @setCursor(x, y)

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

  deleteSelection: ->
    [ x0, y0, x1, y1 ] = [ @selection[0].x, @selection[0].y, @selection[1].x, @selection[1].y ]
    if y0 == y1
      # within one line
      @addUndo(Undo.INSERT_SELECT, x0, y0, @lines[y0][x0...x1], x1, y0)
      @deleteText(x0, y0, x1 - x0)
    else
      # multi-line
      buffer = [ @lines[y0][x0...] ].concat (for y in [y0 + 1 ... y1] then @lines[y]), [ @lines[y1][...x1] ]
      @addUndo(Undo.INSERT_SELECT, x0, y0, buffer.join("\n"), x1, y1)
      @lines[y0] = @lines[y0][0 ... @selection[0].x] + @lines[y1][@selection[1].x ...]
      for y in [y0 + 1 .. y1] then @deleteLine(y0 + 1)
    @setCursor(x0, y0)
    @selection = null
    @refreshLine(y0)

  moveSelection: (direction, movement) ->
    @startSelection(direction, @cursorX, @cursorY)
    movement()
    @addSelection(@cursorX, @cursorY)

  selectWord: ->
    x1 = Math.max(0, @cursorX - 1)
    x2 = x1
    while x1 > 0 and @lines[@cursorY][x1].match(/\w/)? then x1 -= 1
    while x2 < @lines[@cursorY].length and x2 > 0 and @lines[@cursorY][x2].match(/\w/)? then x2 += 1
    if x2 > x1
      @startSelection(@SELECTION_RIGHT, x1 + 1, @cursorY)
      @addSelection(x2, @cursorY)
      @setCursor(x2, @cursorY)
    else if @lines[@cursorY][x1] != " "
      @startSelection(@SELECTION_RIGHT, x1, @cursorY)
      @addSelection(x1 + 1, @cursorY)
      @setCursor(x1 + 1, @cursorY)

  selectLine: ->
    if @lines[@cursorY].length == 0 then return
    @startSelection(@SELECTION_RIGHT, 0, @cursorY)
    if @cursorY + 1 < @lines.length
      @addSelection(0, @cursorY + 1)
      @setCursor(0, @cursorY + 1)
    else
      @addSelection(@lines[@cursorY].length, @cursorY)
      @setCursor(@lines[@cursorY].length, @cursorY)

  # ----- undo

  MAX_UNDO: 100
  UNDO_COMPACTION_RATE: 1000

  class Undo
    @INSERT = 1
    @INSERT_SELECT = 2
    @DELETE = 3
    @MERGE = 4 # FIXME

    constructor: (@action, @x, @y, @text, @nextX, @nextY) ->
      @when = Date.now()

    combine: (other) ->
      new Undo(@action, @x, @y, @text + other.text, other.nextX, other.nextY)

  addUndo: (action, x, y, text, nextX, nextY) ->
    @redoBuffer = []
    @undoBuffer.push(new Undo(action, x, y, text, nextX, nextY))
    while @undoBuffer.length > @MAX_UNDO then @undoBuffer.shift()
    # compact?
    if @undoBuffer.length < 2 then return
    u2 = @undoBuffer[@undoBuffer.length - 2]
    u1 = @undoBuffer[@undoBuffer.length - 1]
    if u1.action != u2.action or u1.when - u2.when >= @UNDO_COMPACTION_RATE then return
    if u1.action == Undo.DELETE and u1.x == u2.nextX and u1.y == u2.nextY
      @undoBuffer.pop()
      @undoBuffer.pop()
      @undoBuffer.push(u2.combine(u1))
    else if u1.action == Undo.INSERT and u1.nextX == u2.x and u1.nextY == u2.y
      @undoBuffer.pop()
      @undoBuffer.pop()
      @undoBuffer.push(u1.combine(u2))

  undo: ->
    @cancelSelection()
    item = @undoBuffer.pop()
    if not item? then return
    # FIXME: redo?
    @redoBuffer.push(item)
    switch item.action
      when Undo.INSERT, Undo.INSERT_SELECT
        @insertText(item.x, item.y, item.text)
        @setCursor(item.nextX, item.nextY)
        if item.action == Undo.INSERT_SELECT
          @startSelection(@SELECTION_RIGHT, item.x, item.y)
          @addSelection(item.nextX, item.nextY)
      when Undo.DELETE
        @deleteText(item.x, item.y, item.text.length)
        @setCursor(item.x, item.y)
      when Undo.MERGE
        @mergeLines(item.y)
        @setCursor(item.x, item.y)

  redo: ->
    @cancelSelection()
    item = @redoBuffer.pop()
    if not item? then return
    @undoBuffer.push(item)
    switch item.action
      when Undo.INSERT, Undo.INSERT_SELECT
        @deleteText(item.x, item.y, item.text.length)
        @setCursor(item.x, item.y)
      when Undo.DELETE
        @insertText(item.x, item.y, item.text)
        @setCursor(item.nextX, item.nextY)
      when Undo.MERGE
        [ x, y ] = @insertLF(item.x, item.y)
        @setCursor(x, y)


#exports.Editor = Editor


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

