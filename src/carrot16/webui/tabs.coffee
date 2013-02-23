
# handle the navtab and showing/hiding panels
Tabs =
  tablist: []
  activePane: null

  init: ->
    @connect $("#tab-memory"), $("#pane-memory")
    $("#pane-memory").data "focus", => webui.MemView.focus()

  connect: (tab, pane) ->
    tab.click => (@activate(tab); webui.Project.saveSession())
    tab.data("pane", pane)
    pane.data("tab", tab)
    tab.removeClass("active")
    pane.css("display", "none")
    @tablist.push tab

  activate: (tab) ->
    webui.EditBox.cancel()
    if tab.hasClass("active") then return
    if @activePane?
      @activePane.data("scroll", @activePane.scrollTop())
      @activePane.css("display", "none")
      @activePane.data("tab").removeClass("active")
    # switch!
    @activePane = tab.data("pane")
    @activePane.css("display", "block")
    tab.addClass("active")
    if @activePane.data("scroll")? then @activePane.scrollTop(@activePane.data("scroll"))
    if @activePane.data("focus")? then setTimeout((=> @activePane.data("focus")()), 0)

  activeTab: ->
    @activePane?.data("tab")
  
  current: ->
    tab = @activeTab()
    n = 0
    while n < @tablist.length and not (@tablist[n][0] is tab[0]) then n += 1
    n

  next: ->
    n = @current() + 1
    if n >= @tablist.length then n = 0
    @activate(@tablist[n])
    webui.Project.saveSession()

  previous: ->
    n = @current() - 1
    if n < 0 then n = @tablist.length - 1
    @activate(@tablist[n])
    webui.Project.saveSession()

  openNewEditor: ->
    view = new webui.CodeView()
    view.setName("(untitled)")
    view.activate()
    view

  close: (pane) ->
    tab = pane.data("tab")
    if tab is @activeTab() then @next()
    @tablist = @tablist.filter (x) -> x isnt tab
    tab.remove()
    webui.CodeViewSet.remove(pane.data("codeview"))
    pane.remove()
    webui.CodeViewSet.assemble()

  closeCurrent: ->
    if not @activePane? then return
    if not webui.CodeViewSet.visible() then return
    @close(@activePane)

  closeByName: (name) ->
    view = webui.CodeViewSet.findByName(name)
    if not view? then return
    @close(view.pane)

  closeAll: ->
    for tab in @tablist
      if tab.data("pane")?.data("codeview")?
        @activate(tab)
        @closeCurrent()
        @closeAll()
        return

  saveSession: (projectId) ->
    tabIds = []
    for tab in @tablist
      codeview = tab.data("pane")?.data("codeview")
      if codeview?
        tabIds.push(codeview.name)
        codeview.saveSession("c16:editor-#{projectId}-#{codeview.name}")
    data = { tabs: tabIds, current: @current() }
    localStorage.setItem("c16:tabs-#{projectId}", JSON.stringify(data))

  loadSession: (projectId) ->
    data = localStorage.getItem("c16:tabs-#{projectId}")
    if not data? then return
    @closeAll()
    data = JSON.parse(data)
    @continueLoadSession(projectId, data, 0)

  # have to do this as a trampoline through the main chrome event loop, so it
  # has time to render the pages and give us metrics.
  continueLoadSession: (projectId, data, index) ->
    if index < data.tabs.length
      tabId = data.tabs[index]
      codeview = new webui.CodeView(tabId)
      codeview.loadSession("c16:editor-#{projectId}-#{tabId}")
      @activate(codeview.tab)
      setTimeout((=> @continueLoadSession(projectId, data, index + 1)), 0)
    else
      if data.current >= 0 and data.current < @tablist.length
        @activate(@tablist[data.current])


exports.Tabs = Tabs
