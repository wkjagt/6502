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
VIA_PORTB                      = $6000
VIA_PORTA                      = $6001
VIA_DDRB                       = $6002
VIA_DDRA                       = $6003
VIA_PCR                        = $600c ; peripheral control register
VIA_IFR                        = $600d ; interrupt flag register
VIA_IER                        = $600e ; interrupt enable register

KEYB_RELEASE                   = %00000001
KEYB_SHIFT                     = %00000010

CURSOR_ON                      = %00000001
VIDEO_BUFFER_STALE             = %00000010

ASCII_ENTER                    = $0a
ASCII_BACKSPACE                = $08

KEYB_RELEASE_CODE              = $F0
KEYB_LEFT_SHIFT_CODE           = $12
KEYB_RIGHT_SHIFT_CODE          = $59

END_OF_SCREEN_BUFFER           = $ff

;======================= zero page addresses =======================
    .dsect
    .org $30
vdp_pattern_init:    reserve 2
flags:               reserve 1

; keyboard
keyb_rptr:           reserve 1
keyb_wptr:           reserve 1
keyb_flags:          reserve 1

; 16 bit pointer used for looping over the screen buffer and writing to VDP
screen_buffer_rptr:  reserve 2
; 16 bit pointer to where the next character is written to the screen buffer
screen_buffer_wptr:  reserve 2

cursor_column:       reserve 1
cursor_row:          reserve 1
    .dend
;======================= /zero page addresses =======================

keyb_buffer                    = $0200 ; one page for keyboard buffer

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
    jsr keyboard_setup
    jsr screen_setup
    lda #0
    sta flags
    cli
    jmp program_loop

screen_setup:
    jsr reset_screen_buffer_rptr
    lda #0
    sta cursor_column
    lda #2
    sta cursor_row
    jsr calculate_cursor_pos
    rts

keyboard_setup:
    lda #0
    sta keyb_rptr
    sta keyb_wptr
    sta keyb_flags
    rts

program_loop:
    jsr update_vram
    jsr keypress_handler
    jmp program_loop

blink_cursor:
    jsr calculate_cursor_pos
    lda flags
    eor #CURSOR_ON ; cursor state on / off for blinking
    sta flags
    bit #CURSOR_ON
    beq .cursor_off
    lda #("~" + 1)
    jmp .print_cursor
.cursor_off:
    lda #"_"
.print_cursor:
    jsr write_to_buffer
    rts

keypress_handler:
    lda keyb_rptr
    cmp keyb_wptr
    bne .keys_in_buffer
    rts
.keys_in_buffer:
    jsr calculate_cursor_pos
    ; sei
    ldx keyb_rptr
    inc keyb_rptr
    lda keyb_buffer, x
.enter:
    cmp #ASCII_ENTER
    bne .backspace
    jsr line_feed
    jmp .done
.backspace:
    cmp #ASCII_BACKSPACE
    bne .write_char
    lda #" " ; clear cursor
    jsr write_to_buffer
    lda cursor_column
    beq .done
    dec cursor_column
    jmp .done
.write_char:
    tax
    lda cursor_column
    cmp #39
    beq .done
    txa
    jsr write_to_buffer
    inc cursor_column
.done:
    jsr blink_cursor
    cli
    rts

line_feed:
    lda #0
    jsr write_to_buffer ; clear cursor
    lda #0
    sta cursor_column
    lda cursor_row
    cmp #21
    beq .scroll
    inc cursor_row
    jmp .done
.scroll:
    jsr scroll_up
    lda #0
    sta cursor_column
.done:
    rts

write_to_buffer:
    sta (screen_buffer_wptr)
    lda flags
    ora #VIDEO_BUFFER_STALE  ; stale video
    sta flags
    rts

scroll_up:
    ; starting at position 40, copy all characters to 40 positions to
    ; the left in the screenbuffer
    ; sei
    jsr reset_screen_buffer_wptr ; start writing at the start of screen buffer
    jsr reset_screen_buffer_rptr
    ; set read pointer to 40 after screen buffer
    clc
    lda #(<screenbuffer)
    adc #40
    sta screen_buffer_rptr
    lda screen_buffer_rptr + 1
    adc #0
    sta screen_buffer_rptr + 1
.loop:
    lda (screen_buffer_rptr)
    cmp #END_OF_SCREEN_BUFFER
    beq .done
    jsr write_to_buffer
    jsr incr_screen_buffer_rptr
    jsr incr_screen_buffer_wptr
    jmp .loop
.done:
    ; cli
    rts

calculate_cursor_pos:
    pha ; push A onto the stack because it contains the character to write
    ; and it's being overwritten in this routine to calculate the position

    jsr reset_screen_buffer_wptr
    ; calculate buffer offset from row and column
    ; calculation = (row * 40) + column
    ldx #0
.multiply:
    ; add 40 to the write pointer for the number of times in the row value
    lda screen_buffer_wptr
    clc
    adc #$28  ; add 40
    sta screen_buffer_wptr
    lda screen_buffer_wptr + 1
    adc #0    ; add whatever is in the carry flag
    sta screen_buffer_wptr + 1
    inx
    cpx cursor_row
    bne .multiply
    ; add the column value
    lda screen_buffer_wptr
    clc
    adc cursor_column
    sta screen_buffer_wptr
    lda screen_buffer_wptr + 1
    adc #0    ; add whatever is in the carry flag
    sta screen_buffer_wptr + 1
    pla
    rts

io_setup:
    lda #0                         ; set port A as input (for keyboard)
    sta VIA_DDRA
    ; sta VIA_DDRB
    ; enable interrupts on CA1 and CB1:
    ; CA1 is used by the PS/2 keyboard when all data is available on the shift registers
    ; CB1 is used by the 555 timer for slowly timed things like the cursor
    lda #%10010010                 ; enable interrupt on CA1 and CB1
    sta VIA_IER
    lda #%00000001                 ; set CA1 as positive active edge
    sta VIA_PCR
    rts

