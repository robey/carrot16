
Key = carrot16.Key

# one object = easy way to clear all the edit state at once
class EditState
  BLINK_TIME: 350
  TIMEOUT: 10000

  constructor: (@element, @callback) ->
    @text = @element.text()
    if @text.length < 4 then @text = sprintf("%04x", parseInt(@text, 16))
    @originalText = @text
    @position = 0
    @cursor = $("<span />")
    @cursor.css("background-color", "#000")
    @cursor.css("color", "#ff8")
    @cursor.css("position", "absolute")
    @cursor.css("display", "block")
    @setCursor()
    @blinker = setInterval((=> @blink()), @BLINK_TIME)
    @resetImpatience()

  cancel: ->
    @text = @originalText
    @element.text(@text)
    @end()

  commit: ->
    @callback(parseInt(@text, 16))
    @end()

  end: ->
    @cursor.remove()
    if @timeout? then clearTimeout(@timeout)
    if @blinker? then clearInterval(@blinker)
    EditBox.state = null

  # move cursor to @position
  setCursor: ->
    @element.text(@text)
    @cursor.text(if @position < @text.length then @text[@position] else "\u00a0")
    @cursor.remove()
    @element.append(@cursor)
    top = (@element.outerHeight() - parseInt(@element.css("line-height"))) / 2
    @cursor.css("top", top)
    left = Math.floor((@element.outerWidth() - (@cursor.width() * 4)) / 2)
    @cursor.css("left", left + Math.min(@position, @text.length) * @cursor.width())

  blink: ->
    @cursor.css("display", if @cursor.css("display") == "none" then "block" else "none")

  # you get a certain amount of time to type, before we auto-cancel.
  resetImpatience: ->
    if @timeout? then clearTimeout(@timeout)
    @timeout = setTimeout((=> @cancel()), @TIMEOUT)

  keydown: (key) ->
    switch key
      when Key.BACKSPACE
        # weird chrome bug: you must catch BACKSPACE before chrome does something inscrutible.
        if @position == 0 then return true
        @position -= 1
        @text = @text[0 ... @position] + @originalText[@position ... @text.length]
        @setCursor()
        true
      when Key.ESCAPE
        @cancel()
        true
      when Key.LEFT
        if @position > 0 then @position -= 1
        @setCursor()
        true
      when Key.RIGHT
        if @position <= @text.length then @position += 1
        @setCursor()
        true
      else
        false

  keypress: (key) ->
    if (key in [0x30...0x3a]) or (key in [0x41...0x47]) or (key in [0x61...0x67])
      if @position >= @text.length then @position = @text.length - 1
      @text = @text[0 ... @position] + String.fromCharCode(key) + @text[@position + 1 ... @text.length]
      @position += 1
      @setCursor()
      @resetImpatience()
      true
    else if (key == 13) or (key == 10)
      @commit()
      true
    else
      false


EditBox =
  state: null

  active: -> @state?

  # edit a 4-digit hex element, and call the callback when done.
  start: (element, callback) ->
    if @state?
      @state.cancel()
      return
    @state = new EditState(element, callback)

  cancel: ->
    @state?.cancel()

  keydown: (key) ->
    if not @state? then return false
    @state.keydown(key)

  keypress: (key) ->
    if not @state? then return false
    @state.keypress(key)


exports.EditBox = EditBox
