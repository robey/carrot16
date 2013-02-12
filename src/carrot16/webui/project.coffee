
# project-level commands like new, load, etc
Project =
  init: ->
    $("#menu-new").click => (@openNew(); @saveSession())
    $("#menu-load").click => @load()
    $("#menu-save").click => @save()
    $("#menu-close").click => (@closeTab(); @saveSession())
    $("#menu-rename").click => @rename()
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

  rename: ->
    if not webui.CodeViewSet.visible() then return
    webui.Tabs.activePane.data("codeview").editName()

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


exports.Project = Project
