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

vdp_patterns:
  ; characters follow ASCII order but leave out all non printing characters
  ; before the space character
  .byte $00, $00, $00, $00, $00, $00, $00, $00 ; ' '
  .byte $30, $78, $78, $30, $30, $00, $30, $00 ; !
  .byte $6c, $6c, $6c, $00, $00, $00, $00, $00 ; "
  .byte $6c, $6c, $fe, $6c, $fe, $6c, $6c, $00 ; #
  .byte $30, $7c, $c0, $78, $0c, $f8, $30, $00 ; $
  .byte $00, $c6, $cc, $18, $30, $66, $c6, $00 ; %
  .byte $38, $6c, $38, $76, $dc, $cc, $76, $00 ; &
  .byte $60, $60, $c0, $00, $00, $00, $00, $00 ; '
  .byte $18, $30, $60, $60, $60, $30, $18, $00 ; (
  .byte $60, $30, $18, $18, $18, $30, $60, $00 ; )
  .byte $00, $66, $3c, $ff, $3c, $66, $00, $00 ; *
  .byte $00, $30, $30, $fc, $30, $30, $00, $00 ; +
  .byte $00, $00, $00, $00, $00, $30, $30, $60 ; ,
  .byte $00, $00, $00, $fc, $00, $00, $00, $00 ; -
  .byte $00, $00, $00, $00, $00, $30, $30, $00 ; .
  .byte $06, $0c, $18, $30, $60, $c0, $80, $00 ; /
  .byte $7c, $c6, $ce, $de, $f6, $e6, $7c, $00 ; 0
  .byte $30, $70, $30, $30, $30, $30, $fc, $00 ; 1
  .byte $78, $cc, $0c, $38, $60, $cc, $fc, $00 ; 2
  .byte $78, $cc, $0c, $38, $0c, $cc, $78, $00 ; 3
  .byte $1c, $3c, $6c, $cc, $fe, $0c, $1e, $00 ; 4
  .byte $fc, $c0, $f8, $0c, $0c, $cc, $78, $00 ; 5
  .byte $38, $60, $c0, $f8, $cc, $cc, $78, $00 ; 6
  .byte $fc, $cc, $0c, $18, $30, $30, $30, $00 ; 7
  .byte $78, $cc, $cc, $78, $cc, $cc, $78, $00 ; 8
  .byte $78, $cc, $cc, $7c, $0c, $18, $70, $00 ; 9
  .byte $00, $30, $30, $00, $00, $30, $30, $00 ; :
  .byte $00, $30, $30, $00, $00, $30, $30, $60 ; ;
  .byte $18, $30, $60, $c0, $60, $30, $18, $00 ; <
  .byte $00, $00, $fc, $00, $00, $fc, $00, $00 ; =
  .byte $60, $30, $18, $0c, $18, $30, $60, $00 ; >
  .byte $78, $cc, $0c, $18, $30, $00, $30, $00 ; ?
  .byte $7c, $c6, $de, $de, $de, $c0, $78, $00 ; @
  .byte $30, $78, $cc, $cc, $fc, $cc, $cc, $00 ; A
  .byte $fc, $66, $66, $7c, $66, $66, $fc, $00 ; B
  .byte $3c, $66, $c0, $c0, $c0, $66, $3c, $00 ; C
  .byte $f8, $6c, $66, $66, $66, $6c, $f8, $00 ; D
  .byte $fe, $62, $68, $78, $68, $62, $fe, $00 ; E
  .byte $fe, $62, $68, $78, $68, $60, $f0, $00 ; F
  .byte $3c, $66, $c0, $c0, $ce, $66, $3e, $00 ; G
  .byte $cc, $cc, $cc, $fc, $cc, $cc, $cc, $00 ; H
  .byte $78, $30, $30, $30, $30, $30, $78, $00 ; I
  .byte $1e, $0c, $0c, $0c, $cc, $cc, $78, $00 ; J
  .byte $e6, $66, $6c, $78, $6c, $66, $e6, $00 ; K
  .byte $f0, $60, $60, $60, $62, $66, $fe, $00 ; L
  .byte $c6, $ee, $fe, $fe, $d6, $c6, $c6, $00 ; M
  .byte $c6, $e6, $f6, $de, $ce, $c6, $c6, $00 ; N
  .byte $38, $6c, $c6, $c6, $c6, $6c, $38, $00 ; O
  .byte $fc, $66, $66, $7c, $60, $60, $f0, $00 ; P
  .byte $78, $cc, $cc, $cc, $dc, $78, $1c, $00 ; Q
  .byte $fc, $66, $66, $7c, $6c, $66, $e6, $00 ; R
  .byte $78, $cc, $60, $30, $18, $cc, $78, $00 ; S
  .byte $fc, $b4, $30, $30, $30, $30, $78, $00 ; T
  .byte $cc, $cc, $cc, $cc, $cc, $cc, $fc, $00 ; U
  .byte $cc, $cc, $cc, $cc, $cc, $78, $30, $00 ; V
  .byte $c6, $c6, $c6, $d6, $fe, $ee, $c6, $00 ; W
  .byte $c6, $c6, $6c, $38, $38, $6c, $c6, $00 ; X
  .byte $cc, $cc, $cc, $78, $30, $30, $78, $00 ; Y
  .byte $fe, $c6, $8c, $18, $32, $66, $fe, $00 ; Z
  .byte $78, $60, $60, $60, $60, $60, $78, $00 ; [
  .byte $c0, $60, $30, $18, $0c, $06, $02, $00 ; \
  .byte $78, $18, $18, $18, $18, $18, $78, $00 ; ]
  .byte $10, $38, $6c, $c6, $00, $00, $00, $00 ; ^
  .byte $00, $00, $00, $00, $00, $00, $00, $ff ; _
  .byte $30, $30, $18, $00, $00, $00, $00, $00 ; `
  .byte $00, $00, $78, $0c, $7c, $cc, $76, $00 ; a
  .byte $e0, $60, $60, $7c, $66, $66, $dc, $00 ; b
  .byte $00, $00, $78, $cc, $c0, $cc, $78, $00 ; c
  .byte $1c, $0c, $0c, $7c, $cc, $cc, $76, $00 ; d
  .byte $00, $00, $78, $cc, $fc, $c0, $78, $00 ; e
  .byte $38, $6c, $60, $f0, $60, $60, $f0, $00 ; f
  .byte $00, $00, $76, $cc, $cc, $7c, $0c, $f8 ; g
  .byte $e0, $60, $6c, $76, $66, $66, $e6, $00 ; h
  .byte $30, $00, $70, $30, $30, $30, $78, $00 ; i
  .byte $0c, $00, $0c, $0c, $0c, $cc, $cc, $78 ; j
  .byte $e0, $60, $66, $6c, $78, $6c, $e6, $00 ; k
  .byte $70, $30, $30, $30, $30, $30, $78, $00 ; l
  .byte $00, $00, $cc, $fe, $fe, $d6, $c6, $00 ; m
  .byte $00, $00, $f8, $cc, $cc, $cc, $cc, $00 ; n
  .byte $00, $00, $78, $cc, $cc, $cc, $78, $00 ; o
  .byte $00, $00, $dc, $66, $66, $7c, $60, $f0 ; p
  .byte $00, $00, $76, $cc, $cc, $7c, $0c, $1e ; q
  .byte $00, $00, $dc, $76, $66, $60, $f0, $00 ; r
  .byte $00, $00, $7c, $c0, $78, $0c, $f8, $00 ; s
  .byte $10, $30, $7c, $30, $30, $34, $18, $00 ; t
  .byte $00, $00, $cc, $cc, $cc, $cc, $76, $00 ; u
  .byte $00, $00, $cc, $cc, $cc, $78, $30, $00 ; v
  .byte $00, $00, $c6, $d6, $fe, $fe, $6c, $00 ; w
  .byte $00, $00, $c6, $6c, $38, $6c, $c6, $00 ; x
  .byte $00, $00, $cc, $cc, $cc, $7c, $0c, $f8 ; y
  .byte $00, $00, $fc, $98, $30, $64, $fc, $00 ; z
  .byte $1c, $30, $30, $e0, $30, $30, $1c, $00 ; {
  .byte $18, $18, $18, $00, $18, $18, $18, $00 ; |
  .byte $e0, $30, $30, $1c, $30, $30, $e0, $00 ; }
  .byte $76, $dc, $00, $00, $00, $00, $00, $00 ; ~
; non ascii
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00 ; cursor
vdp_end_patterns: