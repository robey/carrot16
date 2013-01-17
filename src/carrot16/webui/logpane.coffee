
LogPane =
  init: ->
    @pane = $("#log")
    @clear()

  clear: ->
    wasVisible = @visible()
    @pane.css("display", "none")
    @pane.empty()
    if wasVisible then webui.CodeViewSet.resizeAll()

  visible: -> @pane.css("display") != "none"

  height: ->
    if @visible() then @pane.outerHeight(true) else 0

  top: ->
    if @visible() then @pane.position().top else $(window).height()

  log: (message) ->
    if not @visible?
      @pane.css("display", "block")
      webui.CodeViewSet.resizeAll()
    @pane.append(message)
    @pane.append($("<br />"))


exports.LogPane = LogPane
