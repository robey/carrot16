
# a map of numerical ranges: (start, end] -> object
# given a number, we can find all ranges that span it.
# keys (ranges) do not have to be unique, and may overlap partially or completely.
class RangeMap
  constructor: ->
    @id = 1
    # internally, entries are (id -> range) and (id -> obj)
    @rangeMap = {}
    @objMap = {}
    # sorted caches for quick searching:
    @clearCache()
  
  clearCache: ->
    @startList = null
    @endList = null

  buildCache: ->
    @startList = ([ k[0], v ] for k, v of @rangeMap).sort (a, b) -> a[0] - b[0]
    @endList = ([ k[1], v ] for k, v of @rangeMap).sort (a, b) -> a[0] - b[0]

  intersect: (a, b) ->
    a = a.sort()
    b = b.sort()
    rv = []
    ai = 0
    bi = 0
    while ai < a.length and bi < b.length
      if a[ai] < b[bi]
        ai += 1
      else if a[ai] > b[bi]
        bi += 1
      else
        rv.push(a[ai])
        ai += 1
        bi += 1
    rv

  # returns a key which may be used to remove the range later.
  add: (start, end, obj) ->
    id = @id
    @id += 1
    @rangeMap[id] = [ start, end ]
    @objMap[id] = obj
    @clearCache()
    id

  get: (n) ->
    if not @startList? then @buildCache()
    if @startList.length == 0 then return []
    rv1 = []
    index = 0
    while index < @startList.length and @startList[index][0] <= n
      rv1.push @startList[index][1]
      index += 1
    if rv1.length == 0 then return []
    rv2 = []
    index = @endList.length - 1
    while index >= 0 and @endList[index][0] > n
      rv1.push @endList[index][1]
      index -= 1
    if rv2.length == 0 then return []
    @intersect(rv1, rv2)




# memory isn't technically a piece of "hardware" on the DCPU, but lots of
# things touch it, so it's convenient to abstract it out.
class Memory
  constructor: ->
    @memory = []

  clear: ->
    for i in [0 ... 0x10000] then if @memory[i] then @memory[i] = 0

exports.RangeMap = RangeMap
exports.Memory = Memory
