; TMS9918A
VDP_VRAM               = $8000
VDP_REG                = $8001
VDP_WRITE_VRAM_BIT     = %01000000  ; pattern of second vram address write: 01AAAAAA
VDP_REGISTER_BITS      = %10000000  ; pattern of second register write: 10000RRR

VDP_NAME_TABLE_BASE            = $0400
VDP_PATTERN_TABLE_BASE         = $0800
VDP_COLOR_TABLE_BASE           = $0200
VDP_SPRITE_PATTERNS_TABLE_BASE = $0000
VDP_SPRITE_ATTR_TABLE_BASE     = $0100

; zero page addresses
VDP_PATTERN_INIT    = $30
VDP_PATTERN_INIT_HI = $31
VDP_SPRITE_INIT     = $32
VDP_SPRITE_INIT_HI  = $33

BALL_HOR_DIRECTION  = $34
BALL_VER_DIRECTION  = $35
BALL_X              = $36
BALL_Y              = $37
PADDLE_X            = $38
PADDLE_Y            = $39
PADDLE_LEFT_NAME    = $1
PADDLE_CENTER_NAME  = $2
PADDLE_RIGHT_NAME   = $3

BLOCKS_START_ADDRESS = $60

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
  jsr game_setup
  cli
  jmp game_loop

game_setup:
  jsr init_ball
  jsr init_paddle
  jsr init_blocks

  rts

vdp_setup:
  ; patterns
  jsr vdp_initialize_pattern_table
  jsr vdp_initialize_color_table
  ; sprites
  jsr initialize_sprites
  jsr vdp_clear_display
  jsr vdp_enable_display
  rts

game_loop:
  jsr update_game
  jsr delay
  jmp game_loop

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

vdp_clear_display:
  vdp_write_vram VDP_NAME_TABLE_BASE
  lda #0
  ldx #$3
  ldy #0
vdp_clear_display_loop:
  sta VDP_VRAM
  iny
  bne vdp_clear_display_loop
  dex
  bne vdp_clear_display_loop
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

vdp_initialize_color_table:
  vdp_write_vram VDP_COLOR_TABLE_BASE
  ldx #$20
  lda #$1a   ; color
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

init_ball:
  lda #0
  sta BALL_HOR_DIRECTION ; 0: left, 1: right
  sta BALL_VER_DIRECTION ; 0: down, 2: up
  lda #$10               ; start position
  sta BALL_X
  lda #$20 
  sta BALL_Y
  rts

init_paddle:
  lda #$0
  sta PADDLE_X
  lda #$aa
  sta PADDLE_Y
  rts

init_blocks:
  ; block width = 24 (3 sprites)
  ; first block starts at x = 8
  ldx #$0 ; index
  lda #$8 ; x coordinate
  ldy #$8 ; y coordinate
  sta BLOCKS_START_ADDRESS, x
  inx
  adc #$24
  sta BLOCKS_START_ADDRESS, x
  inx
  

  ; write blocks to name table to display on screen
  vdp_write_vram (VDP_NAME_TABLE_BASE + 33)
  ldx #$a ; 10 blocks
.blocks_loop:
  ldy #$1
.block_loop:
  sty VDP_VRAM
  iny
  cpy #$4
  bne .block_loop
  dex
  bne .blocks_loop
  rts


update_game:
  jsr set_ball_hor_direction
  jsr set_ball_ver_direction
  jsr set_ball_pos
  jsr set_paddle_pos
  rts

draw_ball:
  vdp_write_vram VDP_SPRITE_ATTR_TABLE_BASE
  lda BALL_Y
  sta VDP_VRAM
  lda BALL_X
  sta VDP_VRAM
  lda #0
  sta VDP_VRAM
  lda #$01
  sta VDP_VRAM
  rts

draw_paddle:
  pha

  vdp_write_vram (VDP_SPRITE_ATTR_TABLE_BASE + 4)
  lda PADDLE_Y
  sta VDP_VRAM
  lda PADDLE_X
  sbc #$7
  sta VDP_VRAM
  lda #PADDLE_LEFT_NAME
  sta VDP_VRAM
  lda #$01
  sta VDP_VRAM

  lda PADDLE_Y
  sta VDP_VRAM
  lda PADDLE_X
  sta VDP_VRAM
  lda #PADDLE_CENTER_NAME
  sta VDP_VRAM
  lda #$01
  sta VDP_VRAM

  lda PADDLE_Y
  sta VDP_VRAM
  lda PADDLE_X
  adc #$7
  sta VDP_VRAM
  lda #PADDLE_RIGHT_NAME
  sta VDP_VRAM
  lda #$01
  sta VDP_VRAM

  pla
  rts

set_ball_hor_direction:
verify_left_border:
  lda BALL_X
  cmp #$4
  bne verify_right_border ; not currently 0
  lda #$1
  sta BALL_HOR_DIRECTION
  rts
verify_right_border:
  cmp #$f9
  bne .done
  lda #$0
  sta BALL_HOR_DIRECTION
.done:
  rts

set_ball_ver_direction:
verify_top_border:
  lda BALL_Y
  cmp #$0f
  bne verify_bottom_border
  lda #$1
  sta BALL_VER_DIRECTION
  rts
verify_bottom_border:
  cmp #$a3
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

set_paddle_pos:
  lda BALL_X
  cmp #$0c
  bcc .max_left
  cmp #$f0
  bcs .max_right
  jmp .done
.max_left:
  lda #$0c
  jmp .done
.max_right
  lda #$f0
.done
  sta PADDLE_X
  rts

delay:
  phx
  phy
  ldx #$ff
  ldy #$07
delay_loop:
  dex
  bne delay_loop
  dey
  bne delay_loop
  ply
  plx
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
  jsr draw_paddle
.done
  plx
  ply
  pla
  cli
  rts

vdp_patterns:
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; empty, used to clear the screen
  .byte $7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f ; block left
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; block center
  .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe ; block right
vdp_end_patterns:


vdp_sprite_patterns:
  .byte $3c,$42,$f1,$f9,$fd,$fd,$7e,$3c    ; ball 
  .byte $7f,$ff,$ff,$ff,$ff,$7f,$00,$00    ; paddle left
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$00,$00    ; paddle center
  .byte $fe,$ff,$ff,$ff,$ff,$fe,$00,$00    ; paddle right
vdp_end_sprite_patterns:
