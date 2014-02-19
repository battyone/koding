class MainView extends KDView

  constructor:->

    super

    @notifications = []

  viewAppended:->

    @bindPulsingRemove()
    @bindTransitionEnd()
    @createHeader()
    @createDock()
    @createAccountArea()
    @createMainPanels()
    @createMainTabView()
    @setStickyNotification()

    @utils.defer => @emit 'ready'

  bindPulsingRemove:->

    router     = KD.getSingleton 'router'
    appManager = KD.getSingleton 'appManager'

    appManager.once 'AppCouldntBeCreated', removePulsing

    appManager.on 'AppCreated', (appInstance)->
      options = appInstance.getOptions()
      {title, name, appEmitsReady} = options
      routeArr = location.pathname.split('/')
      routeArr.shift()
      checkedRoute = if routeArr.first is "Develop" \
                     then routeArr.last else routeArr.first

      if checkedRoute is name or checkedRoute is title
        if appEmitsReady
          appView = appInstance.getView()
          appView.ready removePulsing
        else removePulsing()

  addBook:->
    # @addSubView new BookView delegate : this

  _logoutAnimation:->
    {body}        = document

    turnOffLine   = new KDCustomHTMLView
      cssClass    : "turn-off-line"
    turnOffDot    = new KDCustomHTMLView
      cssClass    : "turn-off-dot"

    turnOffLine.appendToDomBody()
    turnOffDot.appendToDomBody()

    body.style.background = "#000"
    @setClass               "logout-tv"


  createMainPanels:->

    @addSubView @panelWrapper = new KDView
      tagName  : "section"
      domId    : "main-panel-wrapper"

  createHeader:->

    {entryPoint} = KD.config

    @addSubView @header = new KDView
      tagName : "header"
      domId   : "main-header"

    @header.clear()

    @header.addSubView @headerContainer = new KDCustomHTMLView
      cssClass  : "inner-container"

    @logo = new KDCustomHTMLView
      tagName   : "a"
      domId     : "koding-logo"
      cssClass  : if entryPoint?.type is 'group' then 'group' else ''
      partial   : '<cite></cite>'
      click     : (event)=>
        KD.utils.stopDOMEvent event
        if KD.isLoggedIn()
        then KD.getSingleton('router').handleRoute "/Activity", {entryPoint}
        else location.replace '/'

    @headerContainer.addSubView @logo

    groupLogo = ""
    if KD.currentGroup?.logo
      groupLogo = KD.utils.proxifyUrl KD.currentGroup.logo,
        crop         : yes
        width        : 55
        height       : 55

      @logo.setCss 'background-image', "url(#{groupLogo})"
      @logo.setClass 'custom'

    @logo.setClass KD.config.environment


    @headerContainer.addSubView @logotype = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "logotype"
      partial   : "Koding"
      click     : (event)=>
        KD.utils.stopDOMEvent event
        KD.getSingleton('router').handleRoute "/", {entryPoint}

  createDock:->

    @headerContainer.addSubView KD.singleton('dock').getView()


  createAccountArea:->

    @accountArea = new KDCustomHTMLView
      cssClass : 'account-area'

    @headerContainer.addSubView @accountArea

    unless KD.isLoggedIn()
      @loginLink = new CustomLinkView
        cssClass    : 'header-sign-in'
        title       : 'Login'
        attributes  :
          href      : '/Login'
        click       : (event)->
          KD.utils.stopDOMEvent event
          KD.getSingleton('router').handleRoute "/Login"
      @accountArea.addSubView @loginLink

      mc = KD.getSingleton "mainController"
      mc.on "accountChanged.to.loggedIn", =>
        @loginLink.destroy()
        @createLoggedInAccountArea()

      return

    @createLoggedInAccountArea()

  createLoggedInAccountArea:->
    @accountArea.destroySubViews()

    @accountArea.addSubView @accountMenu = new AvatarAreaIconMenu
    @accountMenu.accountChanged KD.whoami()

    @accountArea.addSubView @avatarArea  = new AvatarArea {}, KD.whoami()
    @accountArea.addSubView @searchIcon  = new KDCustomHTMLView
      domId      : 'fatih-launcher'
      cssClass   : 'search acc-dropdown-icon'
      tagName    : 'a'
      attributes :
        title    : 'Search'
        href     : '#'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        # log 'run fatih'

        @accountArea.setClass "search-open"
        @searchInput.setFocus()

        KD.getSingleton("windowController").addLayer @searchInput

        @searchInput.once "ReceivedClickElsewhere", =>
          if not @searchInput.getValue()
            @accountArea.unsetClass "search-open"

      partial    : "<span class='icon'></span>"

    @accountArea.addSubView @searchForm = new KDCustomHTMLView
      cssClass   : "search-form-container"

    handleRoute = (searchRoute, text)->
      if group = KD.getSingleton("groupsController").getCurrentGroup()
        groupSlug = if group.slug is "koding" then "" else "/#{group.slug}"
      else
        groupSlug = ""

      toBeReplaced =  if text is "" then "?q=:text:" else ":text:"

      # inject search text
      searchRoute = searchRoute.replace toBeReplaced, text
      # add group slug
      searchRoute = "#{groupSlug}#{searchRoute}"

      KD.getSingleton("router").handleRoute searchRoute

    search = (text) ->
      currentApp  = KD.getSingleton("appManager").getFrontApp()
      if currentApp and searchRoute = currentApp.options.searchRoute
        return handleRoute searchRoute, text
      else
        return handleRoute "/Activity?q=:text:", text

    @searchForm.addSubView @searchInput = new KDInputView
      placeholder  : "Search here..."
      keyup      : (event)=>
        text = @searchInput.getValue()
        # if user deleted everything in textbox
        # clear the search result
        if text is "" and @searchInput.searched
          search("")
          @searchInput.searched = false

        # 13 is ENTER
        if event.keyCode is 13
          search text
          @searchInput.searched = true

        # 27 is ESC
        if event.keyCode is 27
          @accountArea.unsetClass "search-open"
          @searchInput.setValue ""
          @searchInput.searched = false


  createMainTabView:->

    @appSettingsMenuButton = new AppSettingsMenuButton
    @appSettingsMenuButton.hide()

    @mainTabView = new MainTabView
      domId               : "main-tab-view"
      listenToFinder      : yes
      delegate            : this
      slidingPanes        : no
      hideHandleContainer : yes

    @mainTabView.on "PaneDidShow", =>
      appManager   = KD.getSingleton "appManager"

      return  unless appManager.getFrontApp()

      appManifest  = appManager.getFrontAppManifest()
      forntAppName = appManager.getFrontApp().getOptions().name
      menu         = appManifest?.menu or KD.getAppOptions(forntAppName)?.menu
      if Array.isArray menu
        menu = items: menu
      if menu?.items?.length
        @appSettingsMenuButton.setData menu
        @appSettingsMenuButton.show()
      else
        @appSettingsMenuButton.hide()

    @mainTabView.on "AllPanesClosed", ->
      KD.getSingleton('router').handleRoute "/Activity"

    @panelWrapper.addSubView @mainTabView
    @panelWrapper.addSubView @appSettingsMenuButton

  setStickyNotification:->

    return if not KD.isLoggedIn() # don't show it to guests

    {JSystemStatus} = KD.remote.api

    JSystemStatus.on 'restartScheduled', @bound 'handleSystemMessage'

    KD.utils.wait 2000, =>
      KD.remote.api.JSystemStatus.getCurrentSystemStatuses (err, statuses)=>
        if err then log 'current system status:',err
        else
          {daisy} = Bongo
          queue   = statuses.map (status)=>=>
            @createGlobalNotification status
            KD.utils.wait 500, -> queue.next()

          daisy queue.reverse()

  handleSystemMessage:(message)->

    @createGlobalNotification message  if message.status is 'active'

  hideAllNotifications:->

    notification.hide() for notification in @notifications

  createGlobalNotification:(message, options = {})->

    typeMap =
      'restart' : 'warn'
      'reload'  : ''
      'info'    : ''
      'red'     : 'err'
      'yellow'  : 'warn'
      'green'   : ''

    options.type      or= typeMap[message.type]
    options.showTimer  ?= message.type isnt 'restart'
    options.cssClass    = KD.utils.curry "header-notification", options.type
    options.cssClass    = KD.utils.curry options.cssClass, 'fx'  if options.animated

    @notifications.push notification = new GlobalNotificationView options, message

    @header.addSubView notification
    @hideAllNotifications()

    notification.once 'KDObjectWillBeDestroyed', =>
      for n, i in @notifications
        if n.getId() is notification.getId()
          @notifications[i-1]?.show()
          break

    KD.utils.wait 177, notification.bound 'show'


  enableFullscreen: ->
    @setClass "fullscreen no-anim"
    @emit "fullscreen", yes
    KD.getSingleton("windowController").notifyWindowResizeListeners()

  disableFullscreen: ->
    @unsetClass "fullscreen no-anim"
    @emit "fullscreen", no
    KD.getSingleton("windowController").notifyWindowResizeListeners()

  isFullscreen: -> @hasClass "fullscreen"

  toggleFullscreen: ->
    if @isFullscreen() then @disableFullscreen() else @enableFullscreen()

  removePulsing = ->

    loadingScreen = document.getElementById 'main-loading'

    return unless loadingScreen

    logo = loadingScreen.children[0]
    logo.classList.add 'out'

    KD.utils.wait 750, ->

      loadingScreen.classList.add 'out'

      KD.utils.wait 750, ->

        loadingScreen.parentElement.removeChild loadingScreen

        return if KD.isLoggedIn()

        cdc      = KD.singleton('display')
        mainView = KD.getSingleton 'mainView'

        return unless Object.keys(cdc.displays).length

        for own id, display of cdc.displays
          top      = display.$().offset().top
          duration = 400
          KDScrollView::scrollTo.call mainView, {top, duration}
          break