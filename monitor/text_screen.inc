    .include "macros.inc"
VDP_VRAM                       = $4400
VDP_REG                        = $4401
VDP_WRITE_VRAM_BIT             = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS              = %10000000  ; pattern of second register write: 10000RRR
VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

CURSOR_ON                      = %00000001
VIDEO_BUFFER_STALE             = %00000010
ENTER                          = $0D
LINEFEED                       = $0A
BACKSP                         = $08
ESC                            = $1B

SCREEN_WIDTH                   = 40
SCREEN_HEIGHT                  = 24
COLUMN_START                   = 1

; LOCATIONS
screenbuffer                   = $0300
; vdp_patterns                   = $C041
; vdp_end_patterns               = $C341

;======================= zero page addresses =======================
; Uses $10 - $18
;===================================================================
    .dsect
    .org $10
vdp_pattern_init:    reserve 2
screen_flags:        reserve 1

; 16 bit pointer used for looping over the screen buffer and writing to VDP
screen_buffer_rptr:  reserve 2
; 16 bit pointer to where the next character is written to the screen buffer
screen_buffer_wptr:  reserve 2

cursor_column:       reserve 1
cursor_row:          reserve 1
    .dend
;======================= /zero page addresses =======================


SCRNSETUP:
    lda #0
    sta screen_flags
    jsr vdp_initialize_pattern_table
    jsr vdp_initialize_color_table
    jsr vdp_enable_display
CLRSCRN:
    jsr init_screen_buffer
    jsr reset_screen_buffer_rptr
    lda #COLUMN_START
    sta cursor_column
    lda #0
    sta cursor_row
    jsr calculate_cursor_pos
    jsr blink_cursor
    rts

; The screen is 40 by 25, so 1000 bytes. Clear 4 pages of RAM to hold it.
init_screen_buffer:
    jsr reset_screen_buffer_wptr
    ldy #4    ; empty 4 pages of RAM to hold the screen buffer (3, 4, 5)
    ldx #255  ; page length
.next
    lda #0    ; fill with 0s
    sta (screen_buffer_wptr)
    jsr incr_screen_buffer_wptr
    dex
    bne .next
    dey
    bne .next
    rts

ECHO:
    jsr calculate_cursor_pos
    cmp #ENTER
    beq .enter
    cmp #BACKSP
    beq .backspace
    cmp #ESC
    beq .esc
    tax
    lda cursor_column
    cmp #SCREEN_WIDTH - 1
    beq .done
    txa
    jsr write_to_buffer
    inc cursor_column
    jmp .done
.enter:
    jsr line_feed
    jmp .done
.backspace:
    lda #" " ; clear cursor
    jsr write_to_buffer
    lda cursor_column
    cmp #COLUMN_START
    beq .done
    dec cursor_column
    jmp .done
.esc:
    jsr CLRSCRN
.done:
    jsr blink_cursor
    rts    

vdp_initialize_pattern_table:
    store_registers
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
    restore_registers
    rts

vdp_initialize_color_table:
    vdp_write_vram VDP_COLOR_TABLE_BASE
    ldx #$20
    lda #$71   ; color fg/bg
vdp_color_table_loop:
    sta VDP_VRAM
    dex
    bne vdp_color_table_loop
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

update_vram:
;==============================================================================
; Only update if we know VRAM is stale
;==============================================================================
    lda screen_flags
    bit #VIDEO_BUFFER_STALE
    beq .done
;==============================================================================
; Set flag to "not stale"
;==============================================================================
    and #(~VIDEO_BUFFER_STALE)
    sta screen_flags
;==============================================================================
; Start at beginning of buffer
;==============================================================================
    jsr reset_screen_buffer_rptr
    vdp_write_vram VDP_NAME_TABLE_BASE
.screenbuffer_loop:
    lda (screen_buffer_rptr)
;==============================================================================
; The first character that's supported is ASCII char with code $21, so
; sutracting $20 will give us the correct offset into the pattern table
;==============================================================================
    sec
    sbc #$20                                ; ascii characters in VDP 
    sta VDP_VRAM
    jsr incr_screen_buffer_rptr
;==============================================================================
; Once the high byte of the read pointer goes into the 6th page
; of the buffer, we know we're done.
;==============================================================================
    lda screen_buffer_rptr + 1
    cmp #6
    beq .done
    jmp .screenbuffer_loop
.done
    rts

