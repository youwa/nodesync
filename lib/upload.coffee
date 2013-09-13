http = require 'http'
fs = require 'fs'
FormData = require 'form-data'


remote =
  connect: (host, pathTo) ->
    @host = host
    @pathTo = pathTo
    do @post

  _prepareHTTP: (headers)->
    @option.headers = headers
    self = @

    req = http.request @option

    req.on 'response', (res) ->
      if not self.connected
        self.connected = true
        console.info "Server: >>>\n\tSuccecc Connected!"
      else
        console.info "Server: >>>"

      res.setEncoding 'utf8'
      res.on 'data', (chunk)->
        console.info "   #{res.statusCode}:\t\u001b[1;36m#{chunk}\u001b[0m"
        console.log ""
    req.on 'error', (err)->

      console.error "#{err.code} 无法连接 \"#{self.option.host}\" ..."
      console.error err

    return req

  post: (opts) ->
    self = @
    form = new FormData()
    for key, value of opts
      #if the value is empty will cause form_data.js error
      form.append key, value if value

    #form.pipe (@_prepareHTTP form.getHeaders())
    form.submit(@host, (err, res)->
      if err
        # connect failed
        console.error "\t#{err}"
        return

      if not self.connected
        self.connected = true
        console.info "Server: >>>\n\tSuccecc Connected!"
      else
        console.info "Server: >>> #{res.statusCode}"

      res.on 'data', (chunk)->
        data = JSON.parse chunk
        console.info " #{data.code}:\t\u001b[1;36m#{data.msg}\u001b[0m"
        console.log ""
    )

  _debugInfo: (event, filepath)->
    # send module used for debug
    console.log "  send:\t >>>>>>>>"
    console.log "\t      op: \u001b[1;4m#{event}\u001b[0m"
    console.log "\t  pathto: #{@pathTo}"
    console.log "\tfilepath: #{filepath}"
    console.log ""

  save: (fp, oid) ->
    @_debugInfo 'change', fp

    @post
      op: 'change'
      to: @pathTo
      filepath: fp

      md5: oid
      file: fs.createReadStream(fp)

  mkdir: (dir) ->
    @_debugInfo 'mkdir', dir


    @post
      op: 'mkdir'
      to: @pathTo
      filepath: dir

  delete: (fp, oid)->
    @_debugInfo 'del', fp

    @post
      op: "del"
      to: @pathTo
      filepath: fp

  move: (fp, oid, nfp) ->
    @_debugInfo 'mv', "move #{fp} to #{nfp}"

    @post
      op: 'mv'
      to: @pathTo
      filepath: fp
      target: nfp
      oid: oid

module.exports = remote