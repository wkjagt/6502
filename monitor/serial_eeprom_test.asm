; SAVE "HELLO WORLD" TO EEPROM AND READ IT BACK

BYTE_OUT        =       $00         ; address used for shifting bytes
BYTE_IN         =       $01         ; address used to shift reveived bits into
LAST_ACK_BIT    =       $06
ARGS            =       $07



SER_DATA        =       $4800       ; Data register
SER_ST          =       $4801       ; Status register
SER_CMD         =       $4802       ; Command register
SER_CTL         =       $4803       ; Control register
SER_RXFL        =       %00001000   ; Serial Receive full bit
PORTA           =       $6001       ; Data port A
PORTA_DDR       =       $6003       ; Data direction of port A

DATA_PIN        =       %10            
CLOCK_PIN       =       %01

EEPROM_CMD      =       %10100000
WRITE_MODE      =       0
READ_MODE       =       1
BLOCK0          =       %0000
BLOCK1          =       %1000
DEVICE0         =       %000
DEVICE1         =       %010
DEVICE2         =       %100
DEVICE3         =       %110

                .ORG    $0700

; ========================= INITIALIZE ===========================
                sei                     ; Disable interrupts
                lda     #$0a            ; new line for debugging
                jsr     write_to_terminal

                ; set pins 0 and 1 to outputs
                lda     PORTA_DDR
                ora     #(DATA_PIN | CLOCK_PIN)
                sta     PORTA_DDR



               CALL WRITE SEQUENVE ROUTINE
                ; arg: block / device
                lda     #%000           ; block 1, device 0
                sta     ARGS
                ; arg: target high address
                lda     #0              ; target address high byte
                sta     ARGS+1
                ; arg: target low address
                lda     #0              ; target address low byte
                sta     ARGS+2

                ; arg: address of start of string
                lda     #<text          ; low byte of address of first byte
                sta     ARGS+3
                lda     #>text          ; high byte of address of first byte
                sta     ARGS+4          

                ; arg: string length
                lda     #21             ; number of bytes to write
                sta     ARGS+5

                jsr     write_sequence
                rts
text:
                .asciiz "This is a third test"


;=============== CALL READ SEQUENCE ROUTINE ===========
                ; arg: block / device
                lda     #%000           ; block 1, device 0
                sta     ARGS
                ; arg: target high address
                lda     #0              ; target address high byte
                sta     ARGS+1
                ; arg: target low address
                lda     #0              ; target address low byte
                sta     ARGS+2

                ; arg: address to write string to
                lda     #0          ; low byte of address of first byte
                sta     ARGS+3
                lda     #2          ; high byte of address of first byte
                sta     ARGS+4          

                ; arg: string length
                lda     #21             ; number of bytes to write
                sta     ARGS+5

                jsr     read_sequence
                rts


write_sequence:
                jsr     start_condition
                lda     ARGS            ; block / device
                asl                     
                sta     ARGS
                lda     #(EEPROM_CMD | WRITE_MODE)
                ora     ARGS            ; set block and device bits in A
                jsr     transmit_byte   ; send command to EEPROM

                lda     ARGS+1
                ldx     ARGS+2
                jsr     set_address     ; pulls two bytes from the stack

                ldy     #0              ; start at 0
.byte_loop:
                lda     (ARGS+3),y
                jsr     write_to_terminal
                jsr     transmit_byte
                iny
                cpy     ARGS+5            ; compare with string lengths in TMP1
                bne     .byte_loop
                jsr     stop_condition
                rts



; ========================= ACKNOWLEDGE POLL ===========================
; ack_loop:
;                 jsr     start_condition
;                 lda     #(EEPROM_CMD | WRITE_MODE | DEVICE0 | BLOCK0)
;                 jsr     transmit_byte
;                 ; read ack bit
;                 lda     LAST_ACK_BIT
;                 bne     ack_loop
; ; ========================= READ FROM EEPROM ===========================




read_sequence:
                ; send start condition
                jsr     start_condition
                ; send block / device / write mode
                lda     ARGS            ; block / device
                asl                     
                sta     ARGS
                lda     #(EEPROM_CMD | WRITE_MODE)
                ora     ARGS
                jsr     transmit_byte   ; send command to EEPROM

                ; send address
                lda     ARGS+1
                ldx     ARGS+2
                jsr     set_address     ; pulls two bytes from the stack

                ; send start condition
                jsr     start_condition

                ; send block / device / read mode
                lda     #(EEPROM_CMD | READ_MODE)
                ora     ARGS
                jsr     transmit_byte   ; send command to EEPROM

                ; set data pin as input
                lda     PORTA_DDR
                and     #%11111110      ; data direction to input on the data line
                sta     PORTA_DDR

                ldx     #0              ; byte counter, counts up to length in ARGS+5
.byte_loop:
                ldy     #8              ; bit counter, counts down to 0
.bit_loop:
                jsr     clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr     A               ; shift the reveived bit onto the carry flag
                rol     BYTE_IN         ; shift the received bit into the the received byte
                jsr     clock_low
                
                dey
                bne     .bit_loop

                lda     BYTE_IN
                jsr     write_to_terminal

                inx
                cpx     ARGS+5
                beq     .done           ; no ack for last byte

                ; ack the reception of the byte
                lda     PORTA_DDR
                ora     #%00000001      ; set data line to output
                sta     PORTA_DDR

                lda     PORTA
                and     #%11111110      ; set data line low to ack
                sta     PORTA

                jsr     clock_high
                jsr     clock_low

                lda     PORTA_DDR
                and     #%11111110      ; set data line back to input
                sta     PORTA_DDR
                jmp     .byte_loop
.done:
                ; temp: set back to outputs
                lda     #$ff
                sta     PORTA_DDR
                sta     PORTA

                jsr     stop_condition
                rts

start_condition:
                ; 1. DEACTIVATE BUS
                lda     PORTA
                ora     #(DATA_PIN | CLOCK_PIN)      ; clock and data high
                sta     PORTA
                ; 2. START CONDITION
                and     #%11111110      ; clock stays high, data goes low
                sta     PORTA
                and     #%11111101      ; then pull clock low
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

; a: high byte, x: low byte
set_address:    
                jsr     transmit_byte   ; high address byte
                txa                     ; low address byte from x
                jsr     transmit_byte   ; low address byte
                rts

; TRANSMIT BYTE ROUTINE
transmit_byte:
                pha
                phy
                sta     BYTE_OUT
                ldy     #8
.transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     BYTE_OUT        ; shift next bit into carry
                rol     A               ; shift carry into bit 0 of A
                and     #%11111101      ; make sure clock is low when placing the bit on the bus
                sta     PORTA
                jsr     clock_high      ; toggle clock to strobe it into the eeprom
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
                ply
                pla
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
