
vdp_write_register: .macro register, data
  lda #\data
  sta VDP_REG

  lda #\register
  sta VDP_REG
.endm
