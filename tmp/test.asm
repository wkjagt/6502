JUMP_TABLE_ADDR         = $300
RCV                     = JUMP_TABLE_ADDR + 0
INIT_SCREEN             = JUMP_TABLE_ADDR + 3
RUN                     = JUMP_TABLE_ADDR + 6
RESET                   = JUMP_TABLE_ADDR + 9
PUTC                    = JUMP_TABLE_ADDR + 12
PRINT_HEX               = JUMP_TABLE_ADDR + 15
XMODEM_RCV              = JUMP_TABLE_ADDR + 18
GETC                    = JUMP_TABLE_ADDR + 21
INIT_KB                 = JUMP_TABLE_ADDR + 24
LINE_INPUT              = JUMP_TABLE_ADDR + 27
IRQ_HANDLER             = JUMP_TABLE_ADDR + 30
NMI_HANDLER             = JUMP_TABLE_ADDR + 33
INIT_SERIAL             = JUMP_TABLE_ADDR + 36
CURSOR_ON               = JUMP_TABLE_ADDR + 39
CURSOR_OFF              = JUMP_TABLE_ADDR + 42
DRAW_PIXEL              = JUMP_TABLE_ADDR + 45
RMV_PIXEL               = JUMP_TABLE_ADDR + 48
INIT_STORAGE            = JUMP_TABLE_ADDR + 51
STOR_READ               = JUMP_TABLE_ADDR + 54
STOR_WRITE              = JUMP_TABLE_ADDR + 57
READ_PAGE               = JUMP_TABLE_ADDR + 60
WRITE_PAGE              = JUMP_TABLE_ADDR + 63
GET_INPUT               = JUMP_TABLE_ADDR + 66
CLR_INPUT               = JUMP_TABLE_ADDR + 69
LOAD_FAT                = JUMP_TABLE_ADDR + 72
CLEAR_FAT               = JUMP_TABLE_ADDR + 75
FIND_EMPTY_PAGE         = JUMP_TABLE_ADDR + 78
CLEAR_DIR               = JUMP_TABLE_ADDR + 81
LOAD_DIR                = JUMP_TABLE_ADDR + 84
SAVE_DIR                = JUMP_TABLE_ADDR + 87
SHOW_DIR                = JUMP_TABLE_ADDR + 90
FORMAT_DIVE             = JUMP_TABLE_ADDR + 93
PRINT_STRING            = JUMP_TABLE_ADDR + 96
ADD_TO_DIR              = JUMP_TABLE_ADDR + 99
FIND_EMPTY_DIR          = JUMP_TABLE_ADDR + 102
DELETE_DIR              = JUMP_TABLE_ADDR + 105
DELETE_FILE             = JUMP_TABLE_ADDR + 108
SAVE_FAT                = JUMP_TABLE_ADDR + 111
FIND_FILE               = JUMP_TABLE_ADDR + 114


BG_TRANSPARENT                    = $0
BG_BLACK                          = $1
BG_MEDIUM_GREEN                   = $2
BG_LIGHT_GREEN                    = $3
BG_DARK_BLUE                      = $4
BG_LIGHT_BLUE                     = $5
BG_DARK_RED                       = $6
BG_CYAN                           = $7
BG_MEDIUM_RED                     = $8
BG_LIGHT_RED                      = $9
BG_DARK_YELLOW                    = $A
BG_LIGHT_YELLOW                   = $B
BG_DARK_GREEN                     = $C
BG_MAGENTA                        = $D
BG_GRAY                           = $E
BG_WHITE                          = $F

FG_TRANSPARENT                    = $10 * BG_TRANSPARENT
FG_BLACK                          = $10 * BG_BLACK
FG_MEDIUM_GREEN                   = $10 * BG_MEDIUM_GREEN
FG_LIGHT_GREEN                    = $10 * BG_LIGHT_GREEN
FG_DARK_BLUE                      = $10 * BG_DARK_BLUE
FG_LIGHT_BLUE                     = $10 * BG_LIGHT_BLUE
FG_DARK_RED                       = $10 * BG_DARK_RED
FG_CYAN                           = $10 * BG_CYAN
FG_MEDIUM_RED                     = $10 * BG_MEDIUM_RED
FG_LIGHT_RED                      = $10 * BG_LIGHT_RED
FG_DARK_YELLOW                    = $10 * BG_DARK_YELLOW
FG_LIGHT_YELLOW                   = $10 * BG_LIGHT_YELLOW
FG_DARK_GREEN                     = $10 * BG_DARK_GREEN
FG_MAGENTA                        = $10 * BG_MAGENTA
FG_GRAY                           = $10 * BG_GRAY
FG_WHITE                          = $10 * BG_WHITE

; Video - TMS9918A
VDP_VRAM                       = $4400
VDP_REG                        = $4401
vdp_write_addr_BIT             = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS              = %10000000  ; pattern of second register write: 10000RRR
VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

; name table:           contains a value for each 8x8 region on the screen,
;                       and points to one of the patterns
; color table:          32 bytes, each defining the colors for 8 patterns in 
;                       the pattern table
; pattern table:        a list of patterns to be used as background, selected by
;                       the name table
; sprite pattern table: a list of patterns to be used as sprites
; sprite attr table:    table containing position, color etc for each of the
;                       32 sprites

