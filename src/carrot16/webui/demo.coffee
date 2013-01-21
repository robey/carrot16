DEMO_CODE = """; demo of carrot16 in action!

:start
  jsr find_hardware
  jsr setup_monitor
  jsr draw_logo
  jmp roll_colors
  brk

monitor_hi = 0x7349
monitor_lo = 0xf615
clock_lo = 0xb402
clock_hi = 0x12d0
monitor.map_screen = 0
monitor.map_font = 1
monitor.map_palette = 2
monitor.set_border = 3
monitor.dump_font = 4
monitor.dump_palette = 5
clock.set_tick = 0
clock.set_interrupt = 2
line_size = 32

:find_hardware
  hwn j
  set i, 0
:find_hardware.1
  hwq i
  ife a, monitor_lo
    ife b, monitor_hi
      set [monitor_hw], i
  ife a, clock_lo
    ife b, clock_hi
      set [clock_hw], i
  add i, 1
  ifg j, i
    bra find_hardware.1
  ret

:monitor_hw dat 0
:clock_hw dat 0

framebuffer = 0x100
framebuffer.end = 0x280
custom_font = 0x280
custom_palette = 0x380

; some names for the colors:
black = 0
green = 2
red = 4
orange = 6
bright_green = 10
yellow = 14
white = 15
space = 32

; FIXME: "bgcolor = yellow" doesn't work.
bgcolor = 8

:setup_monitor
  set a, monitor.map_screen
  set b, framebuffer
  hwi [monitor_hw]
  set a, monitor.set_border
  set b, yellow
  hwi [monitor_hw]
  set a, monitor.dump_font
  set b, custom_font
  hwi [monitor_hw]
  set a, monitor.dump_palette
  set b, custom_palette
  hwi [monitor_hw]
  set a, monitor.map_palette
  hwi [monitor_hw]
; copy our custom chars into the font zone
:modify_font
  set i, custom_font
  set j, logo_font
  set x, logo_font.end
:modify_font.1
  sti [i], [j]
  ifl j, x
    bra modify_font.1
  set a, monitor.map_font
  set b, custom_font
  hwi [monitor_hw]
; now set the background to yellow everywhere
:clear
  set i, framebuffer
  set z, framebuffer.end
  set x, bgcolor
  shl x, 8
  add x, space
:clear.1
  sti [i], x
  ifl i, z
    bra clear.1
  ret

:draw_logo
  set i, framebuffer + (line_size * 2) + 5
  set j, title
  set x, (yellow << 4) | bgcolor
  jsr write_string
; fancy carrot
  set [framebuffer + (line_size * 1) + 3], (orange << 12) | (bgcolor << 8) | 1
  set [framebuffer + (line_size * 1) + 4], (green << 12) | (bgcolor << 8) | 4
  set [framebuffer + (line_size * 2) + 2], (orange << 12) | (bgcolor << 8) | 0
  set [framebuffer + (line_size * 2) + 3], (orange << 12) | (bgcolor << 8) | 2
  set [framebuffer + (line_size * 2) + 4], (orange << 12) | (bgcolor << 8) | 3
  ret

; write a null-terminated string (J) to the screen (I) in color (X).
:write_string
  ife [j], 0
    ret
:write_string.1
  set a, x
  shl a, 8
  bor a, [j]
  sti [i], a
  ifn [j], 0
    bra write_string.1
  ret

:title
  dat "carrot16", 0

:logo_font
  dat 0xe0f0, 0xf87e
  dat 0x0080, 0xc0c0
  dat 0x3f1f, 0x0f0f
  dat 0x0703, 0x0000
  dat 0xf0e0, 0x5040
:logo_font.end

:roll_colors
  ias tick.up
  set a, clock.set_interrupt
  set b, 1
  hwi [clock_hw]
  set a, clock.set_tick
  set b, 6
  hwi [clock_hw]
  brk
:tick.up
  add [custom_palette + green], 0x020
  add [custom_palette + orange], 0x110
  ife [custom_palette + orange], 0xc70
    ias tick.down
  rfi 0
:tick.down
  sub [custom_palette + green], 0x020
  sub [custom_palette + orange], 0x110
  ife [custom_palette + orange], 0x940
    ias tick.up
  rfi 0
"""

exports.DEMO_CODE = DEMO_CODE
