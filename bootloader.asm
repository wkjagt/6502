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

PROGRAM_WRITE_PTR_L    = $0002  ; pointer to address where the next byte is written (2 bytes)
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


; phase 1: read 128 bytes and return
; phase 2: send EOT character and use to end loading
; phase 3: send SOH character and use to start loading
; phase 4: send packet numbers and start verifying

load_program:       
.header_byte:       jsr next_serial_byte  ; read byte
                    cmp #$04             ; EOT
                    beq .done
                    ldy #0x80             ; packet size: 128 
.program_byte:      jsr next_serial_byte
                    sta (PROGRAM_WRITE_PTR_L)
                    jsr inc_prgrm_pointer
                    dey
                    beq .header_byte       ; when y == 0, end of packet
                    jmp .program_byte
.done:              tya
                    jsr debug
                    rts

inc_prgrm_pointer:  clc
                    inc PROGRAM_WRITE_PTR_L
                    bcc .done
                    inc PROGRAM_WRITE_PTR_H
.done:              rts

debug:
    pha
    lda #0
    jsr lcd_set_gdram_address
    lda #$0
    jsr lcd_set_gdram_address
    pla
    jsr lcd_write
    lda #0
    jsr lcd_write
    rts

next_serial_byte:   lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq next_serial_byte
                    lda ACIA_DATA
                    rts

nmi:                rti
irq:                rti

                    .org $FFFA
                    .word nmi
                    .word reset
                    .word irq