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

PROGRAM_LENGTH_L       = $0000
PROGRAM_LENGTH_H       = $0001
PROGRAM_WRITE_PTR      = $0002  ; pointer to address where the next byte is written (2 bytes)
PROGRAM_START          = $0300

                    .org $8000
    20
reset: 
setup:              
setup_via:          lda #%11111111          ; Set all pins on port B to output a9 ff
                    sta DDRB                ; 8d 02 60
                    lda #%11100001          ; Set top 3 pins on port A to output a9 e1
                    sta DDRA                ; 8d  03 60
setup_lcd:          lda #%00111000          ; Set 8-bit mode; 2-line display; 5x8 font  a9 38
                    jsr send_lcd_command    20
                    lda #%00001110          ; Display on; cursor on; blink off
                    jsr send_lcd_command
                    lda #%00000110          ; Increment and shift cursor; don't shift display
                    jsr send_lcd_command
                    lda #$00000001          ; Clear display
                    jsr send_lcd_command
setup_acia:         lda #%11001011          ; No parity, no echo, no interrupt
                    sta ACIA_COMMAND
                    lda #%00011111          ; 1 stop bit, 8 data bits, 19200 baud
                    sta ACIA_CONTROL
setup_program_ptrs: lda #0                   ; reset counters that count prgram length
                    sta PROGRAM_LENGTH_L
                    sta PROGRAM_LENGTH_H
                    lda #00                  ; is there a nicer way, by referencing PROGRAM_START?
                    sta PROGRAM_WRITE_PTR
                    lda #$30
                    sta PROGRAM_WRITE_PTR + 1

loop:               lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq loop
                    lda ACIA_DATA
                    jsr write          ; echo
                    cmp #"l"
                    bne loop

                    jsr load_program
                    
                    lda #">"
                    jsr write_lcd
                    
                    jmp PROGRAM_START
                    jmp loop

; this is limited to programs < 256 bytes. Make it fancier by using 16 bit addressing
load_program:       ldy #0
                    jsr next_serial_byte
                    tax
store_program_byte: jsr next_serial_byte
                    sta PROGRAM_START,y
                    iny
                    dex
                    bne store_program_byte
                    lda #"!"
                    jsr write_lcd
                    rts

next_serial_byte:   lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq next_serial_byte
                    lda ACIA_DATA
                    rts

write:              jsr write_acia
                    jsr write_lcd
                    rts

write_acia:         jsr delay
                    sta ACIA_DATA
                    rts

delay:              ldy #$ff
delay_not_done:     dey
                    bne delay_not_done
                    rts

lcd_wait:           pha
                    lda #%00000000          ; Port B is input to read busy LCD busy flag
                    sta DDRB
lcdbusy:            lda #RW
                    sta PORTA
                    lda #(RW | E)
                    sta PORTA
                    lda PORTB
                    and #%10000000
                    bne lcdbusy

                    lda #RW
                    sta PORTA
                    lda #%11111111          ; Port B is output
                    sta DDRB
                    pla
                    rts

send_lcd_command:   jsr lcd_wait
                    sta PORTB
                    lda #0                  ; Clear RS/RW/E bits
                    sta PORTA
                    lda #E                  ; Set E bit to send instruction
                    sta PORTA
                    lda #0                  ; Clear RS/RW/E bits
                    sta PORTA
                    nop
                    rts

write_lcd:          jsr lcd_wait
                    sta PORTB
                    ldy #RS                 ; Set RS; Clear RW/E bits
                    sty PORTA
                    ldy #(RS|E)             ; Set E bit to send instruction
                    sty PORTA
                    ldy #RS                 ; Clear E bits
                    sty PORTA
                    nop

                    rts

nmi:                rti
irq:                rti

                    .org $FFFA
                    .word nmi
                    .word reset
                    .word irq