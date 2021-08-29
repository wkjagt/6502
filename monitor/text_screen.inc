    .include "macros.inc"
VIA_PORTB                      = $6000

VDP_VRAM                       = $8000
VDP_REG                        = $8001
VDP_WRITE_VRAM_BIT             = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS              = %10000000  ; pattern of second register write: 10000RRR
VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

CURSOR_ON                      = %00000001
VIDEO_BUFFER_STALE             = %00000010
END_OF_SCREEN_BUFFER           = $FF
ENTER                          = $0a
BACKSP                         = $08
ESC                            = $1B

; LOCATIONS
screenbuffer                   = $0300
vdp_patterns                   = $C041
vdp_end_patterns               = $C341

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
    jsr init_screen_buffer
    jsr vdp_initialize_pattern_table
    jsr vdp_enable_display
    jsr reset_screen_buffer_rptr
    lda #0
    sta cursor_column
    lda #0
    sta cursor_row
    jsr calculate_cursor_pos
    jsr blink_cursor
    rts

init_screen_buffer:
    jsr reset_screen_buffer_wptr
    ldy #4    ; empty 4 pages (3, 4, 5, 6)
    ldx #255  ; page length
.next
    lda #0    ; fill wil 0s
    sta (screen_buffer_wptr)
    jsr incr_screen_buffer_wptr
    dex
    bne .next
    dey
    bne .next
.done:
    lda #<(screenbuffer + 960)
    sta screen_buffer_wptr
    lda #>(screenbuffer + 960)
    sta screen_buffer_wptr + 1
    lda #END_OF_SCREEN_BUFFER
    sta (screen_buffer_wptr)
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
    cmp #39
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
    beq .done
    dec cursor_column
    jmp .done
.esc:
    jsr SCRNSETUP
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
    lda screen_flags
    bit #VIDEO_BUFFER_STALE
    beq .done
    and #(~VIDEO_BUFFER_STALE)
    sta screen_flags
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
    adc #40
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
    ; starting at position 40, copy all characters to 40 positions to
    ; the left in the screenbuffer
    sei
    jsr reset_screen_buffer_wptr ; start writing at the start of screen buffer
    jsr reset_screen_buffer_rptr
    ; set read pointer to 40 after screen buffer (start of second line)
    lda #(<screenbuffer)            ; load the LSB of the screenbuffer start address
    clc
    adc #40                         ; add 40 to it, which is the left most position of the 2nd line
    sta screen_buffer_rptr          ; store that in the read pointer LSB
    lda screen_buffer_rptr + 1      ; load the MSB of the read pointer
    adc #0                          ; add the carry flag to it
    sta screen_buffer_rptr + 1
.loop:
    lda (screen_buffer_rptr)        ; load the character that the read pointer points to
    cmp #END_OF_SCREEN_BUFFER       ; see if it is $FF (one past the end of the screen)
    beq .done                       ; if it is, we'be read the buffer up to the last line, do nothing else
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
    lda #0
    sta cursor_column
    lda cursor_row
    cmp #22
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
