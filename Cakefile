
child_process = require 'child_process'
fibers = require 'fibers'
fs = require 'fs'
glob = require 'glob'
mocha = require 'mocha'
sync = require 'sync'
util = require 'util'

exec = (args...) ->
  command = args.shift()
  process = child_process.spawn command, args
  process.stderr.on "data", (data) -> util.print(data.toString())
  process.stdout.on "data", (data) -> util.print(data.toString())
  fiber = fibers.current
  process.on 'exit', (code) -> fiber.run(code)
  fibers.yield()

run = (command) ->
  console.log "\u001b[35m+ " + command + "\u001b[0m"
  rv = exec("/bin/sh", "-c", command)
  if rv != 0
    console.error "\u001b[31m! Execution failed. :(\u001b[0m"
    process.exit(1)

checkfile = (file1, file2) ->
  data1 = fs.readFileSync(file1, "UTF-8")
  data2 = fs.readFileSync(file2, "UTF-8")
  if data1 != data2
    console.error "\u001b[31m! Files do not match: #{file1} <-> #{file2}\u001b[0m"
    process.exit(1)

# run a task inside a sync-capable fiber
synctask = (name, description, f) ->
  task name, description, -> (sync -> f())

## -----

emulatorFiles = [
  "emulator",
  "memory",
  "screen",
  "clock",
  "key",
  "keyboard"
]

synctask "clean", "clean", ->
  run "rm -rf lib"
  run "rm -rf js/built"

synctask "build", "build javascript", ->
  run "mkdir -p lib"
  run "coffee -o lib -c src"

synctask "test", "run unit tests", ->
  run "./node_modules/mocha/bin/mocha -R Progress --compilers coffee:coffee-script --colors"

synctask "web", "build emulator into javascript for browsers", ->
  run "mkdir -p js/built"
  files = ("src/carrot16/" + x + ".coffee" for x in emulatorFiles)
  run "coffee -o js/built -j emulator-x -c " + files.join(" ")
  run 'echo "var exports = {};" > js/built/emulator.js'
  # remove the "require" statements.
  run 'grep -v " = require" js/built/emulator-x.js >> js/built/emulator.js'
  run 'echo "var carrot16 = exports; delete exports;" >> js/built/emulator.js'
  run "rm -f js/built/emulator-x.js"
  run "cp lib/carrot16/ui.js js/built/"
