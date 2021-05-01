lcd_write = 0x80a3
lcd_set_gdram_address = 0x809d

    .org $0300

    lda #16
    jsr lcd_set_gdram_address
    lda #$1
    jsr lcd_set_gdram_address
    lda #0b11111111
    jsr lcd_write
    lda #0b11111111
    jsr lcd_write
    rts


