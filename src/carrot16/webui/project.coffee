
CTRL_L = 12
CTRL_M = 13
CTRL_N = 14
CTRL_O = 15
CTRL_P = 16
CTRL_Q = 17
CTRL_R = 18
CTRL_S = 19
CTRL_T = 20
CTRL_U = 21
CTRL_V = 22
CTRL_W = 23

# project-level commands like new, load, etc
Project =
  init: ->
    $("#menu-new").click => @openNew()
    $("#menu-load").click => @load()
    $("#menu-save").click => @save()
    $("#menu-close").click => @closeTab()
    # thread "load" clicks through to the real file loader. (the web sucks.)
    $("#load_input").bind("change", Project.finishLoading)

  openNew: ->
    webui.Tabs.openNewEditor()

  closeTab: ->
    webui.Tabs.closeCurrent()

  load: ->
    $("#load_input").click()

  finishLoading: (event) ->
    file = event.target.files[0]
    # reset the chosen file, so it can be chosen again later.
    $("#load_input")[0].value = ""
    if not file.type.match("text.*")
      webui.LogPane.clear()
      webui.LogPane.log("Not a text file: " + file.name)
      return
    reader = new FileReader()
    reader.onerror = (e) =>
      webui.LogPane.clear()
      webui.LogPane.log("Error reading file: " + file.name)
    reader.onload = (e) =>
      view = new webui.CodeView()
      view.setName(file.name)
      view.setCode(e.target.result)
      view.activate()
    reader.readAsText(file)

  save: ->
    window.URL = window.webkitURL or window.URL
    if not webui.CodeViewSet.visible() then return
    codeview = webui.Tabs.activePane.data("codeview")
    a = $("<a/>")
    a.attr("download", codeview.getName())
    a.attr("href", window.URL.createObjectURL(codeview.save()))
    a.css("display", "hidden")
    $("#body").append(a)
    a[0].click()
    a.remove()

  keypress: (key) ->
    switch event.which
      when CTRL_L
        @load()
        true
      when CTRL_N
        @openNew()
        true
      when CTRL_S
        @save()
        true
      when CTRL_W
        @closeTab()
        true
      else
        false


exports.Project = Project
