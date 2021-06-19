; TMS9918A
VDP_VRAM               = $8000
VDP_REG                = $8001
VDP_WRITE_VRAM_BIT     = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS      = %10000000  ; pattern of second register write: 10000RRR

VIA_START = $6000
PORTA = VIA_START + 1
PORTB = VIA_START + 0
DDRA  = VIA_START + 3
DDRB  = VIA_START + 2


VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

VDP_PATTERN_INIT    = $30
VDP_PATTERN_INIT_HI = $31
VDP_SPRITE_INIT     = $32
VDP_SPRITE_INIT_HI  = $33
BALL_HOR_DIRECTION  = $34
BALL_VER_DIRECTION  = $35
BALL_X              = $36
BALL_Y              = $37

LEFT_PADDLE_Y       = $40
RIGHT_PADDLE_Y      = $41

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
  lda #0
  sta DDRA ; direction: read

  jsr vdp_setup
  ; jsr game_setup
  cli
  jmp game_loop

game_loop:
  jsr update_game
  jsr delay
  jmp game_loop


update_game:
  jsr side_wall_collision
  jsr floor_ceiling_collision
  jsr set_ball_pos
  jsr set_left_paddle_pos
  jsr set_right_paddle_pos
  rts

side_wall_collision:
verify_left_border:
  lda BALL_X
  cmp #$6
  bne verify_right_border ; not currently 0
  lda #$1
  sta BALL_HOR_DIRECTION
  rts
verify_right_border:
  cmp #$fb
  bne .done
  lda #$0
  sta BALL_HOR_DIRECTION
.done:
  rts

floor_ceiling_collision:
verify_top_border:
  lda BALL_Y
  cmp #$00
  bne verify_bottom_border
  lda #$1
  sta BALL_VER_DIRECTION
  rts
verify_bottom_border:
  cmp #$ba
  bne .done
  lda #0
  sta BALL_VER_DIRECTION
.done
  rts

set_ball_pos:
set_ball_pos_x:
  lda BALL_HOR_DIRECTION
  bne incr_ball_x
  dec BALL_X
  jmp set_ball_pos_y
incr_ball_x:
  inc BALL_X
set_ball_pos_y:
  lda BALL_VER_DIRECTION
  bne incr_ball_y
  dec BALL_Y
  rts
incr_ball_y:
  inc BALL_Y
  rts

set_left_paddle_pos:
  ldx PORTA  ; this returns a value between 0 and 255
  lda controller_input_to_y_pos, x
  sta LEFT_PADDLE_Y
  rts


set_right_paddle_pos:
  ldx PORTA  ; this returns a value between 0 and 255
  lda controller_input_to_y_pos, x
  sta RIGHT_PADDLE_Y
  rts

draw_ball:
  vdp_write_vram VDP_SPRITE_ATTR_TABLE_BASE
  lda BALL_Y
  sta VDP_VRAM
  lda BALL_X
  sta VDP_VRAM
  lda #0
  sta VDP_VRAM
  lda #$0f
  sta VDP_VRAM
  rts

draw_left_paddle:
  vdp_write_vram (VDP_SPRITE_ATTR_TABLE_BASE + 4) ; offset of 4 to skip the ball attrs
  lda LEFT_PADDLE_Y
  sta VDP_VRAM
  lda #5
  sta VDP_VRAM
  lda #1
  sta VDP_VRAM
  lda #$0f
  sta VDP_VRAM
  rts

draw_right_paddle:
  vdp_write_vram (VDP_SPRITE_ATTR_TABLE_BASE + 8) ; offset of 4 to skip the ball attrs
  lda BALL_Y
  sta VDP_VRAM
  lda #$f8
  sta VDP_VRAM
  lda #2
  sta VDP_VRAM
  lda #$0f
  sta VDP_VRAM
  rts

irq:
  sei
  pha
  phy
  phx
  lda VDP_REG                   ; read VDP status register
  and #%10000000                ; highest bit is interrupt flag
  beq .done
  jsr draw_ball
  jsr draw_left_paddle
  jsr draw_right_paddle
.done
  plx
  ply
  pla
  cli
  rts

delay:
  phx
  phy
  ldx #$ff
  ldy #$f
delay_loop:
  dex
  bne delay_loop
  dey
  bne delay_loop
  ply
  plx
  rts

; ====================================================================================
;                              VDP RELATED ROUTINES
; ====================================================================================
vdp_setup:
  jsr vdp_initialize_pattern_table
  jsr vdp_initialize_color_table

  jsr initialize_sprites
  jsr draw_dotted_line
  jsr vdp_enable_display
  rts

draw_dotted_line:
  vdp_write_vram VDP_NAME_TABLE_BASE
  ldy #$19     ; row number, starts at 23, because there are 24 rows
.draw_row:
  ldx #$20      ; column umber, starts at 31, because there are 32 columns
.draw_row_loop:
  cpx #$10      ; 10 is in the middle, where the dotted line should go
  beq .load_dotted_pattern
  lda #0
  jmp .draw_pattern
.load_dotted_pattern:
  lda #1 ; the dotted line pattern
.draw_pattern:
  sta VDP_VRAM
  dex
  beq .row_done
  jmp .draw_row_loop
.row_done:
  dey
  bne .draw_row
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

vdp_initialize_color_table:
  vdp_write_vram VDP_COLOR_TABLE_BASE
  ldx #$20
  lda #$f1   ; color
vdp_color_table_loop:
  sta VDP_VRAM
  dex
  bne vdp_color_table_loop
  rts

initialize_sprites:
  vdp_write_vram VDP_SPRITE_PATTERNS_TABLE_BASE
  lda #<vdp_sprite_patterns
  sta VDP_SPRITE_INIT
  lda #>vdp_sprite_patterns
  sta VDP_SPRITE_INIT_HI
.loop:
  lda (VDP_SPRITE_INIT)                  ; load A with the value at VDP_PATTERN_INIT 
  sta VDP_VRAM                           ; and store it to VRAM
  lda VDP_SPRITE_INIT                    ; load the low byte of VDP_SPRITE_INIT address into A
  clc                                    ; clear carry flag
  adc #1                                 ; Add 1, with carry
  sta VDP_SPRITE_INIT                    ; store back into VDP_SPRITE_INIT
  lda #0                                 ; load A with 0
  adc VDP_SPRITE_INIT_HI                 ; add with the carry flag to the high address
  sta VDP_SPRITE_INIT_HI                 ; and store that back into the high byte
  cmp #>vdp_end_sprite_patterns          ; compare if we're at the end of the patterns
  bne .loop                              ; if not, loop again
  lda VDP_SPRITE_INIT                    ; compare the low byte
  cmp #<vdp_end_sprite_patterns
  bne .loop                              ; if not equal, loop again
  rts

vdp_enable_display:
  pha
  lda #%11100000
  sta VDP_REG
  lda #(VDP_REGISTER_BITS | 1)
  sta VDP_REG
  pla
  sta VDP_VRAM
  rts


vdp_patterns:
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; empty, used to clear the screen
  .byte $80,$80,$00,$00,$80,$80,$00,$00 ; dotted line
vdp_end_patterns:


vdp_sprite_patterns:
  .byte $60,$f0,$f0,$60,$00,$00,$00,$00    ; ball 
  .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0    ; left paddle 
  .byte $03,$03,$03,$03,$03,$03,$03,$03    ; right paddle 
vdp_end_sprite_patterns:

; to regenerate in irb:
; (0..255).each_slice(8) {|slice| puts ".byte " + slice.map{|int| "$#{(int*180/256).to_s(16).rjust(2, '0')}"}.join(",")}
controller_input_to_y_pos:
  .byte $00,$00,$01,$02,$02,$03,$04,$04
  .byte $05,$06,$07,$07,$08,$09,$09,$0a
  .byte $0b,$0b,$0c,$0d,$0e,$0e,$0f,$10
  .byte $10,$11,$12,$12,$13,$14,$15,$15
  .byte $16,$17,$17,$18,$19,$1a,$1a,$1b
  .byte $1c,$1c,$1d,$1e,$1e,$1f,$20,$21
  .byte $21,$22,$23,$23,$24,$25,$25,$26
  .byte $27,$28,$28,$29,$2a,$2a,$2b,$2c
  .byte $2d,$2d,$2e,$2f,$2f,$30,$31,$31
  .byte $32,$33,$34,$34,$35,$36,$36,$37
  .byte $38,$38,$39,$3a,$3b,$3b,$3c,$3d
  .byte $3d,$3e,$3f,$3f,$40,$41,$42,$42
  .byte $43,$44,$44,$45,$46,$47,$47,$48
  .byte $49,$49,$4a,$4b,$4b,$4c,$4d,$4e
  .byte $4e,$4f,$50,$50,$51,$52,$52,$53
  .byte $54,$55,$55,$56,$57,$57,$58,$59
  .byte $5a,$5a,$5b,$5c,$5c,$5d,$5e,$5e
  .byte $5f,$60,$61,$61,$62,$63,$63,$64
  .byte $65,$65,$66,$67,$68,$68,$69,$6a
  .byte $6a,$6b,$6c,$6c,$6d,$6e,$6f,$6f
  .byte $70,$71,$71,$72,$73,$74,$74,$75
  .byte $76,$76,$77,$78,$78,$79,$7a,$7b
  .byte $7b,$7c,$7d,$7d,$7e,$7f,$7f,$80
  .byte $81,$82,$82,$83,$84,$84,$85,$86
  .byte $87,$87,$88,$89,$89,$8a,$8b,$8b
  .byte $8c,$8d,$8e,$8e,$8f,$90,$90,$91
  .byte $92,$92,$93,$94,$95,$95,$96,$97
  .byte $97,$98,$99,$99,$9a,$9b,$9c,$9c
  .byte $9d,$9e,$9e,$9f,$a0,$a1,$a1,$a2
  .byte $a3,$a3,$a4,$a5,$a5,$a6,$a7,$a8
  .byte $a8,$a9,$aa,$aa,$ab,$ac,$ac,$ad
  .byte $ae,$af,$af,$b0,$b1,$b1,$b2,$b3