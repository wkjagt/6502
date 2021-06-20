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

BALL_X_SPEED        = $38
BALL_Y_SPEED        = $39
TEMP_PADDLE_Y       = $3a
LEFT_PADDLE_Y       = $3b
RIGHT_PADDLE_Y      = $3c

GAME_SPEED          = $3d
; constants
LEFT_PADDLE_X       = $20
RIGHT_PADDLE_X      = $d8
INITIAL_GAME_SPEED  = $6      ; this is actually a delay, so a lower number is faster


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
  jsr game_setup
  jsr vdp_setup
  cli
  jmp game_loop

game_setup:
  lda #0
  sta DDRA ; direction: read
  lda #1
  sta BALL_Y_SPEED
  lda #1
  sta BALL_VER_DIRECTION
  sta BALL_HOR_DIRECTION
  lda #$2f
  sta BALL_Y
  lda #$7f
  sta BALL_X
  lda #INITIAL_GAME_SPEED
  sta GAME_SPEED
  rts

game_loop:
  jsr delay
  jsr update_game
  jmp game_loop

update_game:
  sei
  jsr paddle_collision
  jsr side_wall_collision
  jsr floor_ceiling_collision
  jsr set_ball_pos
  jsr set_left_paddle_pos
  jsr set_right_paddle_pos
  cli
  rts

paddle_collision:
  lda BALL_X
  cmp #LEFT_PADDLE_X + 2      ; taking paddle thickness into account
  bne .check_right_paddle
  ldx LEFT_PADDLE_Y
  jmp .continue
.check_right_paddle
  cmp #RIGHT_PADDLE_X + 4     ; paddle thickness again
  bne .no_collision
  ldx RIGHT_PADDLE_Y
.continue:
  stx TEMP_PADDLE_Y
  lda BALL_Y
  sec
  sbc TEMP_PADDLE_Y
  bcc .no_collision; carry is clear: negative: done
  cmp #$f
  bcs .no_collision
  ; flip direction
  lda BALL_HOR_DIRECTION
  eor #1
  sta BALL_HOR_DIRECTION
.no_collision
  rts

side_wall_collision:
  lda BALL_X
  cmp #$04
  beq .continue
  cmp #$fb
  bne .return
.continue:
  jsr blink_screen
  lda BALL_HOR_DIRECTION
  eor #1
  sta BALL_HOR_DIRECTION
.return:
  rts

floor_ceiling_collision:
verify_top_border:
  lda BALL_Y
  cmp #$01
  bcc .flip_ball_ver_dir
  cmp #$ba
  bcc .done
.flip_ball_ver_dir:
  lda BALL_VER_DIRECTION
  eor #1
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
  lda BALL_Y
  sec
  sbc BALL_Y_SPEED
  sta BALL_Y
  rts
incr_ball_y:
  lda BALL_Y
  adc BALL_Y_SPEED
  sta BALL_Y
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
  lda LEFT_PADDLE_Y         ; y coordinate for the sprite 
  sta VDP_VRAM
  lda #LEFT_PADDLE_X        ; x coordinate for the sprite 
  sta VDP_VRAM
  lda #1                    ; sprite index
  sta VDP_VRAM
  lda #$0f                  ; colours
  sta VDP_VRAM

  lda LEFT_PADDLE_Y         ; y coordinate for the sprite 
  adc #7                    ; adding 7 because with 8 there's a gap sometimes....
  sta VDP_VRAM
  lda #LEFT_PADDLE_X        ; x coordinate for the sprite 
  sta VDP_VRAM
  lda #2                    ; sprite index
  sta VDP_VRAM
  lda #$0f                  ; colours
  sta VDP_VRAM
  rts

draw_right_paddle:
  vdp_write_vram (VDP_SPRITE_ATTR_TABLE_BASE + 12) ; offset of 4 to skip the ball attrs
  lda RIGHT_PADDLE_Y
  sta VDP_VRAM
  lda #RIGHT_PADDLE_X
  sta VDP_VRAM
  lda #3
  sta VDP_VRAM
  lda #$0f
  sta VDP_VRAM

  lda RIGHT_PADDLE_Y         ; y coordinate for the sprite 
  adc #8                     ; no need to add 7 instead of 8 here. weird...
  sta VDP_VRAM
  lda #RIGHT_PADDLE_X        ; x coordinate for the sprite 
  sta VDP_VRAM
  lda #4                    ; sprite index
  sta VDP_VRAM
  lda #$0f                  ; colours
  sta VDP_VRAM
  rts

