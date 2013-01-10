should = require 'should'
bunnyemu = require '../src/bunnyemu'

util = require "util"

describe "RangeMap", ->
  it "finds a single value", ->
    m = new bunnyemu.RangeMap()
    m.add(10, 11, "hello")
    m.get(9).should.eql([])
    m.get(10).should.eql([ "hello" ])
    m.get(11).should.eql([])

  it "can handle 2 identical ranges", ->
    m = new bunnyemu.RangeMap()
    h = m.add(10, 11, "hello")
    g = m.add(10, 11, "goodbye")
    m.get(10).should.eql([ "hello", "goodbye" ])

  it "can remove ranges", ->
    m = new bunnyemu.RangeMap()
    h = m.add(10, 11, "hello")
    g = m.add(10, 11, "goodbye")
    m.get(10).should.eql([ "hello", "goodbye" ])
    m.remove(h)
    m.get(10).should.eql([ "goodbye" ])
    m.remove(g)
    m.get(10).should.eql([])

  it "can have several overlapping and non-overlapping ranges", ->
    m = new bunnyemu.RangeMap()
    m.add(10, 30, "alpha")
    m.add(20, 32, "beta")
    m.add(15, 20, "gamma")
    m.add(50, 55, "delta")
    m.get(5).should.eql([])
    m.get(10).should.eql([ "alpha" ])
    m.get(13).should.eql([ "alpha" ])
    m.get(15).should.eql([ "alpha", "gamma" ])
    m.get(19).should.eql([ "alpha", "gamma" ])
    m.get(20).should.eql([ "alpha", "beta" ])
    m.get(30).should.eql([ "beta" ])
    m.get(32).should.eql([])
    m.get(50).should.eql([ "delta" ])
    m.get(51).should.eql([ "delta" ])
    m.get(55).should.eql([])
    m.get(60).should.eql([])

describe "Memory", ->
  it "starts blank", ->
    m = new bunnyemu.Memory()
    m.get(10).should.eql(0)

  it "get and set", ->
    m = new bunnyemu.Memory()
    m.set(10, 20)
    m.get(10).should.eql(20)

  it "clear", ->
    m = new bunnyemu.Memory()
    m.set(10, 20)
    m.get(10).should.eql(20)
    m.clear()
    m.get(10).should.eql(0)

  it "16 bit", ->
    m = new bunnyemu.Memory()
    m.set(10, 0x12345)
    m.get(10).should.eql(0x2345)

  it "triggers read watches", ->
    m = new bunnyemu.Memory()
    reads = []
    watch = m.watchReads 10, 20, (addr) -> reads.push(addr)
    m.get(5).should.equal(0)
    reads.should.eql([])
    m.get(10).should.equal(0)
    reads.should.eql([ 10 ])
    m.peek(10).should.equal(0)
    reads.should.eql([ 10 ])
    m.get(10).should.equal(0)
    reads.should.eql([ 10, 10 ])
    m.unwatchReads(watch)
    m.get(10).should.equal(0)
    reads.should.eql([ 10, 10 ])

  it "triggers write watches", ->
    m = new bunnyemu.Memory()
    writes = []
    watch = m.watchWrites 10, 20, (addr) -> writes.push(addr)
    m.set(5, 1)
    writes.should.eql([])
    m.set(10, 1)
    writes.should.eql([ 10 ])
    m.set(10, 1)
    writes.should.eql([ 10, 10 ])
    m.get(10).should.equal(1)
    writes.should.eql([ 10, 10 ])
    m.unwatchWrites(watch)
    m.set(10, 2)
    writes.should.eql([ 10, 10 ])

