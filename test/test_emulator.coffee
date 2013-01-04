should = require 'should'
bunnyemu = require '../src/bunnyemu'

util = require "util"

pack = (op, a, b) ->
  ((a & 0x3f) << 10) | ((b & 0x1f) << 5) | (op & 0x1f)

preload = (e, op, a, b) ->
  e.registers.PC = 0x10
  e.memory[e.registers.PC] = pack(op, a, b)

preloadSpecial = (e, op, a) -> preload(e, 0, a, op)
  
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

  describe "fetchOperand", ->
    e = new bunnyemu.Emulator()
    it "R", ->
      e.registers.A = 9
      e.fetchOperand(0).should.equal(9)
    it "[R]", ->
      e.registers.B = 20
      e.memory[20] = 0x9999
      e.fetchOperand(0x09).should.equal(0x9999)
    it "[R + imm]", ->
      e.registers.C = 40
      e.registers.PC = 30
      e.memory[30] = 2
      e.memory[42] = 0x7777
      e.fetchOperand(0x12).should.equal(0x7777)
    it "POP", ->
      e.registers.SP = 10
      e.memory[10] = 0x6666
      e.fetchOperand(0x18).should.equal(0x6666)
      e.registers.SP.should.equal(11)
    it "PUSH", ->
      e.registers.SP = 10
      e.memory[9] = 0x5555
      e.fetchOperand(0x18, true).should.equal(0x5555)
      e.registers.SP.should.equal(9)
    it "PEEK", ->
      e.registers.SP = 10
      e.memory[10] = 0x4444
      e.fetchOperand(0x19).should.equal(0x4444)
      e.registers.SP.should.equal(10)
    it "PICK", ->
      e.registers.PC = 5
      e.memory[5] = 2
      e.registers.SP = 10
      e.memory[12] = 0x3333
      e.fetchOperand(0x1a).should.equal(0x3333)
      e.registers.SP.should.equal(10)
    it "SP", ->
      e.registers.SP = 0x7400
      e.fetchOperand(0x1b).should.equal(0x7400)
    it "PC", ->
      e.registers.PC = 0x7401
      e.fetchOperand(0x1c).should.equal(0x7401)
    it "EX", ->
      e.registers.EX = 0x7402
      e.fetchOperand(0x1d).should.equal(0x7402)
    it "[imm]", ->
      e.registers.PC = 500
      e.memory[500] = 600
      e.memory[600] = 0x2222
      e.fetchOperand(0x1e).should.equal(0x2222)
    it "imm", ->
      e.registers.PC = 500
      e.memory[500] = 600
      e.memory[600] = 0x2222
      e.fetchOperand(0x1f).should.equal(600)

  describe "storeOperand", ->
    e = new bunnyemu.Emulator()
    it "R", ->
      e.storeOperand(0, 9)
      e.registers.A.should.equal(9)
    it "[R]", ->
      e.registers.B = 20
      e.storeOperand(0x09, 0x9999)
      e.memory[20].should.equal(0x9999)
    it "[R + imm]", ->
      e.registers.C = 40
      e.registers.PC = 30
      e.memory[30] = 2
      e.fetchOperand(0x12, true)
      e.storeOperand(0x12, 0x7777)
      e.memory[42].should.equal(0x7777)
    it "PUSH", ->
      e.registers.SP = 10
      e.storeOperand(0x18, 0x5555)
      e.memory[9].should.equal(0x5555)
      e.registers.SP.should.equal(9)
    it "PEEK", ->
      e.registers.SP = 10
      e.storeOperand(0x19, 0x4444)
      e.memory[10].should.equal(0x4444)
      e.registers.SP.should.equal(10)
    it "PICK", ->
      e.registers.PC = 5
      e.memory[5] = 2
      e.registers.SP = 10
      e.fetchOperand(0x1a, true)
      e.storeOperand(0x1a, 0x3333)
      e.memory[12].should.equal(0x3333)
      e.registers.SP.should.equal(10)
    it "SP", ->
      e.storeOperand(0x1b, 0x7400)
      e.registers.SP.should.equal(0x7400)
    it "PC", ->
      e.storeOperand(0x1c, 0x7401)
      e.registers.PC.should.equal(0x7401)
    it "EX", ->
      e.storeOperand(0x1d, 0x7402)
      e.registers.EX.should.equal(0x7402)
    it "[imm]", ->
      e.registers.PC = 500
      e.memory[500] = 600
      e.fetchOperand(0x1e, true)
      e.storeOperand(0x1e, 0x2222)
      e.memory[600].should.equal(0x2222)

  describe "special ops", ->
    e = new bunnyemu.Emulator()
    e.hardware = [ new bunnyemu.Hardware(0x22334455, 2, 0x66779988), new bunnyemu.Hardware(0x12341234, 1, 0x56785678) ]

    it "JSR", ->
      preloadSpecial(e, 0x01, 0)
      e.registers.A = 0x9898
      e.registers.SP = 0x100
      e.step()
      e.registers.PC.should.equal(0x9898)
      e.memory[0xff].should.equal(0x11)

    it "INT", ->
      preloadSpecial(e, 0x08, 0x01)
      e.registers.B = 9
      e.step()
      e.interruptQueue.should.eql([ 9 ])
      # now trigger it
      e.registers.A = 99
      e.registers.IA = 0xf333
      e.registers.SP = 0x100
      e.memory[0xf333] = 0
      e.step()
      e.registers.PC.should.equal(0xf334)
      e.registers.A.should.equal(9)
      e.registers.SP.should.equal(0xfe)
      e.memory[0xff].should.equal(0x11)
      e.memory[0xfe].should.equal(99)

    it "IAG", ->
      preloadSpecial(e, 0x09, 0x03)
      e.registers.IA = 0x4321
      e.step()
      e.registers.X.should.equal(0x4321)

    it "IAS", ->
      preloadSpecial(e, 0x0a, 0x05)
      e.registers.Z = 0x4322
      e.step()
      e.registers.IA.should.equal(0x4322)

    it "RFI", ->
      preloadSpecial(e, 0x0b, 0)
      e.registers.SP = 0x100
      e.memory[0x100] = 90
      e.memory[0x101] = 91
      e.step()
      e.registers.A.should.equal(90)
      e.registers.PC.should.equal(91)

    it "IAQ", ->
      preloadSpecial(e, 0x0c, 7)
      e.registers.J = 1
      e.queueing = false
      e.step()
      e.queueing.should.equal(true)
      preloadSpecial(e, 0x0c, 7)
      e.registers.J = 0
      e.step()
      e.queueing.should.equal(false)

    it "HWN", ->
      preloadSpecial(e, 0x10, 6)
      e.step()
      e.registers.I.should.equal(2)

    it "HWQ", ->
      preloadSpecial(e, 0x11, 0)
      e.registers.A = 0
      e.step()
      e.registers.A.should.equal(0x4455)
      e.registers.B.should.equal(0x2233)
      e.registers.C.should.equal(2)
      e.registers.X.should.equal(0x9988)
      e.registers.Y.should.equal(0x6677)
      # don't spaz out if HWQ refers to nonexistent hardware:
      preloadSpecial(e, 0x11, 0)
      e.registers.A = 2
      e.step()
      e.registers.A.should.equal(0)
      e.registers.B.should.equal(0)
      e.registers.C.should.equal(0)
      e.registers.X.should.equal(0)
      e.registers.Y.should.equal(0)

    it "HWI", ->
      e.hardware[1].request = (emu) ->
        emu.registers.Z = 0xeeee
        30
      preloadSpecial(e, 0x12, 0)
      e.cycles = 0
      e.registers.A = 1
      e.step()
      e.registers.Z.should.equal(0xeeee)
      e.cycles.should.equal(30)

