;       skeletal cbios for first level of CP/M 2.0 alteration
;
msize   equ     64              ;cp/m version memory size in kilobytes
;
;       "bias" is address offset from 3400h for memory systems
;       than 16k (referred to as"b" throughout the text)
;
bias    equ     (msize-21)*1024
ccp     equ     3800h+bias      ;base of ccp
bdos    equ     ccp+806h        ;base of bdos
bios    equ     ccp+1600h       ;base of bios
cdisk   equ     0004h           ;current disk number 0=a,... l5=p
iobyte  equ     0003h           ;intel i/o byte
;
        org     bios            ;origin of this program
nsects  equ     ($-ccp)/128     ;warm start sector count
;
BANK_SW equ $e0
;
;       jump vector for individual subroutines
;
        jmp     boot    ;cold start
wboote: jmp     wboot   ;warm start
        jmp     const   ;console status
        jmp     conin   ;console character in
        jmp     conout  ;console character out
        jmp     list    ;list character out
        jmp     punch   ;punch character out
        jmp     reader  ;reader character out
        jmp     home    ;move head to home position
        jmp     seldsk  ;select disk
        jmp     settrk  ;set track number
        jmp     setsec  ;set sector number
        jmp     setdma  ;set dma address
        jmp     read    ;read disk
        jmp     write   ;write disk
        jmp     listst  ;return list status
        jmp     sectran ;sector translate
;
;       fixed data tables for four-drive standard
;       ibm-compatible 8" disks
;
;       disk Parameter header for disk 00
dpbase: dw      trans, 0000h
        dw      0000h, 0000h
        dw      dirbf, dpblk
        dw      chk00, all00
;       disk parameter header for disk 01
        dw      trans, 0000h
        dw      0000h, 0000h
        dw      dirbf, dpblk
        dw      chk01, all01
;       disk parameter header for disk 02
        dw      trans, 0000h
        dw      0000h, 0000h
        dw      dirbf, dpblk
        dw      chk02, all02
;       disk parameter header for disk 03
        dw      trans, 0000h
        dw      0000h, 0000h
        dw      dirbf, dpblk
        dw      chk03, all03
;
;       sector translate vector
trans:  db       1,  7, 13, 19  ;sectors  1,  2,  3,  4
        db      25,  5, 11, 17  ;sectors  5,  6,  7,  6
        db      23,  3,  9, 15  ;sectors  9, 10, 11, 12
        db      21,  2,  8, 14  ;sectors 13, 14, 15, 16
        db      20, 26,  6, 12  ;sectors 17, 18, 19, 20
        db      18, 24,  4, 10  ;sectors 21, 22, 23, 24
        db      16, 22          ;sectors 25, 26
;
dpblk:  ;disk parameter block, common to all disks
        dw      26              ;sectors per track
        db      3               ;block shift factor
        db      7               ;block mask
        db      0               ;null mask
        dw      242             ;disk size-1
        dw      63              ;directory max
        db      192             ;alloc 0
        db      0               ;alloc 1
        dw      16              ;check size
        dw      2               ;track offset

banner: db      'Sega CP/M 2.2', 0Dh, 0Ah
;
;       end of fixed tables
;
;       individual subroutines to perform each function
boot:   ;simplest case is to just perform parameter initialization
        xra     a               ;zero in the accum
        sta     iobyte          ;clear the iobyte
        sta     cdisk           ;select disk zero
;
        call console_init
;
        ;print banner on startup
        lxi     d, banner
        jmp     bprint
bploop: inx     d
bprint: ldax    d
        mov     c, a
        call    conout
        cp      0Ah
        jnz     bploop
;
        jmp     gocpm           ;initialize and go to cp/m
;
wboot:  ;simplest case is to read the disk until all sectors loaded
        lxi     sp, 80h         ;use space below buffer for stack
        mvi     c, 0            ;select disk 0
        call    seldsk
        call    home            ;go to track 00
;
        mvi     b, nsects       ;b counts * of sectors to load
        mvi     c, 0            ;c has the current track number
        mvi     d, 2            ;d has the next sector to read
;       note that we begin by reading track 0, sector 2 since sector 1
;       contains the cold start loader, which is skipped in a warm start
        lxi     h, ccp          ;base of cp/m (initial load point)
