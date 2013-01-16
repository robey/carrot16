
MemView = 
  offset: null
  columns: null
  windowRows: 32

  scrollTo: (addr) ->
    webui.Tabs.activate $("#tab-memory")
    page = @windowRows * @columns
    $("#pane-memory").scrollTop(Math.floor(addr / page) * @windowRows)
    @update()

  update: ->
    if $("#pane-memory").css("display") == "none" then return
    if not @columns?
      @checkWidth()
      rows = 0x10000 / @columns
      lineHeight = 20
      $("#memory_view").height(rows + (@windowRows - 1) * lineHeight - 5)
    offset = $("#pane-memory").scrollTop() * @columns
    lines = $("#memory_linenums")
    dump = $("#memory_dump")
    lines.css("top", offset / @columns)
    dump.css("top", offset / @columns)
    if @offset == offset
      # update the cell contents only, don't rebuild.
      @refresh(offset)
    else
      @rebuild(offset, lines, dump)

  # figure out if we can fit 16 words wide (and do so)
  checkWidth: ->
    dump = $("#memory_dump")
    for cols in [ 16, 8 ]
      line = $("<span/>")
      for i in [0 ... cols]
        span = $("<span/>")
        span.addClass("memory-cell")
        span.text("0000")
        line.append(span)
      dump.append(line)
      if line.width() + 50 < dump.width()
        # found one that fits!
        @columns = cols
        dump.width(line.width() + 10)
        return
    @columns = 8

  refresh: (offset) ->
    for addr in @range(offset)
      addrx = sprintf("%04x", addr)
      @buildCell($("#addr_#{addrx}"), addr)

  rebuild: (offset, lines, dump) ->
    lines.empty()
    dump.empty()
    for addrRow in @range(offset) by @columns
      addrx = sprintf("%04x", addrRow)
      lines.append("#{addrx}<br/>")
      row = $("<div/>")
      row.addClass("memory-dump-line")
      for addr in [addrRow ... addrRow + @columns]
        addrx = sprintf("%04x", addr)
        cell = $("<span/>")
        cell.attr("id", "addr_#{addrx}")
        @buildCell(cell, addr)
        cell.bind "click", do (cell, addr) ->
          -> fetchInput cell, (v) => emulator.memory.set(addr, v)
        row.append(cell)
        #if addr % 8 == 7 then dump.append($("<br/>"))
      dump.append(row)
    @offset = offset

  range: (offset) -> [offset ... Math.min(0x10000, offset + @columns * @windowRows)]

  buildCell: (cell, addr) ->
    value = emulator.memory.peek(addr)
    # blow away all existing classes
    cell.attr("class", "memory-cell pointer")
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


exports.MemView = MemView
