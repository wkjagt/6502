    .macro vdp_write_vram
    pha
    lda #<(\1)
    sta VDP_REG
    lda #(VDP_WRITE_VRAM_BIT | >\1) ; see second register write pattern
    sta VDP_REG
    pla
    .endm

    .macro store_registers
    pha
    phy
    phx
    .endm

    .macro restore_registers
    plx
    ply
    pla
    .endm