irq:
    pha
    phy
    phx
.io_irq:
    lda VIA_IFR
    asl a                         ; IRQ
    bcc .done                     ; no interrupt on the 6502
.timer1
    asl a
.timer2:
    asl a
.cb1:
    asl a
    bcc .cb2
    jsr slow_clock_interrupt
.cb2:
    asl a
.shift_reg:
    asl a
.ca1:
    asl a
    bcc .ca2
    jsr keyboard_interrupt
.ca2:
    asl a
.done
    plx
    ply
    pla
    rts

slow_clock_interrupt:
    pha
    jsr blink_cursor
    pla 
    bit VIA_PORTB  ; only to clear the interrupt because this uses CB1
    rts            ; NOTE: use CA2 instead

keyboard_interrupt:
    pha
    phx
    lda keyb_flags                  ; read the current keyboard flags
    and #KEYB_RELEASE               ; see if the previous scan code was for a key release 
    beq .read_key                   ; if it isn't, go ahead and read the key
    lda keyb_flags                  
    eor #KEYB_RELEASE               ; the previous code was a release, so the new code
                                    ; is for the key that's being released.
    sta keyb_flags                  ; Turn off the release flag
    lda VIA_PORTA                   ; Read the key that's being released
    cmp #KEYB_LEFT_SHIFT_CODE       ; It's the shift key that was released: handle that case
    beq .shift_up
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_up
    jmp .done
.shift_up:
    lda keyb_flags                  ; turn off the shift flag
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
.done
    plx
    pla
    rts


;======================= VDP routines =======================

update_vram:
    lda flags
    bit #VIDEO_BUFFER_STALE
    beq .done
    and #(~VIDEO_BUFFER_STALE)
    sta flags
    jsr reset_screen_buffer_rptr
    vdp_write_vram VDP_NAME_TABLE_BASE
.screenbuffer_loop:
    lda (screen_buffer_rptr)
    cmp #END_OF_SCREEN_BUFFER
    beq .done
    sec
    sbc #$20                                ; ascii characters in VDP 
    sta VDP_VRAM
    jsr incr_screen_buffer_rptr
    jmp .screenbuffer_loop
.done
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
    sta vdp_pattern_init
    lda #>vdp_patterns
    sta vdp_pattern_init + 1
vdp_pattern_table_loop:
    lda (vdp_pattern_init)                  ; load A with the value at vdp_pattern_init 
    sta VDP_VRAM                            ; and store it to VRAM
    lda vdp_pattern_init                    ; load the low byte of vdp_pattern_init address into A
    clc                                     ; clear carry flag
    adc #1                                  ; Add 1, with carry
    sta vdp_pattern_init                    ; store back into vdp_pattern_init
    lda #0                                  ; load A with 0
    adc vdp_pattern_init + 1                 ; add with the carry flag to the high address
    sta vdp_pattern_init + 1                 ; and store that back into the high byte
    cmp #>vdp_end_patterns                  ; compare if we're at the end of the patterns
    bne vdp_pattern_table_loop              ; if not, loop again
    lda vdp_pattern_init                    ; compare the low byte
    cmp #<vdp_end_patterns
    bne vdp_pattern_table_loop              ; if not equal, loop again
    plx
    pla
    rts

vdp_enable_display:
    lda #$71                               ; fg / bg colours
    sta VDP_REG
    lda #(VDP_REGISTER_BITS | 7)           ; register select (selecting register 1)
    sta VDP_REG

    lda #%11110000                         ; 16k Bl IE M1 M2 0 Siz MAG 
    sta VDP_REG
    lda #(VDP_REGISTER_BITS | 1)           ; register select (selecting register 1)
    sta VDP_REG
    rts

;======================= Utility routines =======================

reset_screen_buffer_wptr:
    lda #(<screenbuffer)
    sta screen_buffer_wptr
    lda #(>screenbuffer)
    sta screen_buffer_wptr + 1
    rts

reset_screen_buffer_rptr:
    lda #(<screenbuffer)
    sta screen_buffer_rptr
    lda #(>screenbuffer)
    sta screen_buffer_rptr + 1
    rts

incr_screen_buffer_rptr:
    inc screen_buffer_rptr
    bne .done
    inc screen_buffer_rptr + 1
.done:
    rts

incr_screen_buffer_wptr:
    inc screen_buffer_wptr
    bne .done
    inc screen_buffer_wptr + 1
.done:
    rts

;======================= Data =======================

vdp_patterns:
  ; characters follow ASCII order but leave out all non printing characters
  ; before the space character
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
; non ascii
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00 ; cursor
vdp_end_patterns:


keymap: ; scancode to ascii code
  .byte "????????????? `?" ; 00-0F           ; 0d: tab
  .byte "?????q1???zsaw2?" ; 10-1F
  .byte "?cxde43?? vftr5?" ; 20-2F           ; 29: spacebar
  .byte "?nbhgy6???mju78?" ; 30-3F
  .byte "?,kio09??./l;p-?" ; 40-4F
  .byte "??'?[=????",$0a,"]?\??" ; 50-5F     ; 0a: enter / line feed
  .byte "??????",$08,"??1?47???" ; 60-6F     ; 06: backspace
  .byte "0.2568",$1b,"??+3-*9??" ; 70-7F     ; 1b: esc
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
    .byte "              < 6502 OS >               "
    .blk 23 * 40
    .byte END_OF_SCREEN_BUFFER ; end of screen, to check when to stop writing to vram