; *****************************************************************************
; Bootloader for cartridge based CP/M on Sega SC-3000 system.
; *****************************************************************************

VDP_DATA     equ $be
VDP_CTRL     equ $bf
PPI_CTRL     equ $df
BANK_SW      equ $e0

CBIOS_ADDR   equ $fa00
CPM22_ADDR   equ $e400
SWITCH_ADDR  equ $e3f0

; *****************************************************************************

  org $0000 ; Reset Vector
reset:
  ld sp,$dfff ; RAM End
  di
  im 1
  jp start

; *****************************************************************************

start:
  ; Load VDP register 0:
  ld a,$00
  out (VDP_CTRL),a
  ld a,$80
  out (VDP_CTRL),a

  ; Load VDP register 1:
  ld a,$b0
  out (VDP_CTRL),a
  ld a,$81
  out (VDP_CTRL),a

  ; Load VDP register 2:
  ld a,$0f ; Name Table Base Address
  out (VDP_CTRL),a
  ld a,$82
  out (VDP_CTRL),a

  ; Load VDP register 3:
  ld a,$ff ; Color Table Base Address
  out (VDP_CTRL),a
  ld a,$83
  out (VDP_CTRL),a

  ; Load VDP register 4:
  ld a,$03 ; Pattern Generator Base Address
  out (VDP_CTRL),a
  ld a,$84
  out (VDP_CTRL),a

  ; Load VDP register 5:
  ld a,$76 ; Sprite Attribute Table Base Address
  out (VDP_CTRL),a
  ld a,$85
  out (VDP_CTRL),a

  ; Load VDP register 6:
  ld a,$03 ; Sprite Pattern Generator Base Address
  out (VDP_CTRL),a
  ld a,$86
  out (VDP_CTRL),a

  ; Load VDP register 7:
  ld a,$17 ; Text Color & Backdrop Color
  out (VDP_CTRL),a
  ld a,$87
  out (VDP_CTRL),a

  ; Set Blank Enable to 1 in VDP Register 1:
  ld a,$f0
  out (VDP_CTRL),a
  ld a,$81
  out (VDP_CTRL),a

  ; Set VRAM address to write to pattern generator (0x1800):
  ld a,$00
  out (VDP_CTRL),a
  ld a,$18 + $40
  out (VDP_CTRL),a

  ; Load font data:
  ld ix,font
fontload:
  ld a,(ix)
  out (VDP_DATA),a
  inc ix
  ld a,ixh
  cp a,$18 ; Reached the end when IX is 0x1800.
  jr nz,fontload

  ; Set VRAM address to write name table (0x3C00):
  ld a,$00
  out (VDP_CTRL),a
  ld a,$3c + $40
  out (VDP_CTRL),a

  ; Fill screen with space:
  ld ix,960
screenfill:
  ld a,' '
  out (VDP_DATA),a
  dec ix
  ld a,ixh
  cp a,0
  jr nz,screenfill
  ld a,ixl
  cp a,0
  jr nz,screenfill

  ; Configure the 8255 PPI:
  ld a,$92
  out (PPI_CTRL),a

  ; Load CBIOS into upper RAM:
  ld ix,cbios
  ld iy,CBIOS_ADDR
cbiosload:
  ld a,(ix)
  ld (iy),a
  inc ix
  inc iy
  ld a,ixh
  cp a,cpm22 / 256
  jr nz,cbiosload

  ; Load CP/M 2.2 into upper RAM:
  ld ix,cpm22
  ld iy,CPM22_ADDR
cpm22load:
  ld a,(ix)
  ld (iy),a
  inc ix
  inc iy
  ld a,iyh
  cp a,CBIOS_ADDR / 256
  jr nz,cpm22load

  ; Load switcher code into RAM since cartridge area gets swapped out:
  ld ix,switchcode
  ld iy,SWITCH_ADDR
switchload:
  ld a,(ix)
  ld (iy),a
  inc ix
  inc iy
  ld a,iyh
  cp a,CPM22_ADDR / 256
  jr nz,switchload

  jp SWITCH_ADDR

switchcode:
  ; Switch to bank 0 with RAM in lower area:
  ld a,$a0
  out (BANK_SW),a
  jp CBIOS_ADDR ; Jump to CBIOS.

; *****************************************************************************

  org $1000
font:
  incbin "font.bin"

  org $1800
cbios:
  incbin "cbios.cim"

  org $1e00
cpm22:
  incbin "cpm22.bin"

