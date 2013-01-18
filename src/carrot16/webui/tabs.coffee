
# handle the navtab and showing/hiding panels
Tabs =
  tablist: []
  activePane: null

  init: ->
    @connect $("#tab-memory"), $("#pane-memory")
    $("#pane-memory").data "redraw", => webui.MemView.update()

  connect: (tab, pane) ->
    tab.click => @activate(tab)
    tab.data("pane", pane)
    pane.data("tab", tab)
    tab.removeClass("active")
    pane.css("display", "none")
    @tablist.push tab

  activate: (tab) ->
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
    if @activePane.data("redraw")? then setTimeout((=> @activePane.data("redraw")()), 0)

  next: ->
    tab = @activePane.data("tab")
    n = 0
    while not (@tablist[n][0] is tab[0]) then n += 1
    n += 1
    if n >= @tablist.length then n = 0
    @activate(@tablist[n])

  openNewEditor: ->
    view = new webui.CodeView()
    view.setName("(untitled)")
    view.setCode(DEMO)
    view.activate()


exports.Tabs = Tabs

DEMO = """; demo
set a, 3
"""