calculate_cursor_pos:
    store_registers

    jsr reset_screen_buffer_wptr
    ; calculate buffer offset from row and column
    ; calculation = (row * 40) + column
    ldx #0
.multiply:
    cpx cursor_row
    beq .add
    inx
    lda screen_buffer_wptr
    clc
    adc #SCREEN_WIDTH
    sta screen_buffer_wptr
    lda screen_buffer_wptr + 1
    adc #0    ; add whatever is in the carry flag
    sta screen_buffer_wptr + 1
    bne .multiply
.add:
    ; add the column value
    lda screen_buffer_wptr
    clc
    adc cursor_column
    sta screen_buffer_wptr
    lda screen_buffer_wptr + 1
    adc #0    ; add whatever is in the carry flag
    sta screen_buffer_wptr + 1
    restore_registers
    rts

scroll_up:
    ; starting at position 32, copy all characters to 32 positions to
    ; the left in the screenbuffer
    sei
    jsr reset_screen_buffer_wptr ; start writing at the start of screen buffer
    jsr reset_screen_buffer_rptr
    ; set read pointer to 40 after screen buffer (start of second line)
    lda #(<screenbuffer)            ; load the LSB of the screenbuffer start address
    clc
    adc #SCREEN_WIDTH               ; add 40 to it, which is the left most position of the 2nd line
    sta screen_buffer_rptr          ; store that in the read pointer LSB
    lda screen_buffer_rptr + 1      ; load the MSB of the read pointer
    adc #0                          ; add the carry flag to it
    sta screen_buffer_rptr + 1
.loop:
    lda screen_buffer_rptr + 1
    cmp #6
    beq .done
    lda (screen_buffer_rptr)        ; load the character that the read pointer points to
    sta (screen_buffer_wptr)
    jsr incr_screen_buffer_rptr     ; advance both pointers
    jsr incr_screen_buffer_wptr

    jmp .loop
.done:
    lda screen_flags
    ora #VIDEO_BUFFER_STALE  ; stale video
    sta screen_flags
    jsr update_vram
    cli
    rts

line_feed:
    lda #0
    jsr write_to_buffer ; clear cursor
    lda #COLUMN_START
    sta cursor_column
    lda cursor_row
    cmp #22
    beq .scroll
    inc cursor_row
    jmp .done
.scroll:
    jsr scroll_up
    lda #COLUMN_START
    sta cursor_column
.done:
    rts

write_to_buffer:
    sta (screen_buffer_wptr)
    lda screen_flags
    ora #VIDEO_BUFFER_STALE  ; stale video
    sta screen_flags
    jsr update_vram
    rts

blink_cursor:
    store_registers
    jsr calculate_cursor_pos
    lda screen_flags
    eor #CURSOR_ON ; cursor state on / off for blinking
    sta screen_flags
    bit #CURSOR_ON
    beq .cursor_off
    lda #("~" + 1)
    jmp .print_cursor
.cursor_off:
    lda #"_"
.print_cursor:
    jsr write_to_buffer
    restore_registers
    rts

