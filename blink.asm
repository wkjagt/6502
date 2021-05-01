lcd_write = 0x80a3
lcd_set_gdram_address = 0x809d

    .org $0300

    lda #$0
    jsr lcd_set_gdram_address
    lda #$0
    jsr lcd_set_gdram_address
    lda #$55
    jsr lcd_write
    lda #$55
    jsr lcd_write