load1:  ;load   one more sector
        push    b               ;save sector count, current track
        push    d               ;save next sector to read
        push    h               ;save dma address
        mov     c, d            ;get sector address to register C
        call    setsec          ;set sector address from register C
        pop     b               ;recall dma address to b, C
        push    b               ;replace on stack for later recall
        call    setdma          ;set dma address from b, C
;
;       drive set to 0, track set, sector set, dma address set
        call    read
        cp      00h             ;any errors?
        jnz     wboot           ;retry the entire boot if an error occurs
;
;       no error, move to next sector
        pop     h               ;recall dma address
        lxi     d, 128          ;dma=dma+128
        dad     d               ;new dma address is in h, l
        pop     d               ;recall sector address
        pop     b       ;recall number of sectors remaining, and current trk
        dcr     b               ;sectors=sectors-1
        jz      gocpm           ;transfer to cp/m if all have been loaded
;
;       more    sectors remain to load, check for track change
        inr     d
        mov     a,d             ;sector=27?, if so, change tracks
        cp      27
        jc      load1           ;carry generated if sector<27
;
;       end of  current track,  go to next track
        mvi     d, 1            ;begin with first sector of next track
        inr     c               ;track=track+1
;
;       save    register state, and change tracks
        push    b
        push    d
        push    h
        call    settrk          ;track address set from register c
        pop     h
        pop     d
        pop     b
        jmp     load1           ;for another sector
;
;       end of  load operation, set parameters and go to cp/m
gocpm:
        mvi     a, 0c3h         ;c3 is a jmp instruction
        sta     0               ;for jmp to wboot
        lxi     h, wboote       ;wboot entry point
        shld    1               ;set address field for jmp at 0
;
        sta     5               ;for jmp to bdos
        lxi     h, bdos         ;bdos entry point
        shld    6               ;address field of Jump at 5 to bdos
;
        lxi     b, 80h          ;default dma address is 80h
        call    setdma
;
        ei                      ;enable the interrupt system
        lda     cdisk           ;get current disk number
        mov     c, a            ;send to the ccp
        jmp     ccp             ;go to cp/m for further processing
;
;
;       simple i/o handlers (must be filled in by user)
;       in each case, the entry point is provided, with space reserved
;       to insert your own code
;
const:  ;console status, return 0ffh if character ready, 00h if not
        di
        ld a,(key)
        cp a,$00
        jr nz,const_ready
        ei
        ret
const_ready:
        ld a,$ff
        ei
        ret
;
conin:  ;console character into register a
        ei
        halt ; Wait for IRQ.
        di

        ld a,(key)
        cp a,$00
        jr z,conin ; Loop as long as there is no keypress.

        ld c,a ; Save the keypress into register C.
        ld a,0
        ld (key),a ; Clear the key variable so const does not see it later!
        ld a,c ; Restore the keypress from register C.

        ani     7fh             ;strip parity bit
        ei
        ret
;
conout: ;console character output from register c
        call console_output
        ret
;
list:   ;list character from register c
        mov     a, c            ;character to register a
        ret                     ;null subroutine
;
listst: ;return list status (0 if not ready, 1 if ready)
        xra     a               ;0 is always ok to return
        ret
;
punch:  ;punch  character from  register C
        mov     a, c            ;character to register a
        ret                     ;null subroutine
;
;
reader: ;reader character into register a from reader device
        mvi    a, 1ah           ;enter end of file for now (replace later)
        ani    7fh              ;remember to strip parity bit
        ret
;
;
;       i/o drivers for the disk follow
;       for now, we will simply store the parameters away for use
;       in the read and write   subroutines
;
home:   ;move to the track 00   position of current drive
;       translate this call into a settrk call with Parameter 00
        mvi    c, 0             ;select track 0
        call   settrk
        ret                     ;we will move to 00 on first read/write
;
seldsk: ;select disk given by register c
        lxi     h, 0000h        ;error return code
        mov     a, c
        sta     diskno
        cp      4               ;must be between 0 and 3
        rnc                     ;no carry if 4, 5,...
;       disk number is in the proper range
;       compute proper disk Parameter header address
        lda     diskno
        mov     l, a            ;l=disk number 0, 1, 2, 3
        mvi     h, 0            ;high order zero
        dad     h               ;*2
        dad     h               ;*4
        dad     h               ;*8
        dad     h               ;*16 (size of each header)
        lxi     d, dpbase
        dad     d               ;hl=,dpbase (diskno*16)
        ret