vdp_patterns:
;   .byte $00, $00, $00, $00, $00, $00, $00, $00
;   .byte $38, $44, $6c, $44, $54, $44, $38, $00
;   .byte $38, $7c, $54, $7c, $44, $7c, $38, $00
;   .byte $00, $28, $7c, $7c, $7c, $38, $10, $00
;   .byte $00, $10, $38, $7c, $7c, $38, $10, $00
;   .byte $10, $38, $38, $10, $7c, $7c, $10, $00
;   .byte $00, $10, $38, $7c, $7c, $10, $38, $00
;   .byte $00, $00, $00, $30, $30, $00, $00, $00
;   .byte $fc, $fc, $fc, $cc, $cc, $fc, $fc, $fc
;   .byte $00, $00, $78, $48, $48, $78, $00, $00
;   .byte $fc, $fc, $84, $b4, $b4, $84, $fc, $fc
;   .byte $00, $1c, $0c, $34, $48, $48, $30, $00
;   .byte $38, $44, $44, $38, $10, $38, $10, $00
;   .byte $10, $18, $14, $10, $30, $70, $60, $00
;   .byte $0c, $34, $2c, $34, $2c, $6c, $60, $00
;   .byte $00, $54, $38, $6c, $38, $54, $00, $00
;   .byte $20, $30, $38, $3c, $38, $30, $20, $00
;   .byte $08, $18, $38, $78, $38, $18, $08, $00
;   .byte $10, $38, $7c, $10, $7c, $38, $10, $00
;   .byte $28, $28, $28, $28, $28, $00, $28, $00
;   .byte $3c, $54, $54, $34, $14, $14, $14, $00
;   .byte $38, $44, $30, $28, $18, $44, $38, $00
;   .byte $00, $00, $00, $00, $00, $78, $78, $00
;   .byte $10, $38, $7c, $10, $7c, $38, $10, $38
;   .byte $10, $38, $7c, $10, $10, $10, $10, $00
;   .byte $10, $10, $10, $10, $7c, $38, $10, $00
;   .byte $00, $10, $18, $7c, $18, $10, $00, $00
;   .byte $00, $10, $30, $7c, $30, $10, $00, $00
;   .byte $00, $00, $00, $40, $40, $40, $7c, $00
;   .byte $00, $28, $28, $7c, $28, $28, $00, $00
;   .byte $10, $10, $38, $38, $7c, $7c, $00, $00
;   .byte $7c, $7c, $38, $38, $10, $10, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $10, $38, $38, $10, $10, $00, $10, $00
  .byte $6c, $6c, $48, $00, $00, $00, $00, $00
  .byte $00, $28, $7c, $28, $28, $7c, $28, $00
  .byte $20, $38, $40, $30, $08, $70, $10, $00
  .byte $64, $64, $08, $10, $20, $4c, $4c, $00
  .byte $20, $50, $50, $20, $54, $48, $34, $00
  .byte $30, $30, $20, $00, $00, $00, $00, $00
  .byte $10, $20, $20, $20, $20, $20, $10, $00
  .byte $20, $10, $10, $10, $10, $10, $20, $00
  .byte $00, $28, $38, $7c, $38, $28, $00, $00
  .byte $00, $10, $10, $7c, $10, $10, $00, $00
  .byte $00, $00, $00, $00, $00, $30, $30, $20
  .byte $00, $00, $00, $7c, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $30, $30, $00
  .byte $00, $04, $08, $10, $20, $40, $00, $00
  .byte $38, $44, $4c, $54, $64, $44, $38, $00
  .byte $10, $30, $10, $10, $10, $10, $38, $00
  .byte $38, $44, $04, $18, $20, $40, $7c, $00
  .byte $38, $44, $04, $38, $04, $44, $38, $00
  .byte $08, $18, $28, $48, $7c, $08, $08, $00
  .byte $7c, $40, $40, $78, $04, $44, $38, $00
  .byte $18, $20, $40, $78, $44, $44, $38, $00
  .byte $7c, $04, $08, $10, $20, $20, $20, $00
  .byte $38, $44, $44, $38, $44, $44, $38, $00
  .byte $38, $44, $44, $3c, $04, $08, $30, $00
  .byte $00, $00, $30, $30, $00, $30, $30, $00
  .byte $00, $00, $30, $30, $00, $30, $30, $20
  .byte $08, $10, $20, $40, $20, $10, $08, $00
  .byte $00, $00, $7c, $00, $00, $7c, $00, $00
  .byte $20, $10, $08, $04, $08, $10, $20, $00
  .byte $38, $44, $04, $18, $10, $00, $10, $00
  .byte $38, $44, $5c, $54, $5c, $40, $38, $00
  .byte $38, $44, $44, $44, $7c, $44, $44, $00
  .byte $78, $44, $44, $78, $44, $44, $78, $00
  .byte $38, $44, $40, $40, $40, $44, $38, $00
  .byte $78, $44, $44, $44, $44, $44, $78, $00
  .byte $7c, $40, $40, $78, $40, $40, $7c, $00
  .byte $7c, $40, $40, $78, $40, $40, $40, $00
  .byte $38, $44, $40, $5c, $44, $44, $3c, $00
  .byte $44, $44, $44, $7c, $44, $44, $44, $00
  .byte $38, $10, $10, $10, $10, $10, $38, $00
  .byte $04, $04, $04, $04, $44, $44, $38, $00
  .byte $44, $48, $50, $60, $50, $48, $44, $00
  .byte $40, $40, $40, $40, $40, $40, $7c, $00
  .byte $44, $6c, $54, $44, $44, $44, $44, $00
  .byte $44, $64, $54, $4c, $44, $44, $44, $00
  .byte $38, $44, $44, $44, $44, $44, $38, $00
  .byte $78, $44, $44, $78, $40, $40, $40, $00
  .byte $38, $44, $44, $44, $54, $48, $34, $00
  .byte $78, $44, $44, $78, $48, $44, $44, $00
  .byte $38, $44, $40, $38, $04, $44, $38, $00
  .byte $7c, $10, $10, $10, $10, $10, $10, $00
  .byte $44, $44, $44, $44, $44, $44, $38, $00
  .byte $44, $44, $44, $44, $44, $28, $10, $00
  .byte $44, $44, $54, $54, $54, $54, $28, $00
  .byte $44, $44, $28, $10, $28, $44, $44, $00
  .byte $44, $44, $44, $28, $10, $10, $10, $00
  .byte $78, $08, $10, $20, $40, $40, $78, $00
  .byte $38, $20, $20, $20, $20, $20, $38, $00
  .byte $00, $40, $20, $10, $08, $04, $00, $00
  .byte $38, $08, $08, $08, $08, $08, $38, $00
  .byte $10, $28, $44, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $fc
  .byte $30, $30, $10, $00, $00, $00, $00, $00
  .byte $00, $00, $38, $04, $3c, $44, $3c, $00
  .byte $40, $40, $78, $44, $44, $44, $78, $00
  .byte $00, $00, $38, $44, $40, $44, $38, $00
  .byte $04, $04, $3c, $44, $44, $44, $3c, $00
  .byte $00, $00, $38, $44, $78, $40, $38, $00
  .byte $18, $20, $20, $78, $20, $20, $20, $00
  .byte $00, $00, $3c, $44, $44, $3c, $04, $38
  .byte $40, $40, $70, $48, $48, $48, $48, $00
  .byte $10, $00, $10, $10, $10, $10, $18, $00
  .byte $08, $00, $18, $08, $08, $08, $48, $30
  .byte $40, $40, $48, $50, $60, $50, $48, $00
  .byte $10, $10, $10, $10, $10, $10, $18, $00
  .byte $00, $00, $68, $54, $54, $44, $44, $00
  .byte $00, $00, $70, $48, $48, $48, $48, $00
  .byte $00, $00, $38, $44, $44, $44, $38, $00
  .byte $00, $00, $78, $44, $44, $44, $78, $40
  .byte $00, $00, $3c, $44, $44, $44, $3c, $04
  .byte $00, $00, $58, $24, $20, $20, $70, $00
  .byte $00, $00, $38, $40, $38, $04, $38, $00
  .byte $00, $20, $78, $20, $20, $28, $10, $00
  .byte $00, $00, $48, $48, $48, $58, $28, $00
  .byte $00, $00, $44, $44, $44, $28, $10, $00
  .byte $00, $00, $44, $44, $54, $7c, $28, $00
  .byte $00, $00, $48, $48, $30, $48, $48, $00
  .byte $00, $00, $48, $48, $48, $38, $10, $60
  .byte $00, $00, $78, $08, $30, $40, $78, $00
  .byte $18, $20, $20, $60, $20, $20, $18, $00
  .byte $10, $10, $10, $00, $10, $10, $10, $00
  .byte $30, $08, $08, $0c, $08, $08, $30, $00
  .byte $28, $50, $00, $00, $00, $00, $00, $00
