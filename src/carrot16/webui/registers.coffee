
Registers = 
  init: ->
    $("#PC").click(=> @goToPC())
    $("#regPC").click(=> webui.EditBox.start $("#regPC"), (v) => emulator.registers.PC = v)
    $("#SP").click(=> webui.MemView.scrollTo(emulator.registers.SP))
    $("#regSP").click(=> webui.EditBox.start $("#regSP"), (v) => emulator.registers.SP = v)
    $("#IA").click(=> webui.MemView.scrollTo(emulator.registers.IA))
    $("#regIA").click(=> webui.EditBox.start $("#regIA"), (v) => emulator.registers.IA = v)
    $("#A").click(=> webui.MemView.scrollTo(emulator.registers.A))
    $("#regA").click(=> webui.EditBox.start $("#regA"), (v) => emulator.registers.A = v)
    $("#B").click(=> webui.MemView.scrollTo(emulator.registers.B))
    $("#regB").click(=> webui.EditBox.start $("#regB"), (v) => emulator.registers.B = v)
    $("#C").click(=> webui.MemView.scrollTo(emulator.registers.C))
    $("#regC").click(=> webui.EditBox.start $("#regC"), (v) => emulator.registers.C = v)
    $("#X").click(=> webui.MemView.scrollTo(emulator.registers.X))
    $("#regX").click(=> webui.EditBox.start $("#regX"), (v) => emulator.registers.X = v)
    $("#Y").click(=> webui.MemView.scrollTo(emulator.registers.Y))
    $("#regY").click(=> webui.EditBox.start $("#regY"), (v) => emulator.registers.Y = v)
    $("#Z").click(=> webui.MemView.scrollTo(emulator.registers.Z))
    $("#regZ").click(=> webui.EditBox.start $("#regZ"), (v) => emulator.registers.Z = v)
    $("#I").click(=> webui.MemView.scrollTo(emulator.registers.I))
    $("#regI").click(=> webui.EditBox.start $("#regI"), (v) => emulator.registers.I = v)
    $("#J").click(=> webui.MemView.scrollTo(emulator.registers.J))
    $("#regJ").click(=> webui.EditBox.start $("#regJ"), (v) => emulator.registers.J = v)
    $("#EX").click(=> webui.MemView.scrollTo(emulator.registers.EX))
    $("#regEX").click(=> webui.EditBox.start $("#regEX"), (v) => emulator.registers.EX = v)

  goToPC: ->
    if webui.CodeViewSet.visible()
      webui.CodeViewSet.updatePcHighlight(true)
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
      Math.floor(lowColor[i] + cpuHeat * (hiColor[i] - lowColor[i]))
    canvas = $("#cpu_heat")[0].getContext("2d")
    canvas.fillStyle = "#fff"
    canvas.fillRect(0, 0, 1, 100)
    canvas.fillStyle = "rgb(#{color[0]},#{color[1]},#{color[2]})"
    canvas.fillRect(0, Math.floor(100 * (1.0 - cpuHeat)), 1, 100)


exports.Registers = Registers
