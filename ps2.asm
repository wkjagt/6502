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
keyb_buffer         = $0200 ; one page for keyboard buffer

KEYB_RELEASE        = %00000001
KEYB_SHIFT          = %00000010

KEYB_RELEASE_CODE     = $F0
KEYB_LEFT_SHIFT_CODE  = $12
KEYB_RIGHT_SHIFT_CODE = $59
KEYB_BACKSPACE_CODE   = $66

; screen
screen_wptr_h          = $35
screen_wptr_l          = $36

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
    sta keyb_flags
    lda #80
    sta screen_wptr_h
    cli

program_loop:
    jsr keypress_handler
    jmp program_loop

keypress_handler:
    lda keyb_rptr
    cmp keyb_wptr
    bne .keys_in_buffer
    rts
.keys_in_buffer:
    sei
    ldx keyb_rptr
    lda keyb_buffer, x
    ldx screen_wptr_h
    sta screenbuffer, x
    inc keyb_rptr
    inc screen_wptr_h
    inx
    lda #"_"                       ; cursor
    sta screenbuffer, x
    cli
    rts

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
    pha
    phx

    vdp_write_vram VDP_NAME_TABLE_BASE
    ldx #0
.screenbuffer_loop:
    lda screenbuffer, x
    sta VDP_VRAM
    inx
    bne .screenbuffer_loop
