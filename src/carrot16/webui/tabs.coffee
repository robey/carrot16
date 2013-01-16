
# handle the navtab and showing/hiding panels
Tabs =
  tablist: []
  activePane: null

  init: ->
    @tablist.push $("#tab-memory")
    @connect $("#tab-memory"), $("#pane-memory")
    $("#pane-memory").data "redraw", => webui.MemView.update()
    # FIXME:
    @tablist.push $("#fixme")
    @activePane = $(".pane-editor")
    @activePane.data("tab", $("#fixme"))
    $("#fixme").data("pane", @activePane)
    $("#fixme").click => @activate($("#fixme"))
    # only one tab should be active at first
    for tab in @tablist
      tab.removeClass("active")
      tab.data("pane").css("display", "none")
    @activate($("#fixme"))

  connect: (tab, pane) ->
    tab.click => @activate(tab)
    tab.data("pane", pane)
    pane.data("tab", tab)

  activate: (tab) ->
    if tab.hasClass("active") then return
    @activePane.data("scroll", @activePane.scrollTop())
    @activePane.css("display", "none")
    @activePane.data("tab").removeClass("active")
    # switch!
    @activePane = tab.data("pane")
    @activePane.css("display", "block")
    tab.addClass("active")
    if @activePane.data("scroll")? then @activePane.scrollTop(@activePane.data("scroll"))
    if @activePane.data("redraw")? then @activePane.data("redraw")()

  next: ->
    tab = @activePane.data("tab")
    n = 0
    while not (@tablist[n][0] is tab[0]) then n += 1
    n += 1
    if n >= @tablist.length then n = 0
    @activate(@tablist[n])


exports.Tabs = Tabs
