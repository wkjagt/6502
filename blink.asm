; This is a program that loads into RAM over serial

LED_STATUS = $00

  .org $0300

    lda #0
    sta LED_STATUS

loop:
    ldx #$ff
    ldy #$ff
delay:
    dex
    bne delay
    dey
    bne delay     

    lda LED_STATUS
    beq led_on ; if the led is on, turn if off 
led_off:
    lda #0
    sta LED_STATUS
    sta $6001
    jmp loop
led_on:
    lda #1
    sta LED_STATUS
    sta $6001
    jmp loop