VDP_WRITE_PTR              = $54
VDP_WRITE_END              = $56

BALL_X                      = $58
BALL_Y                      = $59

                .macro vdp_write_addr
                pha
                lda #<(\1)
                sta VDP_REG
                lda #(vdp_write_addr_BIT | >\1) ; see second register write pattern
                sta VDP_REG
                pla
                .endm

                .macro vdp_write_pointers
                lda     #<(\1)
                sta     VDP_WRITE_PTR
                lda     #>(\1)
                sta     VDP_WRITE_PTR+1
                lda     #<(\2)
                sta     VDP_WRITE_END
                lda     #>(\2)
                sta     VDP_WRITE_END+1
                .endm

                .org    $0600

                stz     BALL_X
                stz     BALL_Y

                sei
                lda     #<irq
                sta     IRQ_HANDLER+1
                lda     #>irq
                sta     IRQ_HANDLER+2

                ; set VDP values specific to game
                jsr     write_game_patterns
                jsr     write_game_colors
                jsr     write_game_sprites

                jsr     draw_dotted_line
                jsr     vdp_enable_display
                cli
                rts

irq:            pha
                phy
                phx
                lda     VDP_REG                   ; read VDP status register
                and     #%10000000                ; highest bit is interrupt flag
                beq     .done
                jsr     draw_ball
.done           plx
                ply
                pla
                rti


draw_ball:      inc     BALL_X
                inc     BALL_Y

                vdp_write_addr VDP_SPRITE_ATTR_TABLE_BASE ; same as ball
                lda BALL_Y
                sta VDP_VRAM
                lda BALL_X
                sta VDP_VRAM
                lda #0                  ; first entry in the sprite pattern table
                sta VDP_VRAM
                lda #$0f                ; f: white
                sta VDP_VRAM
.done           rts

                
draw_dotted_line:
                vdp_write_addr VDP_NAME_TABLE_BASE
                ldy #$19     ; row number, starts at 23, because there are 24 rows
.draw_row:      ldx #$20      ; column umber, starts at 31, because there are 32 columns
.draw_row_loop: cpx #$10      ; 10 is in the middle, where the dotted line should go
                beq .load_dots
                lda #0
                jmp .draw_pattern
.load_dots:     lda #1 ; the dotted line pattern
.draw_pattern:  sta VDP_VRAM
                dex
                beq .row_done
                jmp .draw_row_loop
.row_done:      dey
                bne .draw_row
                rts

;===============================tmp==========================


write_game_patterns:
                vdp_write_pointers vdp_patterns, vdp_end_patterns
                jsr     vdp_pattern_write
                rts

write_game_sprites:
                vdp_write_pointers vdp_sprite_patterns, vdp_end_sprite_patterns
                jsr     vdp_sprite_pattern_write
                rts

write_game_colors:
                vdp_write_pointers vdp_colors, vdp_end_colors
                jsr     vdp_color_write
                rts


vdp_sprite_pattern_write:
                vdp_write_addr VDP_SPRITE_PATTERNS_TABLE_BASE
                jsr     _write_vram
                rts

vdp_pattern_write:
                vdp_write_addr VDP_PATTERN_TABLE_BASE
                jsr     _write_vram
                rts

vdp_color_write:
                vdp_write_addr VDP_COLOR_TABLE_BASE
                jsr     _write_vram
                rts

; call into write_vram after setting VDP_WRITE_PTR
; and VDP_WRITE_END to write a complete series of
; bytes into VRAM
_next_write:    inc     VDP_WRITE_PTR   ; inc low byte of write ptr
                bne     _write_vram     ; if that didn't cause a 0, next write
                inc     VDP_WRITE_PTR+1 ; if low byte inc caused 0, inc high byte
_write_vram:    lda     (VDP_WRITE_PTR)
                sta     VDP_VRAM
                lda     VDP_WRITE_PTR
                cmp     VDP_WRITE_END
                bne     _next_write
                lda     VDP_WRITE_PTR+1
                cmp     VDP_WRITE_END+1
                bne     _next_write
                rts
;===============================tmp==========================
vdp_enable_display:
                lda #%11100000                         ; 16k Bl IE M1 M2 0 Siz MAG 
                sta VDP_REG
                lda #(VDP_REGISTER_BITS | 1)           ; register select (selecting register 1)
                sta VDP_REG
                rts

vdp_colors:
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
                .byte FG_DARK_GREEN | BG_TRANSPARENT
vdp_end_colors:

vdp_sprite_patterns:
                .byte $c0,$c0,$00,$00,$00,$00,$00,$00    ; ball 
                .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0    ; left paddle top
                .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0    ; left paddle bottom
                .byte $03,$03,$03,$03,$03,$03,$03,$03    ; right paddle top
                .byte $03,$03,$03,$03,$03,$03,$03,$03    ; right paddle bottom
vdp_end_sprite_patterns:

; pattern generator table
vdp_patterns:   .byte $00,$00,$00,$00,$00,$00,$00,$00 ; empty, used to clear the screen
                .byte $80,$80,$00,$00,$80,$80,$00,$00 ; dotted line
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
vdp_end_patterns: