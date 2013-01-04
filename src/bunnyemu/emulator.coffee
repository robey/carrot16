
class Emulator
  RegisterNames: "ABCXYZIJ"

  # memory: an array of 65536 words (main memory)
  constructor: (memory) ->
    @registers = { A: 0, B: 0, C: 0, X: 0, Y: 0, Z: 0, I: 0, J: 0, PC: 0, SP: 0, EX: 0, IA: 0 }
    if not memory then memory = []
    @memory = memory
    @hardware = []
    @onFire = false
    # we queue interrupts when in an interrupt handler.
    @queueing = false
    @interruptQueue = []
    @cycles = 0

  nextPC: ->
    rv = @memory[@registers.PC] or 0
    @registers.PC = (@registers.PC + 1) & 0xffff
    rv

  # [SP++]
  pop: ->
    rv = @memory[@registers.SP] or 0
    @registers.SP = (@registers.SP + 1) & 0xffff
    rv

  # [--SP]
  # the dcpu spec actually allows binary ops like "ADD PUSH, POP" where PUSH is both a source and a destination, so the
  # community has agreed that we should just treat it as a read-only [--SP].
  getPush: ->
    @registers.SP = (@registers.SP - 1) & 0xffff
    @memory[@registers.SP] or 0

  push: (value) ->
    @registers.SP = (@registers.SP - 1) & 0xffff
    @memory[@registers.SP] = value

  readRegister: (number) ->
    @registers[@RegisterNames[number]] or 0

  # execute one instruction at PC.
  step: ->
    if not @queueing then @triggerQueuedInterrupt()

    instruction = @nextPC()
    op = instruction & 0x1f
    a = (instruction >> 10) & 0x3f
    b = (instruction >> 5) & 0x1f

    if op == 0
      @stepSpecial(b, a)

  stepSpecial: (op, a) ->
    switch op
      when 0x01 # JSR
        pc = @getValue(a, false)
        @push(@registers.PC)
        @registers.PC = pc
        @cycles += 3
      when 0x0b # RFI
        @queueing = false
        @registers.A = @pop()
        @registers.PC = @pop()
        @cycles += 3

  skipValue: (operand) ->
    if (code >= 0x10 and code < 0x18) or (code == 0x1a) or (code == 0x1e) or (code == 0x1f)
      # [R + imm], [SP + imm], [imm], imm
      @nextPC()

  # operand: the A or B operand
  # destination: true if the operand is in the destination position (vs. source)
  getValue: (operand, destination = false) ->
    if operand < 0x08
      # R
      @readRegister(operand)
    else if operand < 0x10
      # [R]
      @memory[@readRegister(operand - 0x08)] or 0
    else if operand < 0x18
      # [R + imm]
      word = @nextPC()
      @cycles += 1
      @memory[(word + @readRegister(operand - 0x10)) & 0xffff] or 0
    else if operand == 0x18
      # POP [SP++] / PUSH [--SP]
      if destination then @getPush() else @pop()
    else if operand == 0x19
      # PEEK [SP]
      @memory[@registers.SP] or 0
    else if operand == 0x1a
      # PICK n [SP + imm]
      word = @nextPC()
      @cycles += 1
      @memory[(word + @registers.SP) & 0xffff] or 0
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
      @cycles += 1
      @memory[word] or 0
    else if operand == 0x1f
      # imm
      word = @nextPC()
      @cycles += 1
      word
    else
      # literal -1 .. 30
      (operand - 0x21) & 0xffff

  triggerQueuedInterrupt: ->
    if @interruptQueue.length == 0 then return false
    interrupt = @interruptQueue.shift()
    if @registers.IA == 0 then return false
    # jump to interrupt handler!
    @queueing = true
    @push(@registers.PC)
    @push(@registers.A)
    @registers.PC = @registers.IA
    interrupt()
    true

exports.Emulator = Emulator
