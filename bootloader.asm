; 6522 VIA
VIA_START = $6000
PORTA = VIA_START + 1
PORTB = VIA_START + 0
DDRA  = VIA_START + 3
DDRB  = VIA_START + 2

; 6551 ACIA
ACIA_START   = $4000
ACIA_DATA    = ACIA_START + 0
ACIA_STATUS  = ACIA_START + 1
ACIA_COMMAND = ACIA_START + 2
ACIA_CONTROL = ACIA_START + 3


ACIA_STATUS_RX_FULL    = 1 << 3

PROGRAM_WRITE_PTR_L    = $0002
PROGRAM_WRITE_PTR_H    = $0003
PROGRAM_START          = $0300

  .org $8000
  .include lcd.asm

reset: 
setup:              
setup_acia:         lda #%11001011          ; No parity, no echo, no interrupt
                    sta ACIA_COMMAND
                    lda #%00011111          ; 1 stop bit, 8 data bits, 19200 baud
                    sta ACIA_CONTROL
setup_program_ptrs: lda #0                   ; reset counters that count prgram length
                    sta PROGRAM_WRITE_PTR_L
                    lda #$03
                    sta PROGRAM_WRITE_PTR_H
                    jsr lcd_init

loop:               lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq loop
                    lda ACIA_DATA
                    cmp #"l"
                    bne loop
                    jsr load_program
                    jsr PROGRAM_START
                    jmp loop

load_program:       
.header_byte:       jsr read_serial_byte       ; read byte
                    cmp #$04                   ; EOT
                    beq .done
                    ldy #0x80                  ; packet size: 128 
.program_byte:      jsr read_serial_byte
                    sta (PROGRAM_WRITE_PTR_L)
                    jsr inc_prgrm_pointer
                    dey
                    beq .header_byte           ; when y == 0, end of packet
                    jmp .program_byte
.done:              tya
                    rts

inc_prgrm_pointer:  clc
                    inc PROGRAM_WRITE_PTR_L
                    bcc .done
                    inc PROGRAM_WRITE_PTR_H
.done:              rts

read_serial_byte:   lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq read_serial_byte
                    lda ACIA_DATA
                    rts

nmi:                rti
irq:                rti

                    .org $FFFA
                    .word nmi
                    .word reset
                    .word irq