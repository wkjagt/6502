; Video - TMS9918A
VDP_VRAM                       = $8000
VDP_REG                        = $8001
VDP_WRITE_VRAM_BIT             = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS              = %10000000  ; pattern of second register write: 10000RRR
VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

; io
VIA_PORTB     = $6000
VIA_PORTA     = $6001
VIA_DDRB      = $6002
VIA_DDRA      = $6003
VIA_PCR       = $600c ; peripheral control register
VIA_IFR       = $600d ; interrupt flag register
VIA_IER       = $600e ; interrupt enable register

; zero page addresses
VDP_PATTERN_INIT    = $30
VDP_PATTERN_INIT_HI = $31

; keyboard
keyb_wptr           = $32
keyb_rptr           = $33
keyb_flags          = $34
keyb_buffer         = $0200

KEYB_RELEASE        = %00000001
KEYB_SHIFT          = %00000010

KEYB_RELEASE_CODE     = $F0
KEYB_LEFT_SHIFT_CODE  = $12
KEYB_RIGHT_SHIFT_CODE = $59
KEYB_BACKSPACE_CODE   = $66

; screen
screen_wptr         = $35

    .org $0300
  
system_irq:
    jsr irq
    rts

    .org $0308

    .macro vdp_write_vram
    pha
    lda #<(\1)
    sta VDP_REG
    lda #(VDP_WRITE_VRAM_BIT | >\1) ; see second register write pattern
    sta VDP_REG
    pla
    .endm

reset:
    jsr vdp_setup
    jsr io_setup
    lda #0
    sta keyb_rptr
    sta keyb_wptr
    sta screen_wptr
    sta keyb_flags
    cli

program_loop:
    jmp program_loop

io_setup:
    lda #0                         ; set port A as input (for keyboard)
    sta VIA_DDRA
    lda #%10000010                 ; enable interrupt on CA1
    sta VIA_IER
    lda #%00000001                 ; set CA1 as positive active edge
    sta VIA_PCR
    rts

irq:
    pha
    phy
    phx
    lda VDP_REG                   ; read VDP status register
    and #%10000000                ; highest bit is interrupt flag
    beq .test_keyboard            ; beq happens when all zeros, so no interrupt from VDP
    jsr vdp_interrupt
    jmp .done
.test_keyboard:
    lda VIA_IFR
    and #%10000010
    beq .done
    jsr keyboard_interrupt
.done
    plx
    ply
    pla
    rts

keyboard_interrupt:
    lda keyb_flags
    and #KEYB_RELEASE
    beq .read_key
    lda keyb_flags
    eor #KEYB_RELEASE
    sta keyb_flags
    lda VIA_PORTA                   ; read the key that's being released
    cmp #KEYB_LEFT_SHIFT_CODE
    beq .shift_up
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_up
    jmp .done
.shift_up:
    lda keyb_flags
    eor #KEYB_SHIFT
    sta keyb_flags
    jmp .done
.read_key:
    ldx VIA_PORTA                   ; load ps/2 scan code
    txa
    cmp #KEYB_RELEASE_CODE          ; keyboard release code
    beq .key_release
    cmp #KEYB_LEFT_SHIFT_CODE
    beq .shift_down
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_down
    cmp #KEYB_BACKSPACE_CODE
    beq .backspace

    lda keyb_flags
    and #KEYB_SHIFT
    bne .shifted_key
    lda keymap, x
    jmp .push_key
.shifted_key:
    lda keymap_shifted, x
.push_key:
    ldx keyb_wptr
    sta keyb_buffer, x
    inc keyb_wptr
    jmp .done
.shift_down:
    lda keyb_flags
    ora #KEYB_SHIFT
    sta keyb_flags
    jmp .done
.key_release:
    lda keyb_flags
    ora #KEYB_RELEASE
    sta keyb_flags
    jmp .done
.backspace:
    
.done
    rts

; ====================================================================================
;                              VDP RELATED ROUTINES
; ====================================================================================

vdp_interrupt:
    lda keyb_rptr
    cmp keyb_wptr
    bne .key_pressed
    rts
.key_pressed:
    lda #<(VDP_NAME_TABLE_BASE)
    adc screen_wptr
    sta VDP_REG
    lda #(VDP_WRITE_VRAM_BIT | >VDP_NAME_TABLE_BASE)
    sta VDP_REG
    inc screen_wptr

    ldx keyb_rptr
    lda keyb_buffer, x
    sta VDP_VRAM
    inc keyb_rptr
    rts

