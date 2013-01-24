
class Editor
  CURSOR_RATE: 500

  constructor: (@element) ->
    @div =
      lineNumbers: element.find(".editor-linenumbers")
      text: element.find(".editor-text")
      textBackground: element.find(".editor-text-background")
      listing: element.find(".editor-listing")
      cursor: element.find(".editor-cursor")
      cursorHighlight: element.find(".editor-cursor-highlight")
    setTimeout((=> @init()), 1)

  init: ->
    @calculateEm()
    @lineHeight = parseInt(@element.css("line-height"))
    # contents being edited:
    @lines = [ ":start", "  SET A, 3", "  ADD X, A", "  ; return", "  RET" ]
    @cursorY = 1
    @cursorX = 0
    @setCursor()
    @stopCursor()
    # force line numbers to be 5-em wide.
    @div.lineNumbers.css("width", 5 * @em + 20)
    # force listing to be 20-em wide.
    @div.listing.css("width", 22 * @em)
    # make background size match editor
    @div.textBackground.css("width", @div.text.width())
    @div.textBackground.css("height", @div.text.height())
    @div.textBackground.css("top", @div.text.position().top)
    @div.textBackground.css("left", @div.text.position().left)
    # hook up keyboard control
    @div.text.focus => @startCursor()
    @div.text.blur => @stopCursor()
    @div.text.keydown (event) => @keydown(event)
    @div.text.keypress (event) => @keypress(event)
    @div.text.click (event) => @moveCursor(event)

  calculateEm: ->
    span = $("<span>0</span>")
    @div.lineNumbers.append(span)
    @em = span.outerWidth(true)
    span.remove()
    console.log("em = #{@em}")

  setCursor: ->
    @div.cursor.css("top", @cursorY * @lineHeight + 1)
    @div.cursor.css("left", @cursorX * @em - 1 + 3)
    @div.cursorHighlight.css("top", @cursorY * @lineHeight + 2)
    @div.cursor.css("display", "block")

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
      when Key.DELETE
        @deleteForward()
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
        @cursorX = @lines[@cursorY].length
        @setCursor()
        false
      else
        true

  # actions

  left: ->
    if @cursorX > 0 then @cursorX -= 1
    @setCursor()

  right: ->
    if @cursorX < @lines[@cursorY].length then @cursorX += 1
    @setCursor()

  up: ->
    if @cursorY > 0 then @cursorY -= 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  down: ->
    if @cursorY < @lines.length - 1 then @cursorY += 1
    if @cursorX > @lines[@cursorY].length then @cursorX = @lines[@cursorY].length
    @setCursor()

  deleteForward: ->
    console.log "del"
    if @cursorX < @lines[@cursorY].length
      @lines[@cursorY] = @lines[@cursorY][0 ... @cursorX] + @lines[@cursorY][@cursorX + 1 ...]
    else
      0
    false

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

$(document).ready =>
  @editor = new Editor($("#editor"))

