should = require 'should'
bunnyemu = require '../src/bunnyemu'

util = require "util"

pack = (op, a, b) ->
  ((a & 0x3f) << 10) | ((b & 0x1f) << 5) | (op & 0x1f)

describe "Emulator", ->
  it "nextPC", ->
    e = new bunnyemu.Emulator()
    e.registers.PC = 0x100
    e.memory[0x100] = 0x8888
    e.nextPC().should.equal(0x8888)
    e.registers.PC.should.equal(0x101)
    e.registers.PC = 0xffff
    e.memory[0xffff] = 0xf00f
    e.nextPC().should.equal(0xf00f)
    e.registers.PC.should.equal(0)

  it "push", ->
    e = new bunnyemu.Emulator()
    e.registers.SP = 0x100
    e.push(0x1234)
    e.registers.SP.should.equal(0xff)
    e.memory[0xff].should.equal(0x1234)
    e.registers.SP = 0
    e.push(0x9999)
    e.registers.SP.should.equal(0xffff)
    e.memory[0xffff].should.equal(0x9999)

  it "getPush", ->
    e = new bunnyemu.Emulator()
    e.registers.SP = 0x100
    e.memory[0xff] = 0x1234
    e.getPush().should.equal(0x1234)
    e.registers.SP.should.equal(0xff)
    e.registers.SP = 0
    e.memory[0xffff] = 0x9999
    e.getPush().should.equal(0x9999)
    e.registers.SP.should.equal(0xffff)

  it "pop", ->
    e = new bunnyemu.Emulator()
    e.registers.SP = 0
    e.memory[0] = 0x1234
    e.pop().should.equal(0x1234)
    e.registers.SP.should.equal(1)
    e.registers.SP = 0xffff
    e.memory[0xffff] = 0x9999
    e.pop().should.equal(0x9999)
    e.registers.SP.should.equal(0)

  it "readRegister", ->
    e = new bunnyemu.Emulator()
    e.registers.X = 20
    e.registers.J = 24
    e.readRegister(3).should.equal(20)
    e.readRegister(7).should.equal(24)

  describe "getValue", ->
    e = new bunnyemu.Emulator()
    it "R", ->
      e.registers.A = 9
      e.getValue(0).should.equal(9)
    it "[R]", ->
      e.registers.B = 20
      e.memory[20] = 0x9999
      e.getValue(0x09).should.equal(0x9999)
    it "[R + imm]", ->
      e.registers.C = 40
      e.registers.PC = 30
      e.memory[30] = 2
      e.memory[42] = 0x7777
      e.getValue(0x12).should.equal(0x7777)
    it "POP", ->
      e.registers.SP = 10
      e.memory[10] = 0x6666
      e.getValue(0x18).should.equal(0x6666)
      e.registers.SP.should.equal(11)
    it "PUSH", ->
      e.registers.SP = 10
      e.memory[9] = 0x5555
      e.getValue(0x18, true).should.equal(0x5555)
      e.registers.SP.should.equal(9)
    it "PEEK", ->
      e.registers.SP = 10
      e.memory[10] = 0x4444
      e.getValue(0x19).should.equal(0x4444)
      e.registers.SP.should.equal(10)
    it "PICK", ->
      e.registers.PC = 5
      e.memory[5] = 2
      e.registers.SP = 10
      e.memory[12] = 0x3333
      e.getValue(0x1a).should.equal(0x3333)
      e.registers.SP.should.equal(10)
    it "SP", ->
      e.registers.SP = 0x7400
      e.getValue(0x1b).should.equal(0x7400)
    it "PC", ->
      e.registers.PC = 0x7401
      e.getValue(0x1c).should.equal(0x7401)
    it "EX", ->
      e.registers.EX = 0x7402
      e.getValue(0x1d).should.equal(0x7402)
    it "[imm]", ->
      e.registers.PC = 500
      e.memory[500] = 600
      e.memory[600] = 0x2222
      e.getValue(0x1e).should.equal(0x2222)
    it "imm", ->
      e.registers.PC = 500
      e.memory[500] = 600
      e.memory[600] = 0x2222
      e.getValue(0x1f).should.equal(600)

  describe "special ops", ->
    e = new bunnyemu.Emulator()

    it "JSR", ->
      e.registers.PC = 10
      e.memory[10] = pack(0, 0, 1)
      e.registers.A = 0x9898
      e.registers.SP = 0x100
      e.step()
      e.registers.PC.should.equal(0x9898)
      e.memory[0xff].should.equal(11)


