
Memory = require("./memory").Memory

# abstraction for hardware attached to the DCPU. each piece of hardware will
# be assigned a number which is used to identify it in HWQ and HWI operations.
class Hardware
  # required id, version, manufacturer for HWQ
  constructor: (@id, @version, @manufacturer) ->

  # handler for HWI
  request: (emulator) ->


class Emulator
  RegisterNames: "ABCXYZIJ"

  # memory: an array of 65536 words (main memory)
  constructor: (memory) ->
    if not memory then memory = new Memory()
    @memory = memory
    @hardware = []
    @reset()

  reset: ->
    @registers = { A: 0, B: 0, C: 0, X: 0, Y: 0, Z: 0, I: 0, J: 0, PC: 0, SP: 0, EX: 0, IA: 0 }
    # if more than 256 interrupts queue up, we "catch fire".
    @onFire = false
    # we queue interrupts when in an interrupt handler. the queue is just interrupt ids.
    @queueing = false
    @interruptQueue = []
    @cycles = 0

  clearMemory: ->
    @memory.clear()

  nextPC: ->
    rv = @memory.get(@registers.PC)
    @registers.PC = (@registers.PC + 1) & 0xffff
    rv

  # [SP++]
  pop: ->
    rv = @memory.get(@registers.SP)
    @registers.SP = (@registers.SP + 1) & 0xffff
    rv

  # the dcpu spec actually allows binary ops like "ADD PUSH, POP" where PUSH is both a source and a destination, so the
  # community has agreed that we should just treat it as a read-only [SP - 1].
  getPush: ->
    @memory.get(@registers.SP - 1)

  # [--SP]
  push: (value) ->
    @registers.SP = (@registers.SP - 1) & 0xffff
    @memory.set(@registers.SP, value)

  readRegister: (number) ->
    @registers[@RegisterNames[number]] or 0

  writeRegister: (number, value) ->
    @registers[@RegisterNames[number]] = value

  # turn a 16-bit signed value into a js signed value
  signed: (value) ->
    if value & 0x8000 then (value | 0xffff0000) else value

  # execute one instruction at PC.
  step: ->
    if @onFire then return
    interrupting = if @queueing then false else @triggerQueuedInterrupt()
    if @halting
      if not interrupting then return
      @halting = false

    instruction = @nextPC()
    op = instruction & 0x1f
    a = (instruction >> 10) & 0x3f
    b = (instruction >> 5) & 0x1f

    if instruction == 0x8b83
      # HLT
      @halting = true
      @registers.PC = (@registers.PC - 1) & 0xffff
      return

    if op == 0
      @stepSpecial(b, a)
    else if op < 0x10
      @stepBinary(op, a, b)
    else if op < 0x18
      @stepConditional(op, a, b)
    else if op < 0x1e
      @stepBinary(op, a, b)
    else
      av = @fetchOperand(a)
      bv = @fetchOperand(b, true)
      @storeOperand(b, av & 0xffff)
      @cycles += 2
      switch op
        when 0x1e # STI
          @registers.I = (@registers.I + 1) & 0xffff
          @registers.J = (@registers.J + 1) & 0xffff
        when 0x1f # STD
          @registers.I = (@registers.I - 1) & 0xffff
          @registers.J = (@registers.J - 1) & 0xffff
    if not @queueing then @triggerQueuedInterrupt()

  stepSpecial: (op, a) ->
    switch op
      when 0x01 # JSR
        pc = @fetchOperand(a)
        @push(@registers.PC)
        @registers.PC = pc
        @cycles += 3
      when 0x08 # INT
        @queueInterrupt(@fetchOperand(a))
        @cycles += 4
      when 0x09 # IAG
        @fetchOperand(a, true)
        @storeOperand(a, @registers.IA)
        @cycles += 1
      when 0x0a # IAS
        @registers.IA = @fetchOperand(a)
        @cycles += 1
      when 0x0b # RFI
        @queueing = false
        @registers.A = @pop()
        @registers.PC = @pop()
        @cycles += 3
      when 0x0c # IAQ
        @queueing = (if @fetchOperand(a) != 0 then true else false)
        @cycles += 2
      when 0x10 # HWN
        @fetchOperand(a, true)
        @storeOperand(a, @hardware.length)
        @cycles += 2
      when 0x11 # HWQ
        n = @fetchOperand(a)
        device = if n < @hardware.length then @hardware[n] else new Hardware(0, 0, 0)
        @registers.A = device.id & 0xffff
        @registers.B = (device.id >> 16) & 0xffff
        @registers.C = device.version
        @registers.X = device.manufacturer & 0xffff
        @registers.Y = (device.manufacturer >> 16) & 0xffff
        @cycles += 4
      when 0x12 # HWI
        n = @fetchOperand(a)
        @cycles += 4
        @cycles += if n < @hardware.length then @hardware[n].request(this) else 0
      else
        # at least spend one cycle pouting.
        @cycles += 1

  stepBinary: (op, a, b) ->
    av = @fetchOperand(a)
    bv = @fetchOperand(b, true)
    rv = 0
    switch op
      when 0x01 # SET
        rv = av
        @cycles += 1
      when 0x02 # ADD
        rv = av + bv
        @cycles += 2
      when 0x03 # SUB
        rv = -av + bv
        @cycles += 2
      when 0x04 # MUL
        rv = av * bv
        @registers.EX = (rv >> 16) & 0xffff
        @cycles += 2
      when 0x05 # MLI
        rv = @signed(av) * @signed(bv)
        @registers.EX = (rv >> 16) & 0xffff
        @cycles += 2
      when 0x06 # DIV
        rv = if av == 0 then 0 else bv / av
        @registers.EX = ((bv << 16) / av) & 0xffff
        @cycles += 3
      when 0x07 # DVI
        rv = if av == 0 then 0 else @signed(bv) / @signed(av)
        @registers.EX = ((bv << 16) / av) & 0xffff
        @cycles += 3
      when 0x08 # MOD
        rv = if av == 0 then 0 else bv % av
        @cycles += 3
      when 0x09 # MDI
        rv = if av == 0 then 0 else @signed(bv) % @signed(av)
        @cycles += 3
      when 0x0a # AND
        rv = av & bv
        @cycles += 1
      when 0x0b # BOR
        rv = av | bv
        @cycles += 1
      when 0x0c # XOR
        rv = av ^ bv
        @cycles += 1
      when 0x0d # SHR
        @registers.EX = ((bv << 16) >>> av) & 0xffff
        rv = (bv >>> av)
        @cycles += 2
      when 0x0e # ASR
        @registers.EX = ((@signed(bv) << 16) >>> av) & 0xffff
        rv = (@signed(bv) >> av)
        @cycles += 2
      when 0x0f # SHL
        @registers.EX = ((bv << av) >>> 16) & 0xffff
        rv = (bv << av)
        @cycles += 2
      when 0x1a # ADX
        rv = bv + av + @registers.EX
        @registers.EX = (rv >> 16) & 0xffff
        @cycles += 3
      when 0x1b # SBX
        rv = -av + bv + @registers.EX
        @registers.EX = (rv >> 16) & 0xffff
        @cycles += 3
    @storeOperand(b, rv & 0xffff)

  stepConditional: (op, a, b) ->
    av = @fetchOperand(a)
    bv = @fetchOperand(b, true)
    switch op
      when 0x10 # IFB
        if (bv & av) == 0 then @skip()
      when 0x11 # IFC
        if (bv & av) != 0 then @skip()
      when 0x12 # IFE
        if bv != av then @skip()
      when 0x13 # IFN
        if bv == av then @skip()
      when 0x14 # IFG
        if bv <= av then @skip()
      when 0x15 # IFA
        if @signed(bv) <= @signed(av) then @skip()
      when 0x16 # IFL
        if bv >= av then @skip()
      when 0x17 # IFU
        if @signed(bv) >= @signed(av) then @skip()
    @cycles += 2

  nextInstructionPc: ->
    @stepLength().map (w) => (@registers.PC + w) & 0xffff

  # how long is this instruction, in words?
  # also return how long it was in chaned conditionals.
  stepLength: ->
    words = 0
    conditionWords = 0
    loop
      instruction = @memory.peek((@registers.PC + words) & 0xffff)
      conditionWords = words
      words += 1
      op = instruction & 0x1f
      a = (instruction >> 10) & 0x3f
      b = (instruction >> 5) & 0x1f
      if @operandHasImmediate(a) then words += 1
      if @operandHasImmediate(b) then words += 1
      return [ words, conditionWords ] if op < 0x10 or op > 0x17

  operandHasImmediate: (operand) ->
    (operand >= 0x10 and operand < 0x18) or (operand == 0x1a) or (operand == 0x1e) or (operand == 0x1f)

  skip: ->
    [ words, conditionWords ] = @stepLength()
    @cycles += words
    @registers.PC = (@registers.PC + words) & 0xffff

  # operand: the A or B operand
  # destination: true if the operand is in the destination position (vs. source)
  # if there's an immediate value, and the operand is a destination, the immediate will be stored in @immediate.
  fetchOperand: (operand, destination = false) ->
    if operand < 0x08
      # R
      @readRegister(operand)
    else if operand < 0x10
      # [R]
      @memory.get(@readRegister(operand - 0x08))
    else if operand < 0x18
      # [R + imm]
      word = @nextPC()
      if destination then @immediate = word
      @cycles += 1
      @memory.get(word + @readRegister(operand - 0x10))
    else if operand == 0x18
      # POP [SP++] / PUSH [--SP]
      if destination then @getPush() else @pop()
    else if operand == 0x19
      # PEEK [SP]
      @memory.get(@registers.SP)
    else if operand == 0x1a
      # PICK n [SP + imm]
      word = @nextPC()
      if destination then @immediate = word
      @cycles += 1
      @memory.get(word + @registers.SP)
    else if operand == 0x1b
      # SP
      @registers.SP
    else if operand == 0x1c
      # PC
      @registers.PC
    else if operand == 0x1d
      # EX
      @registers.EX
    else if operand == 0x1e
      # [imm]
      word = @nextPC()
      if destination then @immediate = word
      @cycles += 1
      @memory.get(word)
    else if operand == 0x1f
      # imm
      word = @nextPC()
      if destination then @immediate = word
      @cycles += 1
      word
    else
      # literal -1 .. 30
      (operand - 0x21) & 0xffff

  storeOperand: (operand, value) ->
    if operand < 0x08
      # R
      @writeRegister(operand, value)
    else if operand < 0x10
      # [R]
      @memory.set(@readRegister(operand - 0x08), value)
    else if operand < 0x18
      # [R + imm]
      @memory.set(@immediate + @readRegister(operand - 0x10), value)
    else if operand == 0x18
      # PUSH [--SP]
      @push(value)
    else if operand == 0x19
      # PEEK [SP]
      @memory.set(@registers.SP, value)
    else if operand == 0x1a
      # PICK n [SP + imm]
      @memory.set(@immediate + @registers.SP, value)
    else if operand == 0x1b
      # SP
      @registers.SP = value
    else if operand == 0x1c
      # PC
      @registers.PC = value
    else if operand == 0x1d
      # EX
      @registers.EX = value
    else if operand == 0x1e
      # [imm]
      @memory.set(@immediate, value)
    # ignore "store into immediate"

  queueInterrupt: (id) ->
    @interruptQueue.push(id)
    if @interruptQueue.length > 256 then @onFire = true

  triggerQueuedInterrupt: ->
    if @interruptQueue.length == 0 then return false
    id = @interruptQueue.shift()
    if @registers.IA == 0 then return false
    # jump to interrupt handler!
    @queueing = true
    @push(@registers.PC)
    @push(@registers.A)
    @registers.PC = @registers.IA
    @registers.A = id
    true

exports.Emulator = Emulator
exports.Hardware = Hardware
