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

  .macro vdp_write_vram
  lda #<(\1)
  sta VDP_REG
  lda #(VDP_WRITE_VRAM_BIT | >\1) ; see second register write pattern
  sta VDP_REG
  .endm

vdp_setup:
  jsr clear_vram
  jsr vdp_set_registers
  ; jsr vdp_enable_display
  rts

clear_vram:
  vdp_write_vram $0000
  ldx #$ff
  ldy #$40
  lda #$0
.loop:
  sta VDP_VRAM
  dex
  bne .loop
  dey
  bne .loop
  rts

vdp_set_registers:
  pha
  phx
  ldx #0
.loop:
  lda vdp_register_inits,x
  sta VDP_REG
  txa
  ora #VDP_REGISTER_BITS ; combine the register number with the second write pattern
  sta VDP_REG
  inx
  cpx #(vdp_end_register_inits - vdp_register_inits) ; compute number of registers
  bne .loop
  plx
  pla
  rts

; vdp_enable_display:
;   pha
;   lda vdp_register_1
;   ora #%01000000 ; enable the active display
;   sta VDP_REG
;   lda #(VDP_REGISTER_BITS | 1)
;   sta VDP_REG
;   pla
;   sta VDP_VRAM
;   rts

vdp_register_inits:
vdp_register_0: .byte %00000000 ; 0  0  0  0  0  0  M3 EXTVDP
vdp_register_1: .byte %10100000 ; 16k Bl IE M1 M2 0 Siz MAG
vdp_register_2: .byte $01       ; Name table base / $400 * $00 = $0000
vdp_register_3: .byte $08       ; Color table base / $40 * $10 = $0400
vdp_register_4: .byte $01       ; Pattern table base / $800 * $01 = $0800
vdp_register_5: .byte $02       ; Sprite attribute table base / $80 * $60 = $3000
vdp_register_6: .byte $00       ; Sprite pattern generator base / $800 * $04 = $2000
vdp_register_7: .byte $f1       ; FG/BG. 1=>Black, E=>Gray
vdp_end_register_inits:
