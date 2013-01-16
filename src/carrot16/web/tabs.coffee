
Tabs =
  tablist: []
  activePane: null

  init: ->
    @tablist.push $("#tab-memory")
    $("#tab-memory").click => @activate($("#tab-memory"))
    # FIXME: fix name of tab1_content
    $("#tab-memory").data("pane", $("#tab1_content"))
    $("#tab1_content").data("tab", $("#tab-memory"))
    $("#tab1_content").data "redraw", =>
      updateViews()
    # FIXME:
    @tablist.push $("#fixme")
    @activePane = $("#tab0_content")
    @activePane.data("tab", $("#fixme"))
    $("#fixme").data("pane", @activePane)
    $("#fixme").click => @activate($("#fixme"))

  activate: (tab) ->
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