.done
    plx
    pla
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
    lda #$21                               ; fg / bg colours
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
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; ' '
  .byte $20,$20,$20,$00,$20,$20,$00,$00 ; !
  .byte $50,$50,$50,$00,$00,$00,$00,$00 ; "
  .byte $50,$50,$F8,$50,$F8,$50,$50,$00 ; #
  .byte $20,$78,$A0,$70,$28,$F0,$20,$00 ; $
  .byte $C0,$C8,$10,$20,$40,$98,$18,$00 ; %
  .byte $40,$A0,$A0,$40,$A8,$90,$68,$00 ; &
  .byte $20,$20,$40,$00,$00,$00,$00,$00 ; '
  .byte $20,$40,$80,$80,$80,$40,$20,$00 ; (
  .byte $20,$10,$08,$08,$08,$10,$20,$00 ; )
  .byte $20,$A8,$70,$20,$70,$A8,$20,$00 ; *
  .byte $00,$20,$20,$F8,$20,$20,$00,$00 ; +
  .byte $00,$00,$00,$00,$20,$20,$40,$00 ; ,
  .byte $00,$00,$00,$F8,$00,$00,$00,$00 ; -
  .byte $00,$00,$00,$00,$20,$20,$00,$00 ; .
  .byte $00,$08,$10,$20,$40,$80,$00,$00 ; /
  .byte $70,$88,$98,$A8,$C8,$88,$70,$00 ; 0
  .byte $20,$60,$20,$20,$20,$20,$70,$00 ; 1
  .byte $70,$88,$08,$30,$40,$80,$F8,$00 ; 2
  .byte $F8,$08,$10,$30,$08,$88,$70,$00 ; 3
  .byte $10,$30,$50,$90,$F8,$10,$10,$00 ; 4
  .byte $F8,$80,$F0,$08,$08,$88,$70,$00 ; 5
  .byte $38,$40,$80,$F0,$88,$88,$70,$00 ; 6
  .byte $F8,$08,$10,$20,$40,$40,$40,$00 ; 7
  .byte $70,$88,$88,$70,$88,$88,$70,$00 ; 8
  .byte $70,$88,$88,$78,$08,$10,$E0,$00 ; 9
  .byte $00,$00,$20,$00,$20,$00,$00,$00 ; :
  .byte $00,$00,$20,$00,$20,$20,$40,$00 ; ;
  .byte $10,$20,$40,$80,$40,$20,$10,$00 ; <
  .byte $00,$00,$F8,$00,$F8,$00,$00,$00 ; =
  .byte $40,$20,$10,$08,$10,$20,$40,$00 ; >
  .byte $70,$88,$10,$20,$20,$00,$20,$00 ; ?
  .byte $70,$88,$A8,$B8,$B0,$80,$78,$00 ; @
  .byte $20,$50,$88,$88,$F8,$88,$88,$00 ; A
  .byte $F0,$88,$88,$F0,$88,$88,$F0,$00 ; B
  .byte $70,$88,$80,$80,$80,$88,$70,$00 ; C
  .byte $F0,$88,$88,$88,$88,$88,$F0,$00 ; D
  .byte $F8,$80,$80,$F0,$80,$80,$F8,$00 ; E
  .byte $F8,$80,$80,$F0,$80,$80,$80,$00 ; F
  .byte $78,$80,$80,$80,$98,$88,$78,$00 ; G
  .byte $88,$88,$88,$F8,$88,$88,$88,$00 ; H
  .byte $70,$20,$20,$20,$20,$20,$70,$00 ; I
  .byte $08,$08,$08,$08,$08,$88,$70,$00 ; J
  .byte $88,$90,$A0,$C0,$A0,$90,$88,$00 ; K
  .byte $80,$80,$80,$80,$80,$80,$F8,$00 ; L
  .byte $88,$D8,$A8,$A8,$88,$88,$88,$00 ; M
  .byte $88,$88,$C8,$A8,$98,$88,$88,$00 ; N
  .byte $70,$88,$88,$88,$88,$88,$70,$00 ; O
  .byte $F0,$88,$88,$F0,$80,$80,$80,$00 ; P
  .byte $70,$88,$88,$88,$A8,$90,$68,$00 ; Q
  .byte $F0,$88,$88,$F0,$A0,$90,$88,$00 ; R
  .byte $70,$88,$80,$70,$08,$88,$70,$00 ; S
  .byte $F8,$20,$20,$20,$20,$20,$20,$00 ; T
  .byte $88,$88,$88,$88,$88,$88,$70,$00 ; U
  .byte $88,$88,$88,$88,$50,$50,$20,$00 ; V
  .byte $88,$88,$88,$A8,$A8,$D8,$88,$00 ; W
  .byte $88,$88,$50,$20,$50,$88,$88,$00 ; X
  .byte $88,$88,$50,$20,$20,$20,$20,$00 ; Y
  .byte $F8,$08,$10,$20,$40,$80,$F8,$00 ; Z
  .byte $F8,$C0,$C0,$C0,$C0,$C0,$F8,$00 ; [
  .byte $00,$80,$40,$20,$10,$08,$00,$00 ; \
  .byte $F8,$18,$18,$18,$18,$18,$F8,$00 ; ]
  .byte $00,$00,$20,$50,$88,$00,$00,$00 ; ^
  .byte $00,$00,$00,$00,$00,$00,$F8,$00 ; _
  .byte $40,$20,$10,$00,$00,$00,$00,$00 ; `
  .byte $00,$00,$70,$88,$88,$98,$68,$00 ; a
  .byte $80,$80,$F0,$88,$88,$88,$F0,$00 ; b
  .byte $00,$00,$78,$80,$80,$80,$78,$00 ; c
  .byte $08,$08,$78,$88,$88,$88,$78,$00 ; d
  .byte $00,$00,$70,$88,$F8,$80,$78,$00 ; e
  .byte $30,$40,$E0,$40,$40,$40,$40,$00 ; f
  .byte $00,$00,$70,$88,$F8,$08,$F0,$00 ; g
  .byte $80,$80,$F0,$88,$88,$88,$88,$00 ; h
  .byte $00,$40,$00,$40,$40,$40,$40,$00 ; i
  .byte $00,$20,$00,$20,$20,$A0,$60,$00 ; j
  .byte $00,$80,$80,$A0,$C0,$A0,$90,$00 ; k
  .byte $C0,$40,$40,$40,$40,$40,$60,$00 ; l
  .byte $00,$00,$D8,$A8,$A8,$A8,$A8,$00 ; m
  .byte $00,$00,$F0,$88,$88,$88,$88,$00 ; n
  .byte $00,$00,$70,$88,$88,$88,$70,$00 ; o
  .byte $00,$00,$70,$88,$F0,$80,$80,$00 ; p
  .byte $00,$00,$F0,$88,$78,$08,$08,$00 ; q
  .byte $00,$00,$70,$88,$80,$80,$80,$00 ; r
  .byte $00,$00,$78,$80,$70,$08,$F0,$00 ; s
  .byte $40,$40,$F0,$40,$40,$40,$30,$00 ; t
  .byte $00,$00,$88,$88,$88,$88,$78,$00 ; u
  .byte $00,$00,$88,$88,$90,$A0,$40,$00 ; v
  .byte $00,$00,$88,$88,$88,$A8,$D8,$00 ; w
  .byte $00,$00,$88,$50,$20,$50,$88,$00 ; x
  .byte $00,$00,$88,$88,$78,$08,$F0,$00 ; y
  .byte $00,$00,$F8,$10,$20,$40,$F8,$00 ; z
  .byte $38,$40,$20,$C0,$20,$40,$38,$00 ; {
  .byte $40,$40,$40,$00,$40,$40,$40,$00 ; |
  .byte $E0,$10,$20,$18,$20,$10,$E0,$00 ; }
  .byte $40,$A8,$10,$00,$00,$00,$00,$00 ; ~
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

screenbuffer: ; a buffer of ascii codes to print to the screen
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"-",0,"6","5","0","2",0,"O","S",0,"-",0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte "_",0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
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
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"!"
