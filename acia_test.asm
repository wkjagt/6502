; 6522 VIA
PORTA = $6001
PORTB = $6000
DDRA = $6003
DDRB = $6002

; LCD
E  = %10000000
RW = %01000000
RS = %00100000

; 6551 ACIA
ACIA_DATA = $4000
ACIA_STATUS = $4001
ACIA_COMMAND = $4002
ACIA_CONTROL = $4003

ACIA_STATUS_IRQ        = 1 << 7
ACIA_STATUS_DSR        = 1 << 6
ACIA_STATUS_DCD        = 1 << 5
ACIA_STATUS_TX_EMPTY   = 1 << 4
ACIA_STATUS_RX_FULL    = 1 << 3
ACIA_STATUS_OVERRUN    = 1 << 2
ACIA_STATUS_FRAME_ERR  = 1 << 1
ACIA_STATUS_PARITY_ERR = 1 << 0

    .org $8000

reset:
    ; Set up 6522 VIA for the LCD
    lda #%11111111          ; Set all pins on port B to output
    sta DDRB
    lda #%11100001          ; Set top 3 pins on port A to output
    sta DDRA
    lda #%00111000          ; Set 8-bit mode; 2-line display; 5x8 font
    JSR send_lcd_command
    lda #%00001110          ; Display on; cursor on; blink off
    JSR send_lcd_command
    lda #%00000110          ; Increment and shift cursor; don't shift display
    JSR send_lcd_command
    lda #$00000001          ; Clear display
    jsr send_lcd_command

    ; Set up 6551 ACIA
    lda #%11001011          ; No parity, no echo, no interrupt
    sta ACIA_COMMAND
    lda #%00011111          ; 1 stop bit, 8 data bits, 19200 baud
    sta ACIA_CONTROL

write:
    LDX #0
next_char:
    LDY #$ff
wait_txd_empty:
    DEY
    BNE wait_txd_empty
    LDA text,x
    BEQ read
    jsr write_acia
    INX
    JMP next_char
read:
    LDA ACIA_STATUS
    AND #ACIA_STATUS_RX_FULL
    BEQ read
    LDA ACIA_DATA
    JSR write_acia
    JSR write_lcd           ; Also send to LCD
    JMP read

write_acia:
    STA ACIA_DATA
    RTS

lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

send_lcd_command:
    jsr lcd_wait
    STA PORTB
    LDA #0                  ; Clear RS/RW/E bits
    STA PORTA
    LDA #E                  ; Set E bit to send instruction
    STA PORTA
    LDA #0                  ; Clear RS/RW/E bits
    STA PORTA
    NOP
    RTS

write_lcd:
    jsr lcd_wait
    STA PORTB
    LDX #RS                 ; Set RS; Clear RW/E bits
    STX PORTA
    LDX #(RS|E)             ; Set E bit to send instruction
    STX PORTA
    LDX #RS                 ; Clear E bits
    STX PORTA
    NOP
    RTS

nmi:
    RTI

irq:
    RTI

text:                    ; CR   LF  Null
    .byte "Kello World!", $0d, $0a, $00

    .org $FFFA
    .word nmi
    .word reset
    .word irq