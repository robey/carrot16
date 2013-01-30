
#
# todo:
# - syntax highlighting
#

Array.prototype.insert = (n, x) -> @splice(n, 0, x)

class Editor
  # cursor blink rate (msec)
  CURSOR_RATE: 500

  # rate at which scrolling should happen when the mouse button is held past the edge of the editor (msec)
  AUTO_SCROLL_RATE: 100

  # how fast you must click twice or thrice
  DOUBLE_CLICK_RATE: 250

  # width (in chars) of the line-numbers gutter
  GUTTER_WIDTH: 5

  # width (in chars) of the listing gutter
  LISTING_WIDTH: 27

  # wait this long for typing to stop before calling the update callback
  TYPING_RATE: 500

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
      cursorHighlight: element.find(".editor-highlight-line-cursor")
    # called when the contents have changed:
    #   - after a pause in typing (TYPING_RATE)
    #   - immediately on cut/paste, enter, or backspace/delete across lines
    @updateCallback = (-> true)
    @replaceText("")
    setTimeout((=> @init()), 1)

  init: ->
    @calculateEm()
    @lineHeight = parseInt(@element.css("line-height"))
    # force line numbers to be 5-em wide.
    @div.gutter.css("width", @GUTTER_WIDTH * @em + 20)
    # force listing to be 20-em wide.
    @div.listing.css("width", @LISTING_WIDTH * @em)
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
    @div.text.bind "keydown", "meta+up", => (@top(); false)
    @div.text.bind "keydown", "meta+down", => (@bottom(); false)
    @div.text.bind "keydown", "backspace", => (@backspace(); false)
    @div.text.bind "keydown", "del", => (@deleteForward(); false)
    @div.text.bind "keydown", "space", => (@insertChar(32); false)
    @div.text.bind "keydown", "return", => (@enter(); false)
    @div.text.bind "keydown", "meta+a", => (@selectAll(); false)
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
    # cut/copy/paste
    @div.text.bind "copy", (e) => @copySelection(e.originalEvent.clipboardData)
    @div.text.bind "cut", (e) => @cutSelection(e.originalEvent.clipboardData)
    @div.text.bind "paste", (e) => @paste(e.originalEvent.clipboardData)
    # start!
    @inited = true
    @fixHeights()
    @div.text.focus()

  windowLines: -> Math.floor(@element.height() / @lineHeight)

  # fix the heights of various elements to match the current text size
  fixHeights: ->
    if not @inited then return
    # make background size match editor
    @div.textBackground.css("width", @div.text.width())
    @div.textBackground.css("height", @div.text.innerHeight())# - @div.text.position().top)
    @div.textBackground.css("top", 0)
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

  # ----- external convenience API
  
  clear: ->
    for line in @div.lines then line.remove()
    @div.lines = []
    @lines = []
    @undoBuffer = []
    @redoBuffer = []
    @selection = null
    @selectionIndex = 0
    @cursorX = 0
    @cursorY = 0
    @virtualX = 0
    @fixHeights()

  replaceText: (text) ->
    @clear()
    if text[-1] != "\n" then text = text + "\n"
    for line in text.split("\n")
      @lines.push line
      div = @newLine(line)
      @div.lines.push div
      @div.text.append div
    @fixHeights()
    # chrome won't let us receive pastes unless we appear to have text
    # selected (?), so we always report a selection.
    selection = window.getSelection()
    selection.removeAllRanges()
    range = document.createRange()
    range.setStart(@div.lines[0][0], 0)
    range.setEnd(@div.lines[0][0], 0)
    selection.addRange(range)

  getLineNumberDiv: (n) ->
    @div.lineNumbers[n]

  onLineNumberClick: (n, f) ->
    @div.lineNumbers[n]?.unbind("click")
    @div.lineNumbers[n]?.bind("click", f)
    @div.lineNumbers[n]?.css("cursor", "pointer")

  setLineNumberMarked: (n, marked) ->
    if marked
      @div.lineNumbers[n]?.addClass("editor-linenumber-marked")
    else
      @div.lineNumbers[n]?.removeClass("editor-linenumber-marked")

  setLineNumberError: (n) ->
    @div.lineNumbers[n]?.removeClass("editor-linenumber-marked")
    @div.lineNumbers[n]?.addClass("editor-linenumber-error")

  clearLineNumberMarks: ->
    for div in @div.lineNumbers then div.removeClass("editor-linenumber-marked")

  clearLineNumberErrors: ->
    for div in @div.lineNumbers then div.removeClass("editor-linenumber-error")

  moveDivToLine: (div, y) ->
    div.css("top", y * @lineHeight)

  # callback(line#, text)
  foreachLine: (f) ->
    for i in [0 ... @lines.length] then f(i, @lines[i])

  getLine: (y) -> @lines[y]

  focus: -> @div.text.focus()

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

  moveCursor: (x, y) ->
    if x? then @cursorX = x
    if y? then @cursorY = y
    @div.cursor.css("top", @cursorY * @lineHeight + 1)
    @div.cursor.css("left", @cursorX * @em - 1 + 5)
    @moveDivToLine(@div.cursorHighlight, @cursorY)
    @div.cursor.css("display", "block")

  scrollToLine: (y) ->
    windowTop = @element.scrollTop()
    windowBottom = windowTop + @element.height()
    lineTop = y * @lineHeight
    lineBottom = lineTop + @lineHeight
    if lineTop < windowTop
      @element.scrollTop(Math.max(0, lineTop - @lineHeight))
    else if lineBottom > windowBottom
      @element.scrollTop(lineTop - @lineHeight * (@windowLines() - 1))

  setCursor: (x, y) ->
    @moveCursor(x, y)
    @scrollToLine(@cursorY)

  stopCursor: ->
    if @cursorTimer? then clearInterval(@cursorTimer)
    @div.cursor.css("display", "none")

  startCursor: ->
    @stopCursor()
    @cursorTimer = setInterval((=> @blinkCursor()), @CURSOR_RATE)
    @moveCursor()

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
    @div.text.focus()
    [ x, y ] = @mouseToPosition(event)
    @setCursor(x, y)
    @virtualX = 0
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
    if not event.shiftKey
      @lastMouseUp = Date.now()
      @lastMouseUpClicks = 1
    if not @selection? then return
    @div.text.unbind("mousemove")
    @div.text.unbind("mouseout")
    @div.text.unbind("mouseover")
    clearTimeout(@autoScrollTimer)
    @autoScrollTimer = null
    @addSelection(x, y)
    if (not event.shiftKey) and @selection[0].y == @selection[1].y and @selection[0].x == @selection[1].x
      @cancelSelection()
    false

  mouseMoveEvent: (event) ->
    [ x, y ] = @mouseToPosition(event)
    if @selection? then @addSelection(x, y)
    @moveCursor(x, y)

  mouseOutEvent: (event) =>
    # weird chrome bug makes it send us a blur for moving between lines.
    if event.toElement.parentElement is @div.text[0] then return
    [ x, y ] = @mouseToPosition(event)
    @setCursor(x, y)
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

  adjustX: ->
    if @virtualX > @cursorX then @cursorX = @virtualX
    if @cursorX > @lines[@cursorY].length then [ @virtualX, @cursorX ] = [ @cursorX, @lines[@cursorY].length ]
    if @virtualX <= @cursorX then @virtualX = 0

  moveUp: ->
    if @cursorY > 0 then @cursorY -= 1
    @adjustX()
    @setCursor()

  moveDown: ->
    if @cursorY < @lines.length - 1 then @cursorY += 1
    @adjustX()
    @setCursor()

  moveLeft: ->
    if @cursorX > 0
      @cursorX -= 1
    else if @cursorY > 0
      @cursorY -= 1
      @cursorX = @lines[@cursorY].length
    @virtualX = 0
    @setCursor()

  moveRight: ->
    if @cursorX < @lines[@cursorY].length
      @cursorX += 1
    else if @cursorY < @lines.length - 1
      @cursorY += 1
      @cursorX = 0
    @virtualX = 0
    @setCursor()

  movePageUp: ->
    @cursorY -= @windowLines()
    if @cursorY < 0 then @cursorY = 0
    @adjustX()
    @centerLine()
    @setCursor()

  movePageDown: ->
    @cursorY += @windowLines()
    if @cursorY > @lines.length - 1 then @cursorY = @lines.length - 1
    @adjustX()
    @centerLine()
    @setCursor()

  # ----- operations on the text

  deleteText: (x, y, count) ->
    while count > 0 and y < @lines.length
      n = @lines[y][x ... x + count].length
      @lines[y] = @lines[y][0...x] + @lines[y][x + count ...]
      @refreshLine(y)
      count -= n
      if count > 0
        @mergeLines(y)
        count -= 1

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

  typed: ->
    if @typingTimer? then clearTimeout(@typingTimer)
    @typingTimer = setTimeout((=> @typingFinished()), @TYPING_RATE)

  typingFinished: ->
    if @typingTimer? then clearTimeout(@typingTimer)
    @typingTimer = null
    setTimeout((=> @updateCallback()), 0)

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
    @virtualX = 0
    @setCursor()

  end: ->
    @cursorX = @lines[@cursorY].length
    @virtualX = 0
    @setCursor()

  pageUp: ->
    @cancelSelection()
    @movePageUp()

  pageDown: ->
    @cancelSelection()
    @movePageDown()

  top: ->
    @cancelSelection()
    @setCursor(0, 0)

  bottom: ->
    @cancelSelection()
    @setCursor(0, @lines.length - 1)

  deleteForward: ->
    @virtualX = 0
    @typed()
    if @selection?
      @deleteSelection()
      return
    if @cursorX < @lines[@cursorY].length
      @addUndo(Undo.INSERT, @cursorX, @cursorY, @lines[@cursorY][@cursorX], @cursorX, @cursorY)
      @deleteText(@cursorX, @cursorY, 1)
    else if @cursorY < @lines.length - 1
      @addUndo(Undo.INSERT, @cursorX, @cursorY, "\n", @cursorX, @cursorY)
      @mergeLines(@cursorY)
      @typingFinished()

  backspace: ->
    @virtualX = 0
    @typed()
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
      @typingFinished()

  deleteToEol: ->
    # would be nice to add this to the clipboard, emacs style, but javascript can't access the clipboard on the fly.
    @virtualX = 0
    @typed()
    @addUndo(Undo.INSERT, @cursorX, @cursorY, @lines[@cursorY][@cursorX ...], @cursorX, @cursorY)
    @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX]
    @refreshLine(@cursorY)

  centerLine: ->
    topLine = Math.max(@cursorY - Math.floor((@windowLines() - 1) / 2), 0)
    @element.scrollTop(topLine * @lineHeight)

  insertChar: (c) ->
    @insert(String.fromCharCode(c))

  insert: (text) ->
    if @selection? then @deleteSelection()
    @virtualX = 0
    @typed()
    [ x, y ] = @insertText(@cursorX, @cursorY, text)
    @addUndo(Undo.DELETE, @cursorX, @cursorY, text, x, y)
    @setCursor(x, y)

  enter: ->
    if @selection? then @deleteSelection()
    @virtualX = 0
    @typingFinished()
    [ x, y ] = @insertLF(@cursorX, @cursorY)
    @addUndo(Undo.DELETE, @cursorX, @cursorY, "\n", x, y)
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
    if not @selection? then return
    oldx = @selection[@selectionIndex].x
    oldy = @selection[@selectionIndex].y
    @selection[@selectionIndex].x = x
    @selection[@selectionIndex].y = y
    # might need to reverse the order
    if @selection[1].y < @selection[0].y or (@selection[1].y == @selection[0].y and @selection[1].x < @selection[0].x)
      [ @selection[0], @selection[1] ] = [ @selection[1], @selection[0] ]
      @selectionIndex = 1 - @selectionIndex
    for n in [Math.min(@selection[0].y, oldy) .. Math.max(@selection[1].y, oldy)] then @refreshLine(n)

  setSelection: (x0, y0, x1, y1) ->
    @cancelSelection()
    @startSelection(@SELECTION_RIGHT, x0, y0)
    @addSelection(x1, y1)
    @setCursor(x1, y1)

  deleteSelection: ->
    [ x0, y0, x1, y1 ] = [ @selection[0].x, @selection[0].y, @selection[1].x, @selection[1].y ]
    @addUndo(Undo.INSERT_SELECT, x0, y0, @getSelection(), x1, y1)
    if y0 == y1
      # within one line
      @deleteText(x0, y0, x1 - x0)
    else
      # multi-line
      @lines[y0] = @lines[y0][...x0] + @lines[y1][x1...]
      for y in [y0 + 1 .. y1] then @deleteLine(y0 + 1)
    @setCursor(x0, y0)
    @selection = null
    @refreshLine(y0)

  getSelection: ->
    if not @selection? then return ""
    [ x0, y0, x1, y1 ] = [ @selection[0].x, @selection[0].y, @selection[1].x, @selection[1].y ]
    if y0 == y1
      @lines[y0][x0...x1]
    else
      buffer = [ @lines[y0][x0...] ].concat (for y in [y0 + 1 ... y1] then @lines[y]), [ @lines[y1][...x1] ]
      buffer.join("\n")

  moveSelection: (direction, movement) ->
    @startSelection(direction, @cursorX, @cursorY)
    movement()
    @addSelection(@cursorX, @cursorY)

  copySelection: (clipboard) ->
    clipboard.setData("Text", @getSelection())
    false

  cutSelection: (clipboard) ->
    @copySelection(clipboard)
    @deleteSelection()
    @typed()
    false

  paste: (clipboard) ->
    if "text/plain" in clipboard.types then @insert(clipboard.getData("text/plain"))
    @typed()
    false

  selectWord: ->
    x1 = Math.max(0, @cursorX - 1)
    x2 = x1
    while x1 >= 0 and @lines[@cursorY][x1].match(/\w/)? then x1 -= 1
    while x2 < @lines[@cursorY].length and x2 > 0 and @lines[@cursorY][x2].match(/\w/)? then x2 += 1
    if x2 > x1
      @setSelection(x1 + 1, @cursorY, x2, @cursorY)
    else if @lines[@cursorY][x1] != " "
      @setSelection(x1, @cursorY, x1 + 1, @cursorY)

  selectLine: ->
    if @lines[@cursorY].length == 0 then return
    if @cursorY + 1 < @lines.length
      @setSelection(0, @cursorY, 0, @cursorY + 1)
    else
      @setSelection(0, @cursorY, @lines[@cursorY].length, @cursorY)

  selectAll: ->
    @cancelSelection()
    @startSelection(@SELECTION_RIGHT, 0, 0)
    @addSelection(@lines[@lines.length - 1].length, @lines.length - 1)


  # ----- undo

  MAX_UNDO: 100
  UNDO_COMPACTION_RATE: 1000

  class Undo
    @INSERT = 1
    @INSERT_SELECT = 2
    @DELETE = 3

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
    @virtualX = 0
    @cancelSelection()
    item = @undoBuffer.pop()
    if not item? then return
    @typed()
    @redoBuffer.push(item)
    switch item.action
      when Undo.INSERT, Undo.INSERT_SELECT
        @insertText(item.x, item.y, item.text)
        @setCursor(item.nextX, item.nextY)
        if item.action == Undo.INSERT_SELECT
          @setSelection(item.x, item.y, item.nextX, item.nextY)
      when Undo.DELETE
        @deleteText(item.x, item.y, item.text.length)
        @setCursor(item.x, item.y)

  redo: ->
    @virtualX = 0
    @cancelSelection()
    item = @redoBuffer.pop()
    if not item? then return
    @typed()
    @undoBuffer.push(item)
    switch item.action
      when Undo.INSERT, Undo.INSERT_SELECT
        @deleteText(item.x, item.y, item.text.length)
        @setCursor(item.x, item.y)
      when Undo.DELETE
        @insertText(item.x, item.y, item.text)
        @setCursor(item.nextX, item.nextY)


exports.Editor = Editor


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

# $(document).ready =>
#   @editor = new Editor($("#editor"))
#   setTimeout((=> @editor.replaceText(@text)), 100)

