; *****************************************************************************
; Terminal emulator for SK-1100 keyboard input and TMS9918 video output.
; *****************************************************************************

PPI_PORT_A   equ $dc
PPI_PORT_B   equ $dd
PPI_PORT_C   equ $de
PPI_CTRL     equ $df

VDP_DATA     equ $be
VDP_CTRL     equ $bf

; *****************************************************************************

console_init:
  ; VRAM address is the cursor position, set to the upper left corner:
  ld a,$00
  ld (vram_l),a
  ld a,$3c
  ld (vram_h),a

  ; Setup IRQ handler at IM1 vector:
  ld a,$c3 ; JP instruction.
  ld ($0038),a
  ld a,key_irq % 256
  ld ($0039),a
  ld a,key_irq / 256
  ld ($003a),a

  ret

; *****************************************************************************

key_irq:
  ex af,af'
  exx
  push ix

  ; Acknowledge the IRQ:
  in a,(VDP_CTRL)

key_poll:
  ld ix,key_matrix
  ld d,0 ; Initial row to scan.

  ; Write row to scan:
key_row_scan:
  ld a,d
  out (PPI_PORT_C),a

  ; Read port A columns:
  in a,(PPI_PORT_A)
  cp a,$fe
  jr z,key_pa0
  cp a,$fd
  jr z,key_pa1
  cp a,$fb
  jr z,key_pa2
  cp a,$f7
  jr z,key_pa3
  cp a,$ef
  jr z,key_pa4
  cp a,$df
  jr z,key_pa5
  cp a,$bf
  jr z,key_pa6
  cp a,$7f
  jr z,key_pa7
  jp key_port_b

key_pa0:
  inc ix
key_pa1:
  inc ix
key_pa2:
  inc ix
key_pa3:
  inc ix
key_pa4:
  inc ix
key_pa5:
  inc ix
key_pa6:
  inc ix
key_pa7:
  jp key_pressed

key_port_b:
  ld bc,8 ; Offset between port A and port B index.
  add ix,bc

  ; Read port B column:
  in a,(PPI_PORT_B)
  and a,$0f
  cp a,$0e
  jr z,key_pb0
  jp key_row_next

key_pb0:
  jp key_pressed

key_row_next:
  inc d
  ld a,d
  cp a,7 ; Total rows.
  jr z,key_end
  inc ix ; Offset between port B and port A index is only 1.
  jp key_row_scan

key_pressed:
  ; Check if shift button is pressed:
  ld a,6 ; Row 6
  out (PPI_PORT_C),a
  in a,(PPI_PORT_B)
  and a,$0f
  cp a,$07 ; Column PB3
  jr nz,key_not_shifted

  ld bc,key_matrix_shifted - key_matrix
  add ix,bc ; Key is shifted.
key_not_shifted:
  ld a,(key_last)
  sub a,(ix) ; Compare last and current key...
  jr z,key_irq_end ; ...Ignore if it is the same.

  ld a,(ix)
  ld (key),a
  ld (key_last),a
  jp key_irq_end

key_end:
  xor a ; Return a 0 for no keypress.
  ld (key),a
  ld (key_last),a

key_irq_end:
  pop ix
  exx
  ex af,af'
  reti

; *****************************************************************************

console_output:
  ld a,c
  cp a,$0a
  jr z,console_lf
  cp a,$0d
  jr z,console_cr
  cp a,$08
  jr z,console_bs

  ; Not an ASCII control character, print it directly:
  ld a,(vram_l)
  out (VDP_CTRL),a
  ld a,(vram_h)
  or a,$40 ; Set write bit.
  out (VDP_CTRL),a
  ld a,c
  out (VDP_DATA),a
  jp cursor_right ; Advance cursor.

console_lf:
  jp cursor_down
console_cr:
  jp cursor_home
console_bs:
  ld a,' '
  out (VDP_DATA),a ; Remove character under cursor first.
  jp cursor_left

; *****************************************************************************

cursor_left:
  push af
  push bc
  push hl
  ld hl,(vram_l)
  dec hl
  jp cursor_move
cursor_right:
  push af
  push bc
  push hl
  ld hl,(vram_l)
  inc hl
  jp cursor_scroll_check
cursor_down:
  push af
  push bc
  push hl
  ld hl,(vram_l)
  ld bc,40
  add hl,bc
