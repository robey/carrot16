
MemView = 
  offset: null

  scrollTo: (addr) ->
    webui.Tabs.activate $("#tab-memory")
    $("#pane-memory").scrollTop(Math.floor(addr / 0x100) * 32)
    @update()

  update: ->
    offset = $("#pane-memory").scrollTop() * 8
    lines = $("#memory_linenums")
    dump = $("#memory_dump")
    lines.css("top", offset / 8)
    dump.css("top", offset / 8)
    if @offset == offset
      # update the cell contents only, don't rebuild.
      @refresh(offset)
    else
      @rebuild(offset, lines, dump)

  refresh: (offset) ->
    for addr in @range(offset)
      addrx = sprintf("%04x", addr)
      @buildCell($("#addr_#{addrx}"), addr)

  rebuild: (offset, lines, dump) ->
    lines.empty()
    dump.empty()
    for addr in @range(offset)
      addrx = sprintf("%04x", addr)
      if addr % 8 == 0
        lines.append("#{addrx}<br/>")
      dump.append(" ")
      cell = $("<span/>")
      cell.attr("id", "addr_#{addrx}")
      @buildCell(cell, addr)
      cell.bind "click", do (cell, addr) ->
        -> fetchInput cell, (v) => emulator.memory.set(addr, v)
      dump.append(cell)
      if addr % 8 == 7 then dump.append($("<br/>"))
    @offset = offset

  range: (offset) -> [offset ... Math.min(0x10000, offset + 256)]

  buildCell: (cell, addr) ->
    value = emulator.memory.peek(addr)
    # blow away all existing classes
    cell.attr("class", "memory_cell pointer")
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
