
# project-level commands like new, load, etc
Project =
  init: ->
    $("#menu-new").click => (@openNew(); @saveSession())
    $("#menu-load").click => @load()
    $("#menu-save").click => @saveCode()
    $("#menu-close").click => (@closeTab(); @saveSession())
    $("#menu-rename").click => @rename()
    $("#menu-load-image").click => @loadImage()
    $("#menu-save-image").click => @saveImage()
    $("#menu-disassemble").click => @disassemble()
    # thread "load" clicks through to the real file loader. (the web sucks.)
    $("#load_input").bind("change", Project.finishLoading)

  openNew: ->
    webui.Tabs.openNewEditor()

  closeTab: ->
    webui.Tabs.closeCurrent()

  load: ->
    $("#load_input").data("expect", "code")
    $("#load_input").click()

  loadImage: ->
    $("#load_input").data("expect", "image")
    $("#load_input").click()

  finishLoading: (event) ->
    file = event.target.files[0]
    # reset the chosen file, so it can be chosen again later.
    $("#load_input")[0].value = ""
    expect = $("#load_input").data("expect")
    switch expect
      when "code" then Project.loadCode(file)
      when "image" then Project.loadImage2(file)

  download: (name, data) ->
    # javascript voodoo begin!
    window.URL = window.webkitURL or window.URL
    a = $("<a/>")
    a.attr("download", name)
    url = window.URL.createObjectURL(data)
    a.attr("href", url)
    a.css("display", "hidden")
    $("#body").append(a)
    a[0].click()
    a.remove()
    setTimeout((=> window.URL.revokeObjectURL(url)), 60000)

  logError: (message) ->
    webui.LogPane.clear()
    webui.LogPane.log(message)

  loadCode: (file) ->
    if not file.type.match("text.*")
      Project.logError("Not a text file: #{file.name}")
      return
    reader = new FileReader()
    reader.onerror = (e) =>
      Project.logError("Error reading file: #{file.name}")
    reader.onload = (e) =>
      view = new webui.CodeView()
      view.setName(file.name)
      view.setCode(e.target.result)
      view.activate()
    reader.readAsText(file)

  saveCode: ->
    if not webui.CodeViewSet.visible() then return
    codeview = webui.Tabs.activePane.data("codeview")
    @download(codeview.getName(), codeview.save())

  rename: ->
    if not webui.CodeViewSet.visible() then return
    webui.Tabs.activePane.data("codeview").editName()

  loadImage2: (file) ->
    if not (file.size in [ 0x20000, 0x20002, 0x20004 ])
      Project.logError("Image file isn't 128KB: #{file.name}")
      return
    reader = new FileReader()
    reader.onerror = (e) =>
      Project.logError("Error reading file: #{file.name}")
    reader.onload = (e) =>
      buffer = new Uint8Array(e.target.result)
      if buffer.length == 0x20004
        if buffer[0x20002] != 0x10 or buffer[0x20003] != 0x16
          Project.logError("Not a memory image file: #{file.name}")
          console.log buffer[0x20002]
          return
      endian = "big"
      if buffer.byteLength > 0x20000 and buffer[0x20000] == 0xff
        endian = "little"
      for i in [0 ... 0x10000]
        data = if endian == "big"
          (buffer[i * 2] << 8) | (buffer[i * 2 + 1])
        else
          (buffer[i * 2 + 1] << 8) | (buffer[i * 2])
        emulator.memory.memory[i] = data
      webui.MemView.update()
    reader.readAsArrayBuffer(file)

  saveImage: ->
    name = webui.CodeViewSet.firstName() + ".d16"
    # make a memory buffer
    buffer = new Uint8Array(0x20004)
    for i in [0 ... 0x10000]
      word = emulator.memory.peek(i)
      buffer[i * 2] = (word >> 8) & 0xff
      buffer[i * 2 + 1] = word & 0xff
    # add byte order indicator
    buffer[0x20000] = 0xfe
    buffer[0x20001] = 0xff
    # header to identify a memory image
    buffer[0x20002] = 0x10
    buffer[0x20003] = 0x16
    blob = new Blob([ buffer ], type: "application/binary")
    @download(name, blob)

  loadSession: ->
    @projectId = localStorage.getItem("c16:current-project")
    if not @projectId?
      @projectId = carrot16.Congeal.uniqueId()
      return false
    webui.Tabs.loadSession(@projectId)
    true

  saveSession: ->
    keys = (for i in [0 ... localStorage.length] then localStorage.key(i))
    for key in keys then if key[0...4] == "c16:" then localStorage.removeItem(key)
    localStorage.setItem("c16:current-project", @projectId)
    webui.Tabs.saveSession(@projectId)

  disassemble: ->
    d = new d16bunny.Disassembler(emulator.memory.memory)
    lines = d.disassemble()
    # get rid of any old tab
    webui.Tabs.closeByName("(disassembled)")
    view = new webui.CodeView()
    view.setName("(disassembled)")
    view.setCode(lines.join("\n"))
    view.activate()


exports.Project = Project
