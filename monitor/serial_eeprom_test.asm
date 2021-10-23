; SAVE "HELLO WORLD" TO EEPROM AND READ IT BACK

BYTE_TO_TRANSMIT =      $00         ; address used for shifting bytes
RECEIVED_BYTE    =      $01         ; address used to shift reveived bits into
LAST_ACK_BIT     =      $06
SER_DATA         =      $4800       ; Data register
SER_ST           =      $4801       ; Status register
SER_CMD          =      $4802       ; Command register
SER_CTL          =      $4803       ; Control register
SER_RXFL         =      %00001000   ; Serial Receive full bit
PORTA            =      $6001       ; Data port A
PORTA_DDR        =      $6003       ; Data direction of port A

                .ORG    $0700

; ========================= INITIALIZE ===========================
                sei             ; Disable interrupts
                lda     #"3"
                jsr     write_to_terminal

                lda     #$ff
                sta     PORTA_DDR

; ========================= WRITE TO EEPROM ===========================

                jsr     start_condition
                jsr     set_write_mode
                jsr     set_address
; 7. TRANSMIT A BYTE
                lda     #"@"            ; random test charachter
                sta     BYTE_TO_TRANSMIT
                jsr     transmit_byte

                jsr     stop_condition
; ========================= ACKNOWLEDGE POLL ===========================
ack_loop:
                jsr     start_condition
                jsr     set_write_mode
                ; read ack bit
                lda     LAST_ACK_BIT
                bne     ack_loop
; ========================= READ FROM EEPROM ===========================

                ; jsr     start_condition
                ; jsr     set_write_mode  ; write mode is used to set the address pointer
                ; jsr     set_address
                ; jsr     start_condition ; random read mode requires two start conditions
                ; jsr     set_read_mode
                ; jsr     receive_byte    ; this should receive the byte in RECEIVED_BYTE
                ; jsr     stop_condition

                ; lda     RECEIVED_BYTE
                ; jsr     write_to_terminal

                rts

start_condition:
; 1. DEACTIVATE BUS
                lda     #%00000011      ; clock and data high
                sta     PORTA

; 2. START CONDITION
                ; clock stays high, data goes low
                and     #%11111110
                sta     PORTA

                ; then pull clock low
                and     #%11111101
                sta     PORTA
                rts

stop_condition:
                lda     PORTA
                and     #%11111110      ; data low
                sta     PORTA
                jsr     clock_high      ; clock high
                lda     PORTA
                ora     #%00000001      ; data high
                sta     PORTA
                rts

set_write_mode:
                lda     #%10100000      ; block zero CS1: 0, CS2: 0, Write
                sta     BYTE_TO_TRANSMIT
                jsr     transmit_byte
                rts

set_read_mode:
                lda     #%10100001      ; block zero CS1: 0, CS2: 0, READ
                sta     BYTE_TO_TRANSMIT
                jsr     transmit_byte
                rts

set_address:
                lda     #0              ; for testing, start at address 0
                sta     BYTE_TO_TRANSMIT
                jsr     transmit_byte   ; high address byte
                jsr     transmit_byte   ; low address byte
                rts

; TRANSMIT BYTE ROUTINE
transmit_byte:
                ldy     #8
.transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     BYTE_TO_TRANSMIT; shift next bit into carry
                rol     A               ; shift carry into bit 0 of A
                and     #%11111101      ; make sure clock is low when placing the bit on the bus
                sta     PORTA
                jsr     clock_high
                jsr     clock_low

                dey
                bne     .transmit_loop

                ; After each byte, the EEPROM expects a clock cycle during which 
                ; it pulls the data line low to signal that the byte was received
                lda     PORTA_DDR
                and     #%11111110      ; set data line as input to receive ack
                sta     PORTA_DDR
                jsr     clock_high
                lda     PORTA
                and     #%00000001      ; only save last bit
                sta     LAST_ACK_BIT
                jsr     clock_low
                lda     PORTA_DDR
                ora     #%00000001      ; set data line back to output
                sta     PORTA_DDR
                rts


receive_byte:
                lda     PORTA_DDR
                and     #%11111110      ; data direction to input on the data line
                sta     PORTA_DDR
                ldy     #8
.receive_loop:
                jsr     clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr     A               ; shift the reveived bit onto the carry flag
                rol     RECEIVED_BYTE   ; shift the received bit into the the received byte
                jsr     clock_high
                
                dey
                bne .receive_loop

                rts

clock_high:    ; toggle clock from high to low to strobe the bit into the eeprom
                lda     PORTA
                ora     #%00000010      ; clock high
                sta     PORTA
                rts
clock_low:         
                lda     PORTA       
                and     #%11111101      ; clock low
                sta     PORTA
                rts



write_to_terminal:
                PHY
                LDY #$ff
wait_txd_empty:
                DEY
                BNE wait_txd_empty
                STA SER_DATA
                PLY
                RTS
