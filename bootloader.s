; .include "serial.inc"
; .include "io.inc"
; .include "lcd.inc"
; .import setup_via
; .import setup_lcd
.import setup_via
.import setup_lcd
.import setup_acia
.import write_acia
.import next_serial_byte
.import serial_data
.import serial_status
.import write_lcd

.segment "CODE"
.define PROGRAM_START  $0300

reset: 
setup:
    jsr setup_via
    jsr setup_lcd
    jsr setup_acia

loop:
    lda serial_status
    and #1 << 3        ; import this?
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

write:              jsr write_acia
                    jsr write_lcd
                    rts


nmi:                rti
irq:                rti

.segment "VECTORS"
.word nmi
.word reset
.word irq