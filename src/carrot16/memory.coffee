
# a map of numerical ranges: (start, end] -> object
# given a number, we can find all ranges that span it.
# keys (ranges) do not have to be unique, and may overlap partially or completely.
class RangeMap
  constructor: ->
    @id = 1
    # internally, entries are (id -> range) and (id -> obj)
    @rangeMap = {}
    @objMap = {}

  # returns a key which may be used to remove the range later.
  add: (start, end, obj) ->
    id = @id
    @id += 1
    @rangeMap[id] = [ start, end ]
    @objMap[id] = obj
    id

  remove: (id) ->
    delete @rangeMap[id]
    delete @objMap[id]

  get: (n) ->
    objs = []
    for k, v of @rangeMap
      if n >= v[0] and n < v[1] then objs.push(@objMap[k])
    objs

# memory isn't technically a piece of "hardware" on the DCPU, but lots of
# things touch it, so it's convenient to abstract it out.
class Memory
  constructor: ->
    @memory = []
    @readWatches = new RangeMap()
    @writeWatches = new RangeMap()

  clear: ->
    for i in [0 ... 0x10000] then if @memory[i] then @memory[i] = 0

  flash: (buffer) ->
    @memory = buffer

  get: (n) ->
    @readWatches.get(n).map (f) => f(n)
    @peek(n)

  peek: (n) ->
    (@memory[n & 0xffff] or 0) & 0xffff

  set: (n, value) ->
    @writeWatches.get(n).map (f) => f(n)
    @memory[n & 0xffff] = (value & 0xffff)

  watchReads: (start, end, callback) ->
    @readWatches.add(start, end, callback)

  unwatchReads: (id) ->
    @readWatches.remove(id)

  watchWrites: (start, end, callback) ->
    @writeWatches.add(start, end, callback)

  unwatchWrites: (id) ->
    @writeWatches.remove(id)


exports.RangeMap = RangeMap
exports.Memory = Memory
