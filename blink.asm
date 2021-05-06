LED_STATUS = $00

VIA_START = $6000
PORTA = VIA_START + 1
PORTB = VIA_START + 0
DDRA  = VIA_START + 3
DDRB  = VIA_START + 2

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
    sta PORTA
    jmp loop
led_on:
    lda #$ff
    sta LED_STATUS
    sta PORTA
    jmp loop