cursor_scroll_check:
  ld a,h
  cp a,$3f
  jr c,cursor_move
  ld a,l
  cp a,$c0
  jr c,cursor_move
  call scroll_down
  jp cursor_end
cursor_move:
  ld (vram_l),hl
cursor_end:
  pop hl
  pop bc
  pop af
  ret

cursor_home:
  push af
  push bc
  push de
  push hl

  ; Divide by 40 then multiply by 40 to position cursor at start of the line.
  ld hl,(vram_l)
  ld d,40
  call Div8
  ld d,h
  ld e,l
  ld a,40
  call Mul8
  ld (vram_l),hl

  pop hl
  pop de
  pop bc
  pop af
  ret

; *****************************************************************************

scroll_down:
  push ix
  push iy
  ld ix,$3c28
  ld iy,$3c00

scroll_down_loop:
  ; Source VRAM:
  ld a,ixl
  out (VDP_CTRL),a
  ld a,ixh
  out (VDP_CTRL),a
  in a,(VDP_DATA)
  ld c,a

  ; Destination VRAM:
  ld a,iyl
  out (VDP_CTRL),a
  ld a,iyh
  or a,$40 ; Set write bit.
  out (VDP_CTRL),a
  ld a,c
  out (VDP_DATA),a

  inc ix
  inc iy

  ld a,ixh
  cp a,$3f
  jr c,scroll_down_loop
  ld a,ixl
  cp a,$c0
  jr c,scroll_down_loop

  ; Remove all characters on last line:
scroll_clear_loop:
  ld a,' '
  out (VDP_DATA),a
  inc ix
  ld a,ixl
  cp a,$e8
  jr c,scroll_clear_loop

  ; Position cursor at the start of the line:
  ld hl,$3f98
  ld (vram_l),hl

  pop iy
  pop ix
  ret

; *****************************************************************************

key_matrix:
  db 'I', 'K', ',',  0 , 'Z', 'A', 'Q', '1' ; Row 0, PA0 -> PA7
  db '8'                                    ; Row 0, PB0
  db 'O', 'L', '.', ' ', 'X', 'S', 'W', '2' ; Row 1, PA0 -> PA7
  db '9'                                    ; Row 1, PB0
  db 'P', ';', '/',  0 , 'C', 'D', 'E', '3' ; Row 2, PA0 -> PA7
  db '0'                                    ; Row 2, PB0
  db '@', ':',  0 ,  8 , 'V', 'F', 'R', '4' ; Row 3, PA0 -> PA7
  db '-'                                    ; Row 3, PB0
  db '[', ']', 10 ,  0 , 'B', 'G', 'T', '5' ; Row 4, PA0 -> PA7
  db '^'                                    ; Row 4, PB0
  db  0 , 13 ,  8 ,  0 , 'N', 'H', 'Y', '6' ; Row 5, PA0 -> PA7
  db 92                                     ; Row 5, PB0
  db  0 , 11 , 12 ,  0 , 'M', 'J', 'U', '7' ; Row 6, PA0 -> PA7
  db  0                                     ; Row 6, PB0
key_matrix_shifted:
  db 'i', 'k', '<',  0 , 'z', 'a', 'q', '!' ; Row 0, PA0 -> PA7
  db '('                                    ; Row 0, PB0
  db 'o', 'l', '>', ' ', 'x', 's', 'w', '"' ; Row 1, PA0 -> PA7
  db ')'                                    ; Row 1, PB0
  db 'p', '+', '?',  0 , 'c', 'd', 'e', '#' ; Row 2, PA0 -> PA7
  db '0'                                    ; Row 2, PB0
  db '`', '*',  0 ,  8 , 'v', 'f', 'r', '$' ; Row 3, PA0 -> PA7
  db '='                                    ; Row 3, PB0
  db '{', '}', 10 ,  0 , 'b', 'g', 't', '%' ; Row 4, PA0 -> PA7
  db '~'                                    ; Row 4, PB0
  db  0 , 13 ,  8 ,  0 , 'n', 'h', 'y', '&' ; Row 5, PA0 -> PA7
  db '|'                                    ; Row 5, PB0
  db  0 , 11 , 12 ,  0 , 'm', 'j', 'u', 39  ; Row 6, PA0 -> PA7
  db  0                                     ; Row 6, PB0

; *****************************************************************************

key:
  db 0 ; The polled keypress.
key_last:
  db 0 ; Used to keeping track if a new key has been pressed.
vram_l:
  db 0
vram_h:
  db 0

