fs = require 'fs'
path = require 'path'
watch = require "watch-project"
jch = require "jch"
program = require 'commander'
remote = require './upload'
fc = require './filechange'
config = require './config'


###
  colors for out put
###

console.error = (s)->
  console.log("\u001b[1;31m#{s}\u001b[0m")
# used for log messages generated by other program
console.info = (s)->
  console.log "\u001b[36m#{s}\u001b[0m"
# used for log important messages
console.warn = (s)->
  console.log "\u001b[35m#{s}\u001b[0m"


###
  start watching for the project directory
###

startWatch = (opts)->
  # check watch target file exists
  if not fs.existsSync opts.path
    console.error "Error: "
    console.log "\tDirectory '#{ opts.path }' to watch is not Exist!"
    return


  # init local
  console.warn "[Beta Mode Enable: works well on linux]" if opts.beta
  console.log "Local : >>>"
  console.log "\tWatching : '#{opts.path}'"
  console.log "\tConnect to: '#{opts.host}'"
  #console.log "\tConnecting ... '#{opts.host}'"
  console.log ""

  # init server
  remote.connect opts.host, opts.pathto, opts.force, opts.debug

  #init flie filter
  if opts.ignore
    filter = new Filter (opts.ignore and opts.ignore.replace(/,\s/g, ",").split(','))
    preCheck = (s)->
      filter.match(s)
  else
    preCheck = ()->
      return false

  #dispatch events occured during the program is not running
  #watch.ready ()->
  #  fs.readFile '.m3ddata', {encoding: 'utf-8'}, (err, data)->
  #    return if err
  #    fc.dispatchEvent watch, data


  watch opts.path,
    stable: !opts.beta
    withHidden: opts.hidden
  , (e)->
    #filter ignored files
    if preCheck (path.basename(e.filename))
      return

    #console.log '\u001b[1;4;35m>>>>>>>>>>>>>>>>>>>\u001b[0m'
    console.log "[#{(new Date()).toTimeString().slice(0,8)}] Local: >>>\u001b[1;4m#{e.type}\u001b[0m [#{e.filename}]"
    if opts.debug
      console.log "   old:\t#{e.oid}"
      console.log "   new:\t#{e.nid || e.oid}"

    switch e.type
      when 'mkdir'
        remote.mkdir e.filename
      when 'change', 'create'
        remote.save e.filename, e.oid
        if (path.basename e.filename)[0...3] is 'jch'
          jch.parse(e.filename)
      when 'delete', 'rmdir'
        remote.delete e.filename, e.oid
      when 'mvfile', 'mvdir'
        remote.move e.oname, e.oid, e.filename
      else


  #save watch status for trigger change events next time
  process.on 'SIGINT', ()->
    #fs.writeFileSync '.m3ddata', watch.status()
    do process.exit


###
  prepare for watching the project directory
###

initMain = ()->

  program
    .option('', '')
    .option('resolve', 'resolve file conflict through svn')
    .option('config', 'modify configuration file')
    .option('', '')
    .option('-f, --force', 'force sync mode, without checking file\'s MD5')
    .option('-h, --hidden', 'watch hidden files and dirs as well')
    .option('-b, --beta', 'beta version, only stable on linux')
    .option('-d, --debug', 'show more detailed debug info')
    .version('0.0.12', '-v, --version')


  params = program.parse(process.argv)

  conf = config.load( path.resolve('.m3dsync_config') )
  # first running this program, will ask user to input configuration informatin rather than start watching
  if conf
    #
    for key, value of conf
      params[key] ?= value

    # startWatch
    startWatch(params)


###
  run different part of the nodesync program, such as resolve conflicts ...
###
parseArgv = ()->
  program
  switch process.argv[2]
    when 'resolve'
      console.log "resolve conflict!"
      # fix sync error through svn
    when 'config'
      confFile = path.resolve '.m3dsync_config'
      if fs.existsSync confFile
        config.create (path.resolve '.m3dsync_config')
      else
        config.create()
    else
      # enter the main sync program
      initMain()

module.exports.run = parseArgv



### #   # ##### ##### ####   #   #   #   #
 #  ##  #   #   #     #   #  ##  #       #
 #  # # #   #   ####  #  #   # # #  ###  #
 #  #  ##   #   #     #   #  #  ##       #
### #   #   #   ##### #    # #   # #   # #####

# matched pattern container solving IDs with same length such as ".swp" and ".bak"
class MatchContainer
  constructor: ()->
    # used to store ids with same length
    #@idList = {}

  add: (val)->
    l = val.length
    if @[l]
      @[l][val] = true
    else
      @[l] = {}
      @[l][val] = true


# check if a filename matched
class Filter
  constructor: (@config)->
    @_prepare()

  _prepare: ()->
    @leftMatch = new MatchContainer()
    @rightMatch = new MatchContainer()
    @totalMatch = new MatchContainer()
    for val in @config
      if val[0] is "*"
        # right hand check list
        @rightMatch.add(val[1...])
      else if val[-1..] is "*"
        # left hand ckeck list
        @leftMatch.add(val[0...-1])
      else
        @totalMatch[val.length] = val

  match: (s)->
    l = s.length
    # right side check first for it's much common
    for len, lenMatchList of @rightMatch
      break if len >= l
      return true if lenMatchList[ s.slice(-len) ]

    # left side check
    for len, lenMatchList of @leftMatch
      break if len >= l
      return true if lenMatchList[ s.slice(0, len) ]

    # full check
    return true if @totalMatch[l]
    return false