vdp_setup:
    jsr vdp_initialize_pattern_table
    jsr vdp_enable_display
    rts

vdp_initialize_pattern_table:
    pha
    phx
    vdp_write_vram VDP_PATTERN_TABLE_BASE   ; write the vram pattern table address to the 9918
    lda #<vdp_patterns                      ; load the start address of the patterns to zero page
    sta VDP_PATTERN_INIT
    lda #>vdp_patterns
    sta VDP_PATTERN_INIT_HI
vdp_pattern_table_loop:
    lda (VDP_PATTERN_INIT)                  ; load A with the value at VDP_PATTERN_INIT 
    sta VDP_VRAM                            ; and store it to VRAM
    lda VDP_PATTERN_INIT                    ; load the low byte of VDP_PATTERN_INIT address into A
    clc                                     ; clear carry flag
    adc #1                                  ; Add 1, with carry
    sta VDP_PATTERN_INIT                    ; store back into VDP_PATTERN_INIT
    lda #0                                  ; load A with 0
    adc VDP_PATTERN_INIT_HI                 ; add with the carry flag to the high address
    sta VDP_PATTERN_INIT_HI                 ; and store that back into the high byte
    cmp #>vdp_end_patterns                  ; compare if we're at the end of the patterns
    bne vdp_pattern_table_loop              ; if not, loop again
    lda VDP_PATTERN_INIT                    ; compare the low byte
    cmp #<vdp_end_patterns
    bne vdp_pattern_table_loop              ; if not equal, loop again

    plx
    pla
    rts

vdp_enable_display:
    lda #$c0                               ; 16k Bl IE M1 M2 0 Siz MAG 
    sta VDP_REG
    lda #(VDP_REGISTER_BITS | 7)           ; register select (selecting register 1)
    sta VDP_REG

    lda #%11110000                         ; 16k Bl IE M1 M2 0 Siz MAG 
    sta VDP_REG
    lda #(VDP_REGISTER_BITS | 1)           ; register select (selecting register 1)
    sta VDP_REG
    rts

vdp_patterns:
; line drawing
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; lr
  .byte $18,$18,$18,$18,$18,$18,$18,$18 ; ud
  .byte $00,$00,$00,$F8,$F8,$18,$18,$18 ; ld
  .byte $00,$00,$00,$1F,$1F,$18,$18,$18 ; rd
  .byte $18,$18,$18,$F8,$F8,$00,$00,$00 ; lu
  .byte $18,$18,$18,$1F,$1F,$00,$00,$00 ; ur
  .byte $18,$18,$18,$FF,$FF,$18,$18,$18 ; lurd
; ; <nonsense for debug>
  .byte $07,$07,$07,$07,$07,$07,$07,$00 ; 07
  .byte $08,$08,$08,$08,$08,$08,$08,$00 ; 08
  .byte $09,$09,$09,$09,$09,$09,$09,$00 ; 09
  .byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$00 ; 0A
  .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$00 ; 0B
  .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00 ; 0C
  .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$00 ; 0D
  .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$00 ; 0E
  .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$00 ; 0F
  .byte $10,$10,$10,$10,$10,$10,$10,$00 ; 10
  .byte $11,$11,$11,$11,$11,$11,$11,$00 ; 11
  .byte $12,$12,$12,$12,$12,$12,$12,$00 ; 12
  .byte $13,$13,$13,$13,$13,$13,$13,$00 ; 13
  .byte $14,$14,$14,$14,$14,$14,$14,$00 ; 14
  .byte $15,$15,$15,$15,$15,$15,$15,$00 ; 15
  .byte $16,$16,$16,$16,$16,$16,$16,$00 ; 16
  .byte $17,$17,$17,$17,$17,$17,$17,$00 ; 17
  .byte $18,$18,$18,$18,$18,$18,$18,$00 ; 18
  .byte $19,$19,$19,$19,$19,$19,$19,$00 ; 19
  .byte $1A,$1A,$1A,$1A,$1A,$1A,$1A,$00 ; 1A
  .byte $1B,$1B,$1B,$1B,$1B,$1B,$1B,$00 ; 1B
  .byte $1C,$1C,$1C,$1C,$1C,$1C,$1C,$00 ; 1C
  .byte $1D,$1D,$1D,$1D,$1D,$1D,$1D,$00 ; 1D
  .byte $1E,$1E,$1E,$1E,$1E,$1E,$1E,$00 ; 1E
  .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$00 ; 1F