;   .byte $10, $38, $6c, $44, $44, $7c, $00, $00
;   .byte $38, $44, $40, $40, $44, $38, $10, $30
;   .byte $48, $00, $48, $48, $48, $58, $28, $00
;   .byte $0c, $00, $38, $44, $78, $40, $38, $00
;   .byte $38, $00, $38, $04, $3c, $44, $3c, $00
;   .byte $28, $00, $38, $04, $3c, $44, $3c, $00
;   .byte $30, $00, $38, $04, $3c, $44, $3c, $00
;   .byte $38, $28, $38, $04, $3c, $44, $3c, $00
;   .byte $00, $38, $44, $40, $44, $38, $10, $30
;   .byte $38, $00, $38, $44, $78, $40, $38, $00
;   .byte $28, $00, $38, $44, $78, $40, $38, $00
;   .byte $30, $00, $38, $44, $78, $40, $38, $00
;   .byte $28, $00, $10, $10, $10, $10, $18, $00
;   .byte $10, $28, $00, $10, $10, $10, $18, $00
;   .byte $20, $00, $10, $10, $10, $10, $18, $00
;   .byte $28, $00, $10, $28, $44, $7c, $44, $00
;   .byte $38, $28, $38, $6c, $44, $7c, $44, $00
;   .byte $0c, $00, $7c, $40, $78, $40, $7c, $00
;   .byte $00, $00, $78, $14, $7c, $50, $3c, $00
;   .byte $3c, $50, $50, $7c, $50, $50, $5c, $00
;   .byte $38, $00, $30, $48, $48, $48, $30, $00
;   .byte $28, $00, $30, $48, $48, $48, $30, $00
;   .byte $60, $00, $30, $48, $48, $48, $30, $00
;   .byte $38, $00, $48, $48, $48, $58, $28, $00
;   .byte $60, $00, $48, $48, $48, $58, $28, $00
;   .byte $28, $00, $48, $48, $48, $38, $10, $60
;   .byte $48, $30, $48, $48, $48, $48, $30, $00
;   .byte $28, $00, $48, $48, $48, $48, $30, $00
;   .byte $00, $10, $38, $40, $40, $38, $10, $00
;   .byte $18, $24, $20, $78, $20, $24, $5c, $00
;   .byte $44, $28, $10, $7c, $10, $7c, $10, $00
;   .byte $60, $50, $50, $68, $5c, $48, $48, $00
;   .byte $08, $14, $10, $38, $10, $10, $50, $20
;   .byte $18, $00, $38, $04, $3c, $44, $3c, $00
;   .byte $18, $00, $10, $10, $10, $10, $18, $00
;   .byte $18, $00, $30, $48, $48, $48, $30, $00
;   .byte $18, $00, $48, $48, $48, $58, $28, $00
;   .byte $28, $50, $00, $70, $48, $48, $48, $00
;   .byte $28, $50, $00, $48, $68, $58, $48, $00
;   .byte $38, $04, $3c, $44, $3c, $00, $3c, $00
;   .byte $30, $48, $48, $48, $30, $00, $78, $00
;   .byte $10, $00, $10, $30, $40, $44, $38, $00
;   .byte $00, $00, $7c, $40, $40, $40, $00, $00
;   .byte $00, $00, $fc, $04, $04, $00, $00, $00
;   .byte $40, $48, $50, $38, $44, $08, $1c, $00
;   .byte $40, $48, $50, $2c, $54, $1c, $04, $00
;   .byte $10, $00, $10, $10, $38, $38, $10, $00
;   .byte $00, $00, $24, $48, $24, $00, $00, $00
;   .byte $00, $00, $48, $24, $48, $00, $00, $00
;   .byte $54, $00, $a8, $00, $54, $00, $a8, $00
;   .byte $54, $a8, $54, $a8, $54, $a8, $54, $a8
;   .byte $a8, $fc, $54, $fc, $a8, $fc, $54, $fc
;   .byte $10, $10, $10, $10, $10, $10, $10, $10
;   .byte $10, $10, $10, $f0, $10, $10, $10, $10
;   .byte $10, $f0, $10, $f0, $10, $10, $10, $10
;   .byte $50, $50, $50, $d0, $50, $50, $50, $50
;   .byte $00, $00, $00, $f0, $50, $50, $50, $50
;   .byte $00, $f0, $10, $f0, $10, $10, $10, $10
;   .byte $50, $d0, $10, $d0, $50, $50, $50, $50
;   .byte $50, $50, $50, $50, $50, $50, $50, $50
;   .byte $00, $f0, $10, $d0, $50, $50, $50, $50
;   .byte $50, $d0, $10, $f0, $00, $00, $00, $00
;   .byte $50, $50, $50, $f0, $00, $00, $00, $00
;   .byte $10, $f0, $10, $f0, $00, $00, $00, $00
;   .byte $00, $00, $00, $f0, $10, $10, $10, $10
;   .byte $10, $10, $10, $1c, $00, $00, $00, $00
;   .byte $10, $10, $10, $fc, $00, $00, $00, $00
;   .byte $00, $00, $00, $fc, $10, $10, $10, $10
;   .byte $10, $10, $10, $1c, $10, $10, $10, $10
;   .byte $00, $00, $00, $fc, $00, $00, $00, $00
;   .byte $10, $10, $10, $fc, $10, $10, $10, $10
;   .byte $10, $1c, $10, $1c, $10, $10, $10, $10
;   .byte $50, $50, $50, $5c, $50, $50, $50, $50
;   .byte $50, $5c, $40, $7c, $00, $00, $00, $00
;   .byte $00, $7c, $40, $5c, $50, $50, $50, $50
;   .byte $50, $dc, $00, $fc, $00, $00, $00, $00
;   .byte $00, $fc, $00, $dc, $50, $50, $50, $50
;   .byte $50, $5c, $40, $5c, $50, $50, $50, $50
;   .byte $00, $fc, $00, $fc, $00, $00, $00, $00
;   .byte $50, $dc, $00, $dc, $50, $50, $50, $50
;   .byte $10, $fc, $00, $fc, $00, $00, $00, $00
;   .byte $50, $50, $50, $fc, $00, $00, $00, $00
;   .byte $00, $fc, $00, $fc, $10, $10, $10, $10
;   .byte $00, $00, $00, $fc, $50, $50, $50, $50
;   .byte $50, $50, $50, $7c, $00, $00, $00, $00
;   .byte $10, $1c, $10, $1c, $00, $00, $00, $00
;   .byte $00, $1c, $10, $1c, $10, $10, $10, $10
;   .byte $00, $00, $00, $7c, $50, $50, $50, $50
;   .byte $50, $50, $50, $dc, $50, $50, $50, $50
;   .byte $10, $fc, $00, $fc, $10, $10, $10, $10
;   .byte $10, $10, $10, $f0, $00, $00, $00, $00
;   .byte $00, $00, $00, $1c, $10, $10, $10, $10
;   .byte $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc
;   .byte $00, $00, $00, $00, $fc, $fc, $fc, $fc
;   .byte $e0, $e0, $e0, $e0, $e0, $e0, $e0, $e0
;   .byte $1c, $1c, $1c, $1c, $1c, $1c, $1c, $1c
;   .byte $fc, $fc, $fc, $fc, $00, $00, $00, $00
;   .byte $00, $00, $34, $48, $48, $34, $00, $00
;   .byte $00, $70, $48, $70, $48, $48, $70, $40
;   .byte $78, $48, $40, $40, $40, $40, $40, $00
;   .byte $00, $7c, $28, $28, $28, $28, $28, $00
;   .byte $78, $48, $20, $10, $20, $48, $78, $00
;   .byte $00, $00, $3c, $48, $48, $30, $00, $00
;   .byte $00, $00, $48, $48, $48, $70, $40, $40
;   .byte $00, $00, $28, $50, $10, $10, $10, $00
;   .byte $38, $10, $38, $44, $38, $10, $38, $00
;   .byte $30, $48, $48, $78, $48, $48, $30, $00
;   .byte $00, $38, $44, $44, $28, $28, $6c, $00
;   .byte $30, $40, $20, $10, $38, $48, $30, $00
;   .byte $00, $00, $28, $54, $54, $28, $00, $00
;   .byte $00, $10, $38, $54, $54, $38, $10, $00
;   .byte $00, $38, $40, $78, $40, $38, $00, $00
;   .byte $00, $30, $48, $48, $48, $48, $00, $00
;   .byte $00, $78, $00, $78, $00, $78, $00, $00
;   .byte $00, $10, $38, $10, $00, $38, $00, $00
;   .byte $40, $30, $08, $30, $40, $00, $78, $00
;   .byte $08, $30, $40, $30, $08, $00, $78, $00
;   .byte $00, $08, $14, $10, $10, $10, $10, $10
;   .byte $10, $10, $10, $10, $10, $50, $20, $00
;   .byte $00, $10, $00, $7c, $00, $10, $00, $00
;   .byte $00, $28, $50, $00, $28, $50, $00, $00
;   .byte $30, $48, $48, $30, $00, $00, $00, $00
;   .byte $00, $00, $00, $30, $30, $00, $00, $00
;   .byte $00, $00, $00, $20, $00, $00, $00, $00
;   .byte $00, $1c, $10, $10, $50, $50, $20, $00
;   .byte $50, $28, $28, $28, $00, $00, $00, $00
;   .byte $60, $10, $20, $70, $00, $00, $00, $00
;   .byte $00, $00, $78, $78, $78, $78, $00, $00
;   .byte $00, $00, $00, $00, $00, $00, $00, $00
  ; non ascii
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00 ; cursor
vdp_end_patterns: