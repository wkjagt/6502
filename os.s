; 6522 VIA
.segment "IO"

  .org $6000

  ; 6522 I/O Port Controller
  io_b:     .res 1 ; Register "B"
  io_a:     .res 1 ; Register "A"
  io_ddrb:  .res 1 ; Data Direction Register "B"
  io_ddra:  .res 1 ; Data Direction Register "A"
  io_t1c_l: .res 1 ; Read:  T1 Low-Order Counter
                   ; Write: T1 Low-Order Latches
  io_t1c_h: .res 1 ; T1 High-Order Counter
  io_t1l_l: .res 1 ; T1 Low-Order Latches
  io_t1l_h: .res 1 ; T1 High-Order Latches
  io_t2c_l: .res 1 ; Read:  T2 Low-Order Counter
                   ; Write: T2 Low-Order Latches
  io_t2c_h: .res 1 ; T2 High-Order Counter
  io_sr:    .res 1 ; Shift Register
  io_acr:   .res 1 ; Auxilary Control Register
  io_pcr:   .res 1 ; Peripheral Control Register
  io_ifr:   .res 1 ; Interrupt Flag Register
  io_ier:   .res 1 ; Interrupt Enable Register
  io_a_noh: .res 1 ; Same as Register "A" (io_a) except no "Handshake"

; LCD
E  = %10000000
RW = %01000000
RS = %00100000

.segment "SERIAL"
  .org $4000

; 6551 ACIA
serial_data:    .res 1
serial_status:  .res 1
serial_command: .res 1
serial_control: .res 1

ACIA_STATUS_IRQ        = 1 << 7
ACIA_STATUS_DSR        = 1 << 6
ACIA_STATUS_DCD        = 1 << 5
ACIA_STATUS_TX_EMPTY   = 1 << 4
ACIA_STATUS_RX_FULL    = 1 << 3
ACIA_STATUS_OVERRUN    = 1 << 2
ACIA_STATUS_FRAME_ERR  = 1 << 1
ACIA_STATUS_PARITY_ERR = 1 << 0

PROGRAM_START          = $0300

.segment "CODE"
                    .org $8000

reset: 
setup:              
setup_via:          lda #%11111111          ; Set all pins on port B to output
                    sta io_ddrb
                    lda #%11100001          ; Set top 3 pins on port A to output
                    sta io_ddra
setup_lcd:          lda #%00111000          ; Set 8-bit mode; 2-line display; 5x8 font
                    jsr send_lcd_command
                    lda #%00001110          ; Display on; cursor on; blink off
                    jsr send_lcd_command
                    lda #%00000110          ; Increment and shift cursor; don't shift display
                    jsr send_lcd_command
                    lda #$00000001          ; Clear display
                    jsr send_lcd_command
setup_acia:         lda #%11001011          ; No parity, no echo, no interrupt
                    sta serial_command
                    lda #%00011111          ; 1 stop bit, 8 data bits, 19200 baud
                    sta serial_control

loop:               lda serial_status
                    and #ACIA_STATUS_RX_FULL
                    beq loop
                    lda serial_data
                    jsr write          ; echo
                    cmp #'l'
                    bne loop

                    jsr load_program
                    
                    lda #'>'
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
                    lda #'!'
                    jsr write_lcd
                    rts

next_serial_byte:   lda serial_status
                    and #ACIA_STATUS_RX_FULL
                    beq next_serial_byte
                    lda serial_data
                    rts

write:              jsr write_acia
                    jsr write_lcd
                    rts

write_acia:         jsr delay
                    sta serial_data
                    rts

delay:              ldy #$ff
delay_not_done:     dey
                    bne delay_not_done
                    rts

lcd_wait:           pha
                    lda #%00000000          ; Port B is input to read busy LCD busy flag
                    sta io_ddrb
lcdbusy:            lda #RW
                    sta io_a
                    lda #(RW | E)
                    sta io_a
                    lda io_b
                    and #%10000000
                    bne lcdbusy

                    lda #RW
                    sta io_a
                    lda #%11111111          ; Port B is output
                    sta io_ddrb
                    pla
                    rts

send_lcd_command:   jsr lcd_wait
                    sta io_b
                    lda #0                  ; Clear RS/RW/E bits
                    sta io_a
                    lda #E                  ; Set E bit to send instruction
                    sta io_a
                    lda #0                  ; Clear RS/RW/E bits
                    sta io_a
                    nop
                    rts

write_lcd:          jsr lcd_wait
                    sta io_b
                    ldy #RS                 ; Set RS; Clear RW/E bits
                    sty io_a
                    ldy #(RS|E)             ; Set E bit to send instruction
                    sty io_a
                    ldy #RS                 ; Clear E bits
                    sty io_a
                    nop

                    rts

nmi:                rti
irq:                rti

.segment "VECTORS"
    .org $fffa
    
    .word nmi
    .word reset
    .word irq