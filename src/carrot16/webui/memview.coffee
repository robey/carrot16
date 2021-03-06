
MemView = 
  offset: null
  columns: null
  rows: null

  init: ->
    pane = $("#pane-memory")
    view = $("#memory-view")
    pane.bind "keydown", "up", =>
      top = view.scrollTop()
      view.scrollTop(Math.max(top - 1, 0))
      false
    pane.bind "keydown", "down", =>
      top = view.scrollTop()
      view.scrollTop(top + 1)
      false
    pane.bind "keydown", "pageup", =>
      top = view.scrollTop()
      view.scrollTop(Math.max(top - @rows, 0))
      false
    pane.bind "keydown", "pagedown", =>
      top = view.scrollTop()
      view.scrollTop(top + @rows)
      false
    pane.bind "keydown", "shift+up", =>
      top = view.scrollTop()
      view.scrollTop(Math.max(top - (4096 / @columns), 0))
      false
    pane.bind "keydown", "shift+down", =>
      top = view.scrollTop()
      view.scrollTop(top + (4096 / @columns))
      false
    pane.bind "keydown", "meta+up", =>
      view.scrollTop(0)
      false
    pane.bind "keydown", "meta+down", =>
      view.scrollTop(0x10000)
      false

  scrollTo: (addr) ->
    webui.Tabs.activate $("#tab-memory")
    @checkWidth()
    page = @rows * @columns
    $("#memory-view").scrollTop(Math.floor(addr / page) * @rows)
    @update()

  visible: ->
    $("#pane-memory").css("display") != "none"

  resized: ->
    @columns = null
    @offset = null

  focus: ->
    @update()
    $("#pane-memory").focus()

  update: ->
    if not @visible() then return
    @checkWidth()
    offset = $("#memory-view").scrollTop() * @columns
    addr = $("#memory-addr")
    dump = $("#memory-dump")
    addr.css("top", offset / @columns)
    dump.css("top", offset / @columns)
    if @offset == offset
      # update the cell contents only, don't rebuild.
      @refresh(offset)
    else
      @rebuild(offset, addr, dump)

  # ensure that we've cached the width
  checkWidth: ->
    if @columns? then return
    @calculateSize()
    totalRows = 0x10000 / @columns
    lineHeight = 20
    $("#memory-scroller").height(totalRows - (@rows - 1) + (@rows * lineHeight) + 7)
    setTimeout((=> @update()), 0)

  # figure out if we can fit 16 words wide (and do so)
  calculateSize: ->
    pane = $("#pane-memory")
    addr = $("#memory-addr")
    dump = $("#memory-dump")
    lineHeight = parseInt(dump.css("line-height"))
    @debug "pane width=#{pane.width()} height=#{pane.height()} line=#{lineHeight}"

    # set the width of the address panel to fit exactly.
    addr.empty()
    addr.css("width", 0)
    span = $("<span>0000</span>")
    addr.append(span)
    addr.css("width", span.width() + addr.outerWidth())

    dump.css("width", "0")
    dump.empty()
    outerWidth = dump.outerWidth()

    # fit as many rows and columns (up to 32 each, using only powers of 2) as we can in the available space.
    @rows = 32
    loop
      height = lineHeight * (@rows + 1)
      break if height < pane.height()
      @rows /= 2

    @columns = 32
    loop
      dump.css("width", "100%")
      dump.empty()
      row = @buildRow(0, $("<span/>"))
      dump.append(row)
      if row.width() + 10 < pane.width() and row.height() <= lineHeight
        $("#memory-dump").css("width", row.width() + outerWidth)
        break
      @columns /= 2

    @debug "going with memory view of #{@columns} x #{@rows}"

  refresh: (offset) ->
    for addr in @range(offset)
      addrx = sprintf("%04x", addr)
      @buildCell($("#addr_#{addrx}"), addr)
    for addrRow in @range(offset) by @columns
      chars = $("#chars_#{sprintf("%04x", addrRow)}")
      chars.empty()
      for addr in [addrRow ... addrRow + @columns]
        @addChars(chars, addr)

  rebuild: (offset, addr, dump) ->
    addr.empty()
    dump.empty()
    for addrRow in @range(offset) by @columns
      addr.append("#{sprintf("%04x", addrRow)}<br/>")
      row = $("<div/>")
      row.addClass("memory-dump-line")
      dump.append(@buildRow(addrRow, row))
    @offset = offset

    # make the background roundrect match the internals.
    $("#memory-addr-background").css("width", $("#memory-addr").outerWidth())
    $("#memory-addr-background").css("height", $("#memory-addr").outerHeight())
    $("#memory-dump-background").css("width", $("#memory-dump").outerWidth() + 20)
    $("#memory-dump-background").css("height", $("#memory-dump").outerHeight())
    $("#memory-dump-background").css("left", $("#memory-dump").position().left)
    # the various scroll containers should be the same size as their contents.
    width = $("#memory-addr").outerWidth() + $("#memory-dump").outerWidth() + 10
    $("#memory-scroller").css("width", width)
    $("#memory-view").css("width", width)
    $("#memory-view").css("height", $("#memory-dump").outerHeight() + 4)

  buildRow: (addrRow, element) ->
    chars = $("<span/>")
    chars.attr("id", "chars_#{sprintf("%04x", addrRow)}")
    chars.css("display", "pre")
    for addr in [addrRow ... addrRow + @columns]
      addrx = sprintf("%04x", addr)
      cell = $("<span/>")
      cell.attr("id", "addr_#{addrx}")
      @buildCell(cell, addr)
      cell.bind "click", do (cell, addr) =>
        => webui.EditBox.start cell, (v) =>
          emulator.memory.set(addr, v)
          @update()
      element.append(cell)
      @addChars(chars, addr)
      if addr % 4 == 3 then element.append($("<span class=memory-dump-spacer />"))
    element.append($("<span class=memory-dump-spacer />"))
    element.append(chars)
    element

  range: (offset) -> [offset ... Math.min(0x10000, offset + @columns * @rows)]

  buildCell: (cell, addr) ->
    value = emulator.memory.peek(addr)
    # blow away all existing classes
    cell.attr("class", "memory-cell pointer editable")
    cell.html(sprintf("%04x", value))
    if addr == emulator.registers.PC
      cell.addClass("r_pc")
    else if addr == emulator.registers.SP
      cell.addClass("r_sp")
    else if addr != 0 and addr == emulator.registers.IA
      cell.addClass("r_ia")
    else if addr in memoryWrites
      cell.addClass("memory_write")
    else if addr in memoryReads
      cell.addClass("memory_read")

  addChars: (chars, addr) ->
    value = emulator.memory.peek(addr)
    for v in [ (value >> 8) & 0xff, value & 0xff ]
      if v > 0x20 and v < 0x7f
        chars.append(String.fromCharCode(v))
      else if v == 0x20
        chars.append("\u00a0")
      else
        chars.append(".")

  debug: (message) ->
    console.log "[memview] #{message}"


exports.MemView = MemView
