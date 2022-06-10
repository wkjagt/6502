    .include "../../pager_os/build/pager_os/pager_os.inc"

BALL_X_DIRECTION            = $56
BALL_Y_DIRECTION            = $57
BALL_X                      = $58
BALL_Y                      = $59

                .macro vdp_write_addr
                pha
                lda #<(\1)
                sta VDP_REG
                lda #(VDP_WRITE_VRAM_BIT | >\1) ; see second register write pattern
                sta VDP_REG
                pla
                .endm

                .macro vdp_write_pointers
                lda     #<(\1)
                sta     vdp_write_ptr
                lda     #>(\1)
                sta     vdp_write_ptr+1
                lda     #<(\2)
                sta     vdp_write_end
                lda     #>(\2)
                sta     vdp_write_end+1
                .endm

                .org    $0600

                stz     BALL_X
                stz     BALL_Y
                lda     #1
                sta     BALL_X_DIRECTION
                sta     BALL_Y_DIRECTION

                sei
                lda     #<irq
                sta     JMP_IRQ_HANDLER+1
                lda     #>irq
                sta     JMP_IRQ_HANDLER+2

                ; set VDP values specific to game
                jsr     write_game_patterns
                jsr     write_game_colors
                jsr     write_game_sprites

                jsr     draw_dotted_line
                jsr     JMP_GRAPHICS_ON
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


draw_ball:      lda     BALL_X
                cmp     #250            ; right edge
                bne     .cmp_left_edge
                lda     #$ff
                sta     BALL_X_DIRECTION
                bra     .move_ball_x

.cmp_left_edge: lda     BALL_X
                cmp     #5
                bne     .move_ball_x
                lda     #1
                sta     BALL_X_DIRECTION

.move_ball_x:   clc
                lda     BALL_X
                adc     BALL_X_DIRECTION
                sta     BALL_X

; ball y
                lda     BALL_Y
                cmp     #180            ; bottom edge
                bne     .cmp_top_edge
                lda     #$ff
                sta     BALL_Y_DIRECTION
                bra     .move_ball_y

.cmp_top_edge:  lda     BALL_Y
                cmp     #5
                bne     .move_ball_y
                lda     #1
                sta     BALL_Y_DIRECTION

.move_ball_y:   
                clc
                lda     BALL_Y
                adc     BALL_Y_DIRECTION
                sta     BALL_Y

                vdp_write_addr VDP_SPRITE_ATTR_TABLE_BASE ; same as ball
                lda BALL_Y
                sta VDP_VRAM
                lda BALL_X
                sta VDP_VRAM
                lda #0                  ; first entry in the sprite pattern table
                sta VDP_VRAM
                lda #$0f
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


write_game_patterns:
                vdp_write_pointers vdp_patterns, vdp_end_patterns
                jsr     JMP_PATTERNS_WRITE
                rts

write_game_sprites:
                vdp_write_pointers vdp_sprite_patterns, vdp_end_sprite_patterns
                jsr     JMP_SPRITE_PATTERNS_WRT
                rts

write_game_colors:
                vdp_write_pointers vdp_colors, vdp_end_colors
                jsr     JMP_COLORS_WRITE
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