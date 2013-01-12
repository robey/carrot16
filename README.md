
carrot16
========

carrot16 is an in-browser IDE, assembler, and emulator for the DCPU platform,
based on work done for deNULL's server-based emulator.

## features

- runs completely in your local browser (chrome) without requiring any server
  or any particular platform (so it should work equally well on mac, linux,
  and Windows)
- full-featured assembler (d16bunny) that supports things like macros
- load and debug local files
- breakpoints and step-through
- watch memory reads/writes as they happen
- written in coffeescript for clarity

## to run it

    $ open index.html

(or the windows equivalent)

## license

open-source licensed under apache 2. patches welcome!

## to-do

- disassembler (is this really necessary?)
- assembler: string form with high bit set on last char
- add vector display
- add disk drive
- make right panel be exactly the width of the monitor
