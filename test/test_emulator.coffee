should = require 'should'
carrot16 = require '../src/carrot16'

util = require "util"

pack = (op, b, a) ->
  ((a & 0x3f) << 10) | ((b & 0x1f) << 5) | (op & 0x1f)

preload = (e, op, b, a) ->
  e.registers.PC = 0x10
  e.memory.set(e.registers.PC, pack(op, b, a))

preloadNext = (e, n, op, b, a) ->
  e.memory.set(e.registers.PC + n, pack(op, b, a))

preloadData = (e, n, data) ->
  e.memory.set(e.registers.PC + n, data)

preloadSpecial = (e, op, a) -> preload(e, 0, op, a)
  
describe "Emulator", ->
  it "nextPC", ->
    e = new carrot16.Emulator()
    e.registers.PC = 0x100
    e.memory.set(0x100, 0x8888)
    e.nextPC().should.equal(0x8888)
    e.registers.PC.should.equal(0x101)
    e.registers.PC = 0xffff
    e.memory.set(0xffff, 0xf00f)
    e.nextPC().should.equal(0xf00f)
    e.registers.PC.should.equal(0)

  it "push", ->
    e = new carrot16.Emulator()
    e.registers.SP = 0x100
    e.push(0x1234)
    e.registers.SP.should.equal(0xff)
    e.memory.get(0xff).should.equal(0x1234)
    e.registers.SP = 0
    e.push(0x9999)
    e.registers.SP.should.equal(0xffff)
    e.memory.get(0xffff).should.equal(0x9999)

  it "getPush", ->
    e = new carrot16.Emulator()
    e.registers.SP = 0x100
    e.memory.set(0xff, 0x1234)
    e.getPush().should.equal(0x1234)
    e.registers.SP.should.equal(0xff)
    e.registers.SP = 0
    e.memory.set(0xffff, 0x9999)
    e.getPush().should.equal(0x9999)
    e.registers.SP.should.equal(0xffff)

  it "pop", ->
    e = new carrot16.Emulator()
    e.registers.SP = 0
    e.memory.set(0, 0x1234)
    e.pop().should.equal(0x1234)
    e.registers.SP.should.equal(1)
    e.registers.SP = 0xffff
    e.memory.set(0xffff, 0x9999)
    e.pop().should.equal(0x9999)
    e.registers.SP.should.equal(0)

  it "readRegister", ->
    e = new carrot16.Emulator()
    e.registers.X = 20
    e.registers.J = 24
    e.readRegister(3).should.equal(20)
    e.readRegister(7).should.equal(24)

  it "skip", ->
    e = new carrot16.Emulator()
    # skip normal op
    e.registers.PC = 0
    e.memory.set(0, pack(0, 0, 0))
    e.skip()
    e.registers.PC.should.equal(1)
    # skip branch
    e.registers.PC = 0
    e.memory.set(0, pack(0x10, 0x1, 0x2))
    e.skip()
    e.registers.PC.should.equal(2)
    # skip several branches
    e.registers.PC = 0
    e.memory.set(0, pack(0x10, 0x1, 0x2))
    e.memory.set(1, pack(0x12, 0x1, 0x2))
    e.memory.set(2, pack(0x11, 0x1, 0x2))
    e.skip()
    e.registers.PC.should.equal(4)
    # skip opcodes with immediates
    e.registers.PC = 0
    e.memory.set(0, pack(0x01, 0x10, 0x1e))
    e.skip()
    e.registers.PC.should.equal(3)

  describe "fetchOperand", ->
    e = new carrot16.Emulator()
    it "R", ->
      e.registers.A = 9
      e.fetchOperand(0).should.equal(9)
    it "[R]", ->
      e.registers.B = 20
      e.memory.set(20, 0x9999)
      e.fetchOperand(0x09).should.equal(0x9999)
    it "[R + imm]", ->
      e.registers.C = 40
      e.registers.PC = 30
      e.memory.set(30, 2)
      e.memory.set(42, 0x7777)
      e.fetchOperand(0x12).should.equal(0x7777)
    it "POP", ->
      e.registers.SP = 10
      e.memory.set(10, 0x6666)
      e.fetchOperand(0x18).should.equal(0x6666)
      e.registers.SP.should.equal(11)
    it "PUSH", ->
      e.registers.SP = 10
      e.memory.set(9, 0x5555)
      e.fetchOperand(0x18, true).should.equal(0x5555)
      e.registers.SP.should.equal(9)
    it "PEEK", ->
      e.registers.SP = 10
      e.memory.set(10, 0x4444)
      e.fetchOperand(0x19).should.equal(0x4444)
      e.registers.SP.should.equal(10)
    it "PICK", ->
      e.registers.PC = 5
      e.memory.set(5, 2)
      e.registers.SP = 10
      e.memory.set(12, 0x3333)
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
      e.memory.set(500, 600)
      e.memory.set(600, 0x2222)
      e.fetchOperand(0x1e).should.equal(0x2222)
    it "imm", ->
      e.registers.PC = 500
      e.memory.set(500, 600)
      e.memory.set(600, 0x2222)
      e.fetchOperand(0x1f).should.equal(600)

  describe "storeOperand", ->
    e = new carrot16.Emulator()
    it "R", ->
      e.storeOperand(0, 9)
      e.registers.A.should.equal(9)
    it "[R]", ->
      e.registers.B = 20
      e.storeOperand(0x09, 0x9999)
      e.memory.get(20).should.equal(0x9999)
    it "[R + imm]", ->
      e.registers.C = 40
      e.registers.PC = 30
      e.memory.set(30, 2)
      e.fetchOperand(0x12, true)
      e.storeOperand(0x12, 0x7777)
      e.memory.get(42).should.equal(0x7777)
    it "PUSH", ->
      e.registers.SP = 10
      e.storeOperand(0x18, 0x5555)
      e.memory.get(9).should.equal(0x5555)
      e.registers.SP.should.equal(9)
    it "PEEK", ->
      e.registers.SP = 10
      e.storeOperand(0x19, 0x4444)
      e.memory.get(10).should.equal(0x4444)
      e.registers.SP.should.equal(10)
    it "PICK", ->
      e.registers.PC = 5
      e.memory.set(5, 2)
      e.registers.SP = 10
      e.fetchOperand(0x1a, true)
      e.storeOperand(0x1a, 0x3333)
      e.memory.get(12).should.equal(0x3333)
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
      e.memory.set(500, 600)
      e.fetchOperand(0x1e, true)
      e.storeOperand(0x1e, 0x2222)
      e.memory.get(600).should.equal(0x2222)

  describe "special ops", ->
    e = new carrot16.Emulator()
    e.hardware = [ new carrot16.Hardware(0x22334455, 2, 0x66779988), new carrot16.Hardware(0x12341234, 1, 0x56785678) ]

    it "JSR", ->
      preloadSpecial(e, 0x01, 0)
      e.registers.A = 0x9898
      e.registers.SP = 0x100
      e.step()
      e.registers.PC.should.equal(0x9898)
      e.memory.get(0xff).should.equal(0x11)

    it "INT", ->
      preloadSpecial(e, 0x08, 0x01)
      e.registers.B = 9
      e.step()
      e.interruptQueue.should.eql([ 9 ])
      # now trigger it
      e.registers.A = 99
      e.registers.IA = 0xf333
      e.registers.SP = 0x100
      e.memory.set(0xf333, 0)
      e.step()
      e.registers.PC.should.equal(0xf334)
      e.registers.A.should.equal(9)
      e.registers.SP.should.equal(0xfe)
      e.memory.get(0xff).should.equal(0x11)
      e.memory.get(0xfe).should.equal(99)

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
      e.memory.set(0x100, 90)
      e.memory.set(0x101, 91)
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
      e.cycles.should.equal(34)

  describe "binary ops", ->
    e = new carrot16.Emulator()

    it "SET", ->
      preload(e, 0x01, 0x03, 0x04)
      e.registers.X = 5
      e.registers.Y = 12
      e.step()
      e.registers.X.should.equal(12)

    it "ADD", ->
      preload(e, 0x02, 0x03, 0x04)
      e.registers.X = 5
      e.registers.Y = 12
      e.step()
      e.registers.X.should.equal(17)

    it "SUB", ->
      preload(e, 0x03, 0x03, 0x04)
      e.registers.X = 15
      e.registers.Y = 12
      e.step()
      e.registers.X.should.equal(3)

    it "MUL", ->
      preload(e, 0x04, 0x03, 0x04)
      e.registers.X = 1500
      e.registers.Y = 1200
      e.step()
      e.registers.X.should.equal(30528)
      e.registers.EX.should.equal(27)

    it "MLI", ->
      preload(e, 0x05, 0x03, 0x04)
      e.registers.X = (-1500) & 0xffff
      e.registers.Y = 1200
      e.step()
      # unclear to me how useful this would be inside DCPU.
      e.registers.X.should.equal((-30528) & 0xffff)
      e.registers.EX.should.equal((27) ^ 0xffff)

    it "DIV", ->
      preload(e, 0x06, 0x03, 0x04)
      e.registers.X = 1500
      e.registers.Y = 1200
      e.step()
      e.registers.X.should.equal(1)
      e.registers.EX.should.equal(16384)

    it "DVI", ->
      preload(e, 0x07, 0x03, 0x04)
      e.registers.X = (-1500) & 0xffff
      e.registers.Y = 1200
      e.step()
      e.registers.X.should.equal((-1) & 0xffff)
      e.registers.EX.should.equal(49152)

    it "MOD", ->
      preload(e, 0x08, 0x03, 0x04)
      e.registers.X = 1500
      e.registers.Y = 1200
      e.step()
      e.registers.X.should.equal(300)

    it "MDI", ->
      preload(e, 0x09, 0x03, 0x04)
      e.registers.X = (-7) & 0xffff
      e.registers.Y = 16
      e.step()
      e.registers.X.should.equal((-7) & 0xffff)

    it "AND", ->
      preload(e, 0x0a, 0x03, 0x04)
      e.registers.X = 0xff77
      e.registers.Y = 0x9191
      e.step()
      e.registers.X.should.equal(0x9111)

    it "BOR", ->
      preload(e, 0x0b, 0x03, 0x04)
      e.registers.X = 0x0f0f
      e.registers.Y = 0x9191
      e.step()
      e.registers.X.should.equal(0x9f9f)

    it "XOR", ->
      preload(e, 0x0c, 0x03, 0x04)
      e.registers.X = 0xffff
      e.registers.Y = 0x9191
      e.step()
      e.registers.X.should.equal(0x6e6e)

    it "SHR", ->
      preload(e, 0x0d, 0x03, 0x04)
      e.registers.X = 0x1234
      e.registers.Y = 4
      e.step()
      e.registers.X.should.equal(0x123)
      e.registers.EX.should.equal(0x4000)

    it "ASR", ->
      preload(e, 0x0e, 0x03, 0x04)
      e.registers.X = 0xf999
      e.registers.Y = 4
      e.step()
      e.registers.X.should.equal(0xff99)
      e.registers.EX.should.equal(0x9000)

    it "SHL", ->
      preload(e, 0x0f, 0x03, 0x04)
      e.registers.X = 0x1234
      e.registers.Y = 4
      e.step()
      e.registers.X.should.equal(0x2340)
      e.registers.EX.should.equal(0x1)

    it "ADX", ->
      preload(e, 0x1a, 0x03, 0x04)
      e.registers.X = 0x1111
      e.registers.Y = 0x2222
      e.registers.EX = 0xf444
      e.step()
      e.registers.X.should.equal(0x2777)
      e.registers.EX.should.equal(1)

    it "SBX", ->
      preload(e, 0x1b, 0x03, 0x04)
      e.registers.X = 0x1111
      e.registers.Y = 0x2222
      e.registers.EX = 1
      e.step()
      e.registers.X.should.equal((- 0x1110) & 0xffff)
      e.registers.EX.should.equal(0xffff)

  describe "conditional ops", ->
    e = new carrot16.Emulator()

    it "IFB", ->
      preload(e, 0x10, 0x03, 0x04)
      e.registers.X = 0x0001
      e.registers.Y = 0xffff
      e.step()
      e.registers.PC.should.equal(0x11)
      preload(e, 0x10, 0x03, 0x04)
      e.registers.X = 0x0001
      e.registers.Y = 0xfff0
      e.step()
      e.registers.PC.should.equal(0x12)

    it "IFC", ->
      preload(e, 0x11, 0x03, 0x04)
      e.registers.X = 0x0001
      e.registers.Y = 0xffff
      e.step()
      e.registers.PC.should.equal(0x12)
      preload(e, 0x11, 0x03, 0x04)
      e.registers.X = 0x0001
      e.registers.Y = 0xfff0
      e.step()
      e.registers.PC.should.equal(0x11)

    it "IFE", ->
      preload(e, 0x12, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2343
      e.step()
      e.registers.PC.should.equal(0x11)
      preload(e, 0x12, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2399
      e.step()
      e.registers.PC.should.equal(0x12)

    it "IFN", ->
      preload(e, 0x13, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2343
      e.step()
      e.registers.PC.should.equal(0x12)
      preload(e, 0x13, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2399
      e.step()
      e.registers.PC.should.equal(0x11)

    it "IFG", ->
      preload(e, 0x14, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2300
      e.step()
      e.registers.PC.should.equal(0x11)
      preload(e, 0x14, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2399
      e.step()
      e.registers.PC.should.equal(0x12)

    it "IFA", ->
      preload(e, 0x15, 0x03, 0x04)
      e.registers.X = (-10) & 0xffff
      e.registers.Y = 10
      e.step()
      e.registers.PC.should.equal(0x12)
      preload(e, 0x15, 0x03, 0x04)
      e.registers.X = 10
      e.registers.Y = (-10) & 0xffff
      e.step()
      e.registers.PC.should.equal(0x11)

    it "IFL", ->
      preload(e, 0x16, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2300
      e.step()
      e.registers.PC.should.equal(0x12)
      preload(e, 0x16, 0x03, 0x04)
      e.registers.X = 0x2343
      e.registers.Y = 0x2399
      e.step()
      e.registers.PC.should.equal(0x11)

    it "IFU", ->
      preload(e, 0x17, 0x03, 0x04)
      e.registers.X = (-10) & 0xffff
      e.registers.Y = 10
      e.step()
      e.registers.PC.should.equal(0x11)
      preload(e, 0x17, 0x03, 0x04)
      e.registers.X = 10
      e.registers.Y = (-10) & 0xffff
      e.step()
      e.registers.PC.should.equal(0x12)

  describe "block move ops", ->
    e = new carrot16.Emulator()

    it "STI", ->
      preload(e, 0x1e, 0x0e, 0x0f)
      e.registers.I = 100
      e.registers.J = 200
      e.memory.set(100, 0x4545)
      e.memory.set(200, 0xbcbc)
      e.step()
      e.memory.get(100).should.equal(0xbcbc)
      e.registers.I.should.equal(101)
      e.registers.J.should.equal(201)

    it "STD", ->
      preload(e, 0x1f, 0x0e, 0x0f)
      e.registers.I = 100
      e.registers.J = 200
      e.memory.set(100, 0x4545)
      e.memory.set(200, 0xbcbc)
      e.step()
      e.memory.get(100).should.equal(0xbcbc)
      e.registers.I.should.equal(99)
      e.registers.J.should.equal(199)