irq:
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
  rts

delay:
  phx
  phy
  ldx #$ff
  ldy GAME_SPEED
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

blink_screen:
  ldx #$3
.loop:
  lda #$1f
  sta VDP_REG
  lda #$7 ; register 7
  ora #VDP_REGISTER_BITS ; combine the register number with the second write pattern
  sta VDP_REG
  jsr blink_delay
  lda #$f1
  sta VDP_REG
  lda #$7 ; register 7
  ora #VDP_REGISTER_BITS ; combine the register number with the second write pattern
  sta VDP_REG
  jsr blink_delay
  dex
  bne .loop
  rts

blink_delay:
  jsr delay
  jsr delay
  jsr delay
  rts

vdp_patterns:
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; empty, used to clear the screen
  .byte $80,$80,$00,$00,$80,$80,$00,$00 ; dotted line
vdp_end_patterns:


vdp_sprite_patterns:
  .byte $c0,$c0,$00,$00,$00,$00,$00,$00    ; ball 
  .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0    ; left paddle top
  .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0    ; left paddle bottom
  .byte $03,$03,$03,$03,$03,$03,$03,$03    ; right paddle top
  .byte $03,$03,$03,$03,$03,$03,$03,$03    ; right paddle bottom
vdp_end_sprite_patterns:

; to regenerate in irb:
; (0..255).each_slice(8) {|slice| puts " .byte " + slice.map{|int| "$#{((255-int)*175/256).to_s(16).rjust(2, '0')}"}.join(",")}
controller_input_to_y_pos:
 .byte $ae,$ad,$ac,$ac,$ab,$aa,$aa,$a9
 .byte $a8,$a8,$a7,$a6,$a6,$a5,$a4,$a4
 .byte $a3,$a2,$a2,$a1,$a0,$9f,$9f,$9e
 .byte $9d,$9d,$9c,$9b,$9b,$9a,$99,$99
 .byte $98,$97,$97,$96,$95,$95,$94,$93
 .byte $92,$92,$91,$90,$90,$8f,$8e,$8e
 .byte $8d,$8c,$8c,$8b,$8a,$8a,$89,$88
 .byte $88,$87,$86,$85,$85,$84,$83,$83
 .byte $82,$81,$81,$80,$7f,$7f,$7e,$7d
 .byte $7d,$7c,$7b,$7b,$7a,$79,$78,$78
 .byte $77,$76,$76,$75,$74,$74,$73,$72
 .byte $72,$71,$70,$70,$6f,$6e,$6e,$6d
 .byte $6c,$6c,$6b,$6a,$69,$69,$68,$67
 .byte $67,$66,$65,$65,$64,$63,$63,$62
 .byte $61,$61,$60,$5f,$5f,$5e,$5d,$5c
 .byte $5c,$5b,$5a,$5a,$59,$58,$58,$57
 .byte $56,$56,$55,$54,$54,$53,$52,$52
 .byte $51,$50,$4f,$4f,$4e,$4d,$4d,$4c
 .byte $4b,$4b,$4a,$49,$49,$48,$47,$47
 .byte $46,$45,$45,$44,$43,$42,$42,$41
 .byte $40,$40,$3f,$3e,$3e,$3d,$3c,$3c
 .byte $3b,$3a,$3a,$39,$38,$38,$37,$36
 .byte $36,$35,$34,$33,$33,$32,$31,$31
 .byte $30,$2f,$2f,$2e,$2d,$2d,$2c,$2b
 .byte $2b,$2a,$29,$29,$28,$27,$26,$26
 .byte $25,$24,$24,$23,$22,$22,$21,$20
 .byte $20,$1f,$1e,$1e,$1d,$1c,$1c,$1b
 .byte $1a,$19,$19,$18,$17,$17,$16,$15
 .byte $15,$14,$13,$13,$12,$11,$11,$10
 .byte $0f,$0f,$0e,$0d,$0c,$0c,$0b,$0a
 .byte $0a,$09,$08,$08,$07,$06,$06,$05
 .byte $04,$04,$03,$02,$02,$01,$00,$00