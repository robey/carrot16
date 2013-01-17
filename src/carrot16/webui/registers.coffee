
Registers = 
  init: ->
    $("#PC").click(=> @goToPC())
    $("#regPC").click(=> @fetchInput $("#regPC"), (v) => emulator.registers.PC = v)
    $("#SP").click(=> webui.MemView.scrollTo(emulator.registers.SP))
    $("#regSP").click(=> @fetchInput $("#regSP"), (v) => emulator.registers.SP = v)
    $("#IA").click(=> webui.MemView.scrollTo(emulator.registers.IA))
    $("#regIA").click(=> @fetchInput $("#regIA"), (v) => emulator.registers.IA = v)
    $("#A").click(=> webui.MemView.scrollTo(emulator.registers.A))
    $("#regA").click(=> @fetchInput $("#regA"), (v) => emulator.registers.A = v)
    $("#B").click(=> webui.MemView.scrollTo(emulator.registers.B))
    $("#regB").click(=> @fetchInput $("#regB"), (v) => emulator.registers.B = v)
    $("#C").click(=> webui.MemView.scrollTo(emulator.registers.C))
    $("#regC").click(=> @fetchInput $("#regC"), (v) => emulator.registers.C = v)
    $("#X").click(=> webui.MemView.scrollTo(emulator.registers.X))
    $("#regX").click(=> @fetchInput $("#regX"), (v) => emulator.registers.X = v)
    $("#Y").click(=> webui.MemView.scrollTo(emulator.registers.Y))
    $("#regY").click(=> @fetchInput $("#regY"), (v) => emulator.registers.Y = v)
    $("#Z").click(=> webui.MemView.scrollTo(emulator.registers.Z))
    $("#regZ").click(=> @fetchInput $("#regZ"), (v) => emulator.registers.Z = v)
    $("#I").click(=> webui.MemView.scrollTo(emulator.registers.I))
    $("#regI").click(=> @fetchInput $("#regI"), (v) => emulator.registers.I = v)
    $("#J").click(=> webui.MemView.scrollTo(emulator.registers.J))
    $("#regJ").click(=> @fetchInput $("#regJ"), (v) => emulator.registers.J = v)
    $("#EX").click(=> webui.MemView.scrollTo(emulator.registers.EX))
    $("#regEX").click(=> @fetchInput $("#regEX"), (v) => emulator.registers.EX = v)

  goToPC: ->
    if webui.Tabs.activePane?.hasClass("pane-editor")
      webui.Tabs.activePane.data("codeview").updatePcHighlight(true)
    else
      webui.MemView.scrollTo(emulator.registers.PC)

  update: ->
    for r, v of emulator.registers
      $("#reg#{r}").html(sprintf("%04x", v))
    $("#cycles").html(emulator.cycles)
    # update cpu heat meter
    lowColor = [ 127, 0, 0 ]
    hiColor = [ 255, 0, 0 ]
    # my kingdom for Array.zip
    color = [0...3].map (i) =>
      Math.floor(lowColor[i] + @cpuHeat * (hiColor[i] - lowColor[i]))
    canvas = $("#cpu_heat")[0].getContext("2d")
    canvas.fillStyle = "#fff"
    canvas.fillRect(0, 0, 1, 100)
    canvas.fillStyle = "rgb(#{color[0]},#{color[1]},#{color[2]})"
    canvas.fillRect(0, Math.floor(100 * (1.0 - @cpuHeat)), 1, 100)


exports.Registers = Registers
