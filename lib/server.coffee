_            = require("underscore")
hbs          = require("hbs")
url          = require("url")
http         = require("http")
cookie       = require("cookie")
stream       = require("stream")
express      = require("express")
Promise      = require("bluebird")
statuses     = require("http-status-codes")
httpProxy    = require("http-proxy")
httpsProxy   = require("@cypress/core-https-proxy")
allowDestroy = require("server-destroy")
cors         = require("./util/cors")
appData      = require("./util/app_data")
buffers      = require("./util/buffers")
cwd          = require("./cwd")
errors       = require("./errors")
logger       = require("./logger")
Socket       = require("./socket")
Request      = require("./request")

DEFAULT_DOMAIN_NAME    = "localhost"
fullyQualifiedRe       = /^https?:\/\//
isOkayStatusRe         = /^2/

setProxiedUrl = (req) ->
  ## bail if we've already proxied the url
  return if req.proxiedUrl

  ## backup the original proxied url
  ## and slice out the host/origin
  ## and only leave the path which is
  ## how browsers would normally send
  ## use their url
  req.proxiedUrl = req.url
  logger.info "Setting proxied url", proxiedUrl: req.proxiedUrl

  req.url = url.parse(req.url).path

## currently not making use of event emitter
## but may do so soon
class Server
  constructor: ->
    if not (@ instanceof Server)
      return new Server

    @_server     = null
    @_socket     = null
    @_wsProxy    = null
    @_httpsProxy = null

  createExpressApp: (morgan) ->
    app = express()

    ## set the cypress config from the cypress.json file
    app.set("view engine", "html")
    app.engine("html",     hbs.__express)

    ## handle the proxied url in case
    ## we have not yet started our websocket server
    app.use (req, res, next) ->
      setProxiedUrl(req)
      next()

    app.use require("cookie-parser")()
    app.use require("compression")()
    app.use require("morgan")("dev") if morgan

    ## serve static file from public when route is /__cypress/static
    ## this is to namespace the static cypress files away from
    ## the real application by separating the root from the files
    app.use "/__cypress/static", express.static(cwd("lib", "public"))

    ## errorhandler
    app.use require("errorhandler")()

    ## remove the express powered-by header
    app.disable("x-powered-by")

    return app

  createRoutes: (app, config, getRemoteState) ->
    require("./routes")(app, config, getRemoteState)

  getHttpServer: -> @_server

  portInUseErr: (port) ->
    e = errors.get("PORT_IN_USE_SHORT", port)
    e.port = port
    e.portInUse = true
    e

  open: (config = {}) ->
    ## always reset any buffers
    ## TODO: change buffers to be an instance
    ## here and pass this dependency around
    buffers.reset()

    Promise.try =>
      app = @createExpressApp(config.morgan)

      logger.setSettings(config)

      getRemoteState = => @_getRemoteState()

      @createRoutes(app, config, getRemoteState)

      @createServer(config.port, config.socketIoRoute, app)

  createServer: (port, socketIoRoute, app) ->
    new Promise (resolve, reject) =>
      @_server  = http.createServer(app)
      @_wsProxy = httpProxy.createProxyServer()

      allowDestroy(@_server)

      onError = (err) =>
        ## if the server bombs before starting
        ## and the err no is EADDRINUSE
        ## then we know to display the custom err message
        if err.code is "EADDRINUSE"
          reject @portInUseErr(port)

      onUpgrade = (req, socket, head) =>
        @proxyWebsockets(@_wsProxy, socketIoRoute, req, socket, head)

      callListeners = (req, res) =>
        listeners = @_server.listeners("request").slice(0)

        @_callRequestListeners(@_server, listeners, req, res)

      onSniUpgrade = (req, socket, head) =>
        upgrades = @_server.listeners("upgrade").slice(0)
        for upgrade in upgrades
          upgrade.call(@_server, req, socket, head)

      @_server.on "connect", (req, socket, head) =>
        @_httpsProxy.connect(req, socket, head, {
          onDirectConnection: (req) =>
            ## make a direct connection only if
            ## our req url does not match the origin policy
            ## which is the superDomain + port
            dc = not cors.urlMatchesOriginPolicyProps("https://" + req.url, @_remoteProps)

            if dc
              str = "Making"
            else
              str = "Not making"

            logger.info(str + " direction connection to: '#{req.url}'")

            return dc
        })

      @_server.on "upgrade", onUpgrade

      @_server.once "error", onError

      @_listen(port, onError)
      .then (port) =>
        ## once we open set the domain
        ## to root by default
        ## which prevents a situation where navigating
        ## to http sites redirects to /__/ cypress
        @_onDomainSet("<root>")

        httpsProxy.create(appData.path("proxy"), port, {
          onRequest: callListeners
          onUpgrade: onSniUpgrade
        })
        .then (httpsProxy) =>
          @_httpsProxy = httpsProxy

          resolve(port)

  _listen: (port, onError) ->
    new Promise (resolve) =>
      listener = =>
        port = @_server.address().port

        @isListening = true

        logger.info("Server listening", {port: port})

        @_server.removeListener "error", onError

        resolve(port)

      ## nuke port from our args if its falsy
      args = _.compact([port, listener])

      @_server.listen.apply(@_server, args)

  _getRemoteState: ->
    # {
    #   origin: "http://localhost:2020"
    #   strategy: "file"
    #   domainName: "localhost"
    #   props: null
    # }

    # {
    #   origin: "https://foo.google.com"
    #   strategy: "http"
    #   domainName: "google.com"
    #   props: {
    #     port: 443
    #     tld: "com"
    #     domain: "google"
    #   }
    # }

    _.extend({},  {
      props:      @_remoteProps
      origin:     @_remoteOrigin
      strategy:   @_remoteStrategy
      visiting:   @_remoteVisitingUrl
      domainName: @_remoteDomainName
    })

  _onResolveUrl: (urlStr, automationRequest) ->
    handlingLocalFile = false
    previousState = _.clone @_getRemoteState()

    originalUrl = urlStr

    console.log buffers.getByOriginalUrl(urlStr)

    ## if we have a buffer for this url
    ## then just respond with its details
    ## so we are idempotant and do not make
    ## another request
    if obj = buffers.getByOriginalUrl(urlStr)
      ## reset the cookies from the existing stream's jar
      Request.setJarCookies(obj.jar, automationRequest)
      .then (c) ->
        return obj.details
    else
      new Promise (resolve) =>
        redirects = []

        if not fullyQualifiedRe.test(urlStr)
          handlingLocalFile = true

          @_remoteVisitingUrl = true

          @_onDomainSet(urlStr)

          urlStr = url.resolve(@_remoteOrigin, urlStr)

        error = (err) ->
          restorePreviousState()

          resolve({__error: err.message})

        getStatusText = (code) ->
          try
            statuses.getStatusText(code)
          catch e
            "Unknown Status Code"

        handleReqStream = (str) =>
          pt = str
          .on("error", error)
          .on "response", (incomingRes) =>
            jar = str.getJar()

            Request.setJarCookies(jar, automationRequest)
            .then (c) =>
              @_remoteVisitingUrl = false

              newUrl = _.last(redirects) ? urlStr

              isOkay = isOkayStatusRe.test(incomingRes.statusCode)

              details = {
                ## TODO: get a status code message here?
                ok: isOkay
                url: newUrl
                status: incomingRes.statusCode
                statusText: getStatusText(incomingRes.statusCode)
                redirects: redirects
                cookies: c
              }

              if isOkay
                ## reset the domain to the new url if we're not
                ## handling a local file
                @_onDomainSet(newUrl) if not handlingLocalFile

                buffers.set({
                  url: newUrl
                  jar: jar
                  stream: pt
                  details: details
                  originalUrl: originalUrl
                  response: incomingRes
                })
              else
                restorePreviousState()

              resolve(details)

            .catch(error)
          .pipe(stream.PassThrough())

        restorePreviousState = =>
          @_remoteProps        = previousState.props
          @_remoteOrigin       = previousState.origin
          @_remoteStrategy     = previousState.strategy
          @_remoteDomainName   = previousState.domainName
          @_remoteVisitingUrl  = previousState.visiting

        mergeHost = (curr, next) ->
          ## parse our next url
          next = url.parse(next, true)

          ## and if its missing its host
          ## then take it from the current url
          if not next.host
            curr = url.parse(curr, true)

            for prop in ["hostname", "port", "protocol"]
              next[prop] = curr[prop]

          next.format()

        Request.sendStream(automationRequest, {
          ## turn off gzip since we need to eventually
          ## rewrite these contents
          gzip: false
          url: urlStr
          followRedirect: (incomingRes) ->
            next = incomingRes.headers.location

            curr = _.last(redirects) ? urlStr

            redirects.push(mergeHost(curr, next))

            return true
        })
        .then(handleReqStream)
        .catch(error)

  _onDomainSet: (fullyQualifiedUrl) ->
    log = (type, url) ->
      logger.info("Setting #{type}", value: url)

    ## if this isn't a fully qualified url
    ## or if this came to us as <root> in our tests
    ## then we know to go back to our default domain
    ## which is the localhost server
    if fullyQualifiedUrl is "<root>" or not fullyQualifiedRe.test(fullyQualifiedUrl)
      @_remoteOrigin = "http://#{DEFAULT_DOMAIN_NAME}:#{@_server.address().port}"
      @_remoteStrategy = "file"
      @_remoteDomainName = DEFAULT_DOMAIN_NAME
      @_remoteProps = null

      log("remoteOrigin", @_remoteOrigin)
      log("remoteStrategy", @_remoteStrategy)
      log("remoteHostAndPort", @_remoteProps)
      log("remoteDocDomain", @_remoteDomainName)

    else
      parsed = url.parse(fullyQualifiedUrl)

      parsed.hash     = null
      parsed.search   = null
      parsed.query    = null
      parsed.path     = null
      parsed.pathname = null

      @_remoteOrigin = url.format(parsed)

      @_remoteStrategy = "http"

      ## set an object with port, tld, and domain properties
      ## as the remoteHostAndPort
      @_remoteProps = cors.parseUrlIntoDomainTldPort(@_remoteOrigin)

      @_remoteDomainName = _.compact([@_remoteProps.domain, @_remoteProps.tld]).join(".")

      log("remoteOrigin", @_remoteOrigin)
      log("remoteHostAndPort", @_remoteProps)
      log("remoteDocDomain", @_remoteDomainName)

    return @_getRemoteState()

  _callRequestListeners: (server, listeners, req, res) ->
    for listener in listeners
      listener.call(server, req, res)

  _normalizeReqUrl: (server) ->
    ## because socket.io removes all of our request
    ## events, it forces the socket.io traffic to be
    ## handled first.
    ## however we need to basically do the same thing
    ## it does and after we call into socket.io go
    ## through and remove all request listeners
    ## and change the req.url by slicing out the host
    ## because the browser is in proxy mode
    listeners = server.listeners("request").slice(0)
    server.removeAllListeners("request")
    server.on "request", (req, res) =>
      setProxiedUrl(req)

      @_callRequestListeners(server, listeners, req, res)

  proxyWebsockets: (proxy, socketIoRoute, req, socket, head) ->
    ## bail if this is our own namespaced socket.io request
    return if req.url.startsWith(socketIoRoute)

    if @_remoteProps and remoteOrigin = @_remoteOrigin
      ## get the hostname + port from the remoteHostPort
      {port}               = @_remoteProps
      {hostname, protocol} = url.parse(remoteOrigin)

      proxy.ws(req, socket, head, {
        secure: false
        target: {
          host: hostname
          port: port
          protocol: protocol
        }
      })
    else
      ## we can't do anything with this socket
      ## since we don't know how to proxy it!
      socket.end() if socket.writable

  _close: ->
    new Promise (resolve) =>
      logger.unsetSettings()

      ## bail early we dont have a server or we're not
      ## currently listening
      return resolve() if not @_server or not @isListening

      logger.info("Server closing")

      @_server.destroy =>
        @isListening = false
        resolve()

  close: ->
    Promise.join(
      @_close()
      @_socket?.close()
      @_httpsProxy?.close()
    )

  end: ->
    @_socket and @_socket.end()

  changeToUrl: (url) ->
    @_socket and @_socket.changeToUrl(url)

  startWebsockets: (watchers, config, options = {}) ->
    options.onDomainSet = =>
      @_onDomainSet.apply(@, arguments)

    options.onResolveUrl = (urlStr, automationRequest, cb) =>
      @_onResolveUrl(urlStr, automationRequest)
      .then(cb)

    @_socket = Socket()
    @_socket.startListening(@_server, watchers, config, options)
    @_normalizeReqUrl(@_server)
    # handleListeners(@_server)

module.exports = Server