;
settrk: ;set track given by register c
        mov     a, c
        sta     track
        ret
;
setsec: ;set sector given by register c
        mov     a, c
        sta     sector
        ret
;
;
sectran:
        ;translate the sector given by bc using the
        ;translate table given by de
        xchg                    ;hl=.trans
        dad     b               ;hl=.trans (sector)
        mov     l, m            ;l=trans (sector)
        mvi     h, 0            ;hl=trans (sector)
        ret                     ;with value in hl
;
setdma: ;set    dma address given by registers b and c
        mov     l, c            ;low order address
        mov     h, b            ;high order address
        shld    dmaad           ;save the address
        ret
;
read:   ;perform read operation (usually this is similar to write
;       so we will allow space to set up read command, then use
;       common code in write)
        push bc
        push de
        push hl

        ; Calculate bank number:
        ld a,(diskno)
        ld de,10 ; Offset between disk images in banks.
        call Mul8
        ld a,l
        add a,$a1 ; Offset from first bank with RAM.

        ld c,a ; Partial bank stored in C.
        ld a,(track)
        sra a
        sra a
        sra a ; Divide by 8.

        add c ; Bank number now in A.
        ld (bankno),a ; Store it in C for later use.

        ; Calculate address within bank:
        ld a,(track)
        and $7 ; Modulus 8.

        ld de,3328 ; Bytes per track.
        call Mul8
        ld (bank1),hl

        ld a,(sector)
        dec a ; Subtract 1 to get 0-indexed value.
        ld de,128 ; Track size.
        call Mul8
        ld (bank2),hl

        ld de,(bank2)
        ld ix,(bank1)
        add ix,de

        ; Do the transfer:
        ld iy,(dmaad)
        ld b,128
        di ; Disable IRQ while switching between banks, since vector changes!
readloop:
        ld a,(bankno)
        out (BANK_SW),a

        ld a,(ix)
        ld (tbyte),a ; Load byte from ROM bank.

        ld a,$a0
        out (BANK_SW),a ; Switch back to RAM bank!

        ld a,(tbyte)
        ld (iy),a ; Store to RAM.

        inc ix
        inc iy
        djnz readloop
        ei ; Now safe to re-enable the IRQ.

        jmp     waitio          ;to perform the actual i/o
;
write:  ;perform a write operation
        ld a,1 ; Write not supported, return error code 1.
        ret
;
waitio: ;enter  here from read  and write to perform the actual i/o
;       operation. return a 00h in register a if the operation completes
;       properly, and 0lh if an error occurs during the read or write
;
;       in this case, we have saved the disk number in 'diskno' (0, 1)
;                       the track number in 'track' (0-76)
;                       the sector number in 'sector' (1-26)
;                       the dma address in 'dmaad' (0-65535)
        xor a
        pop hl
        pop de
        pop bc
        ret                     ;replaced when filled-in
;
;       the remainder of the cbios is reserved uninitialized
;       data area, and does not need to be a Part of the
;       system  memory image (the space must be available,
;       however, between"begdat" and"enddat").
;
track:  ds      2               ;two bytes for expansion
sector: ds      2               ;two bytes for expansion
dmaad:  ds      2               ;direct memory address
diskno: ds      1               ;disk number 0-15
;
;       scratch ram area for bdos use
begdat  equ     $               ;beginning of data area
dirbf:  ds      128             ;scratch directory area
all00:  ds      31              ;allocation vector 0
all01:  ds      31              ;allocation vector 1
all02:  ds      31              ;allocation vector 2
all03:  ds      31              ;allocation vector 3
chk00:  ds      16              ;check vector 0
chk01:  ds      16              ;check vector 1
chk02:  ds      16              ;check vector 2
chk03:  ds      16              ;check vector 3
;
bank1:  ds      2               ;bank address temporary storage 1
bank2:  ds      2               ;bank address temporary storage 2
bankno: ds      1               ;bank number
tbyte:  ds      1               ;transfer byte
;
enddat  equ     $               ;end of data area
datsiz  equ     $-begdat;       ;size of data area

include "sgterm.asm"
include "muldiv.asm"

        end