; </nonsense>
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; ' '
  .byte $00, $00, $18, $18, $00, $00, $18, $18, $18, $18, $18, $18, $18 ; !
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $36, $36, $36, $36 ; "
  .byte $00, $00, $00, $66, $66, $ff, $66, $66, $ff, $66, $66, $00, $00 ; #
  .byte $00, $00, $18, $7e, $ff, $1b, $1f, $7e, $f8, $d8, $ff, $7e, $18 ; $
  .byte $00, $00, $0e, $1b, $db, $6e, $30, $18, $0c, $76, $db, $d8, $70 ; %
  .byte $00, $00, $7f, $c6, $cf, $d8, $70, $70, $d8, $cc, $cc, $6c, $38 ; &
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $1c, $0c, $0e ; '
  .byte $00, $00, $0c, $18, $30, $30, $30, $30, $30, $30, $30, $18, $0c ; (
  .byte $00, $00, $30, $18, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $18, $30 ; )
  .byte $00, $00, $00, $00, $99, $5a, $3c, $ff, $3c, $5a, $99, $00, $00 ; *
  .byte $00, $00, $00, $18, $18, $18, $ff, $ff, $18, $18, $18, $00, $00 ; +
  .byte $00, $00, $30, $18, $1c, $1c, $00, $00, $00, $00, $00, $00, $00 ; ,
  .byte $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $00, $00, $00, $00 ; -
  .byte $00, $00, $00, $38, $38, $00, $00, $00, $00, $00, $00, $00, $00 ; .
  .byte $00, $60, $60, $30, $30, $18, $18, $0c, $0c, $06, $06, $03, $03 ; /
  .byte $00, $00, $3c, $66, $c3, $e3, $f3, $db, $cf, $c7, $c3, $66, $3c ; 0
  .byte $00, $00, $7e, $18, $18, $18, $18, $18, $18, $18, $78, $38, $18 ; 1
  .byte $00, $00, $ff, $c0, $c0, $60, $30, $18, $0c, $06, $03, $e7, $7e ; 2
  .byte $00, $00, $7e, $e7, $03, $03, $07, $7e, $07, $03, $03, $e7, $7e ; 3
  .byte $00, $00, $0c, $0c, $0c, $0c, $0c, $ff, $cc, $6c, $3c, $1c, $0c ; 4
  .byte $00, $00, $7e, $e7, $03, $03, $07, $fe, $c0, $c0, $c0, $c0, $ff ; 5
  .byte $00, $00, $7e, $e7, $c3, $c3, $c7, $fe, $c0, $c0, $c0, $e7, $7e ; 6
  .byte $00, $00, $30, $30, $30, $30, $18, $0c, $06, $03, $03, $03, $ff ; 7
  .byte $00, $00, $7e, $e7, $c3, $c3, $e7, $7e, $e7, $c3, $c3, $e7, $7e ; 8
  .byte $00, $00, $7e, $e7, $03, $03, $03, $7f, $e7, $c3, $c3, $e7, $7e ; 9
  .byte $00, $00, $00, $38, $38, $00, $00, $38, $38, $00, $00, $00, $00 ; :
  .byte $00, $00, $30, $18, $1c, $1c, $00, $00, $1c, $1c, $00, $00, $00 ; ;
  .byte $00, $00, $06, $0c, $18, $30, $60, $c0, $60, $30, $18, $0c, $06 ; <
  .byte $00, $00, $00, $00, $ff, $ff, $00, $ff, $ff, $00, $00, $00, $00 ; =
  .byte $00, $00, $60, $30, $18, $0c, $06, $03, $06, $0c, $18, $30, $60 ; >
  .byte $00, $00, $18, $00, $00, $18, $18, $0c, $06, $03, $c3, $c3, $7e ; ?
  .byte $00, $00, $3f, $60, $cf, $db, $d3, $dd, $c3, $7e, $00, $00, $00 ; @
  .byte $00, $00, $c3, $c3, $c3, $c3, $ff, $c3, $c3, $c3, $66, $3c, $18 ; A
  .byte $00, $00, $fe, $c7, $c3, $c3, $c7, $fe, $c7, $c3, $c3, $c7, $fe ; B
  .byte $00, $00, $7e, $e7, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $e7, $7e ; C
  .byte $00, $00, $fc, $ce, $c7, $c3, $c3, $c3, $c3, $c3, $c7, $ce, $fc ; D
  .byte $00, $00, $ff, $c0, $c0, $c0, $c0, $fc, $c0, $c0, $c0, $c0, $ff ; E
  .byte $00, $00, $c0, $c0, $c0, $c0, $c0, $c0, $fc, $c0, $c0, $c0, $ff ; F
  .byte $00, $00, $7e, $e7, $c3, $c3, $cf, $c0, $c0, $c0, $c0, $e7, $7e ; G
  .byte $00, $00, $c3, $c3, $c3, $c3, $c3, $ff, $c3, $c3, $c3, $c3, $c3 ; H
  .byte $00, $00, $7e, $18, $18, $18, $18, $18, $18, $18, $18, $18, $7e ; I
  .byte $00, $00, $7c, $ee, $c6, $06, $06, $06, $06, $06, $06, $06, $06 ; J
  .byte $00, $00, $c3, $c6, $cc, $d8, $f0, $e0, $f0, $d8, $cc, $c6, $c3 ; K
  .byte $00, $00, $ff, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0 ; L
  .byte $00, $00, $c3, $c3, $c3, $c3, $c3, $c3, $db, $ff, $ff, $e7, $c3 ; M
  .byte $00, $00, $c7, $c7, $cf, $cf, $df, $db, $fb, $f3, $f3, $e3, $e3 ; N
  .byte $00, $00, $7e, $e7, $c3, $c3, $c3, $c3, $c3, $c3, $c3, $e7, $7e ; O
  .byte $00, $00, $c0, $c0, $c0, $c0, $c0, $fe, $c7, $c3, $c3, $c7, $fe ; P
  .byte $00, $00, $3f, $6e, $df, $db, $c3, $c3, $c3, $c3, $c3, $66, $3c ; Q
  .byte $00, $00, $c3, $c6, $cc, $d8, $f0, $fe, $c7, $c3, $c3, $c7, $fe ; R
  .byte $00, $00, $7e, $e7, $03, $03, $07, $7e, $e0, $c0, $c0, $e7, $7e ; S
  .byte $00, $00, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $ff ; T
  .byte $00, $00, $7e, $e7, $c3, $c3, $c3, $c3, $c3, $c3, $c3, $c3, $c3 ; U
  .byte $00, $00, $18, $3c, $3c, $66, $66, $c3, $c3, $c3, $c3, $c3, $c3 ; V
  .byte $00, $00, $c3, $e7, $ff, $ff, $db, $db, $c3, $c3, $c3, $c3, $c3 ; W
  .byte $00, $00, $c3, $66, $66, $3c, $3c, $18, $3c, $3c, $66, $66, $c3 ; X
  .byte $00, $00, $18, $18, $18, $18, $18, $18, $3c, $3c, $66, $66, $c3 ; Y
  .byte $00, $00, $ff, $c0, $c0, $60, $30, $7e, $0c, $06, $03, $03, $ff ; Z
  .byte $00, $00, $3c, $30, $30, $30, $30, $30, $30, $30, $30, $30, $3c ; [
  .byte $00, $03, $03, $06, $06, $0c, $0c, $18, $18, $30, $30, $60, $60 ; \
  .byte $00, $00, $3c, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $3c ; ]
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $c3, $66, $3c, $18 ; ^
  .byte $ff, $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; _
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $38, $30, $70 ; `
  .byte $00, $00, $7f, $c3, $c3, $7f, $03, $c3, $7e, $00, $00, $00, $00 ; a
  .byte $00, $00, $fe, $c3, $c3, $c3, $c3, $fe, $c0, $c0, $c0, $c0, $c0 ; b
  .byte $00, $00, $7e, $c3, $c0, $c0, $c0, $c3, $7e, $00, $00, $00, $00 ; c
  .byte $00, $00, $7f, $c3, $c3, $c3, $c3, $7f, $03, $03, $03, $03, $03 ; d
  .byte $00, $00, $7f, $c0, $c0, $fe, $c3, $c3, $7e, $00, $00, $00, $00 ; e
  .byte $00, $00, $30, $30, $30, $30, $30, $fc, $30, $30, $30, $33, $1e ; f
  .byte $7e, $c3, $03, $03, $7f, $c3, $c3, $c3, $7e, $00, $00, $00, $00 ; g
  .byte $00, $00, $c3, $c3, $c3, $c3, $c3, $c3, $fe, $c0, $c0, $c0, $c0 ; h
  .byte $00, $00, $18, $18, $18, $18, $18, $18, $18, $00, $00, $18, $00 ; i
  .byte $38, $6c, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $00, $00, $0c, $00 ; j
  .byte $00, $00, $c6, $cc, $f8, $f0, $d8, $cc, $c6, $c0, $c0, $c0, $c0 ; k
  .byte $00, $00, $7e, $18, $18, $18, $18, $18, $18, $18, $18, $18, $78 ; l
  .byte $00, $00, $db, $db, $db, $db, $db, $db, $fe, $00, $00, $00, $00 ; m
  .byte $00, $00, $c6, $c6, $c6, $c6, $c6, $c6, $fc, $00, $00, $00, $00 ; n
  .byte $00, $00, $7c, $c6, $c6, $c6, $c6, $c6, $7c, $00, $00, $00, $00 ; o
  .byte $c0, $c0, $c0, $fe, $c3, $c3, $c3, $c3, $fe, $00, $00, $00, $00 ; p
  .byte $03, $03, $03, $7f, $c3, $c3, $c3, $c3, $7f, $00, $00, $00, $00 ; q
  .byte $00, $00, $c0, $c0, $c0, $c0, $c0, $e0, $fe, $00, $00, $00, $00 ; r
  .byte $00, $00, $fe, $03, $03, $7e, $c0, $c0, $7f, $00, $00, $00, $00 ; s
  .byte $00, $00, $1c, $36, $30, $30, $30, $30, $fc, $30, $30, $30, $00 ; t
  .byte $00, $00, $7e, $c6, $c6, $c6, $c6, $c6, $c6, $00, $00, $00, $00 ; u
  .byte $00, $00, $18, $3c, $3c, $66, $66, $c3, $c3, $00, $00, $00, $00 ; v
  .byte $00, $00, $c3, $e7, $ff, $db, $c3, $c3, $c3, $00, $00, $00, $00 ; w
  .byte $00, $00, $c3, $66, $3c, $18, $3c, $66, $c3, $00, $00, $00, $00 ; x
  .byte $c0, $60, $60, $30, $18, $3c, $66, $66, $c3, $00, $00, $00, $00 ; y
  .byte $00, $00, $ff, $60, $30, $18, $0c, $06, $ff, $00, $00, $00, $00 ; z
  .byte $00, $00, $0f, $18, $18, $18, $38, $f0, $38, $18, $18, $18, $0f ; {
  .byte $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18 ; |
  .byte $00, $00, $f0, $18, $18, $18, $1c, $0f, $1c, $18, $18, $18, $f0 ; }
  .byte $00, $00, $00, $00, $00, $00, $06, $8f, $f1, $60, $00, $00, $00 ; ~
  .byte $A8,$50,$A8,$50,$A8,$50,$A8,$00 ; checkerboard
vdp_end_patterns:


keymap:
  .byte "????????????? `?" ; 00-0F
  .byte "?????q1???zsaw2?" ; 10-1F
  .byte "?cxde43?? vftr5?" ; 20-2F
  .byte "?nbhgy6???mju78?" ; 30-3F
  .byte "?,kio09??./l;p-?" ; 40-4F
  .byte "??'?[=????",$0a,"]?\??" ; 50-5F
  .byte "?????????1?47???" ; 60-6F
  .byte "0.2568",$1b,"??+3-*9??" ; 70-7F
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF
keymap_shifted:
  .byte "????????????? ~?" ; 00-0F
  .byte "?????Q!???ZSAW@?" ; 10-1F
  .byte "?CXDE#$?? VFTR%?" ; 20-2F
  .byte "?NBHGY^???MJU&*?" ; 30-3F
  .byte "?<KIO)(??>?L:P_?" ; 40-4F
  .byte '??"?{+?????}?|??' ; 50-5F
  .byte "?????????1?47???" ; 60-6F
  .byte "0.2568???+3-*9??" ; 70-7F
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF

screenbuffer:
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
endscreenbuffer
