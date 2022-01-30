JUMP_TABLE_ADDR         = $300
JMP_DUMP:               = JUMP_TABLE_ADDR + 0
JMP_RCV:                = JUMP_TABLE_ADDR + 3
JMP_INIT_SCREEN:        = JUMP_TABLE_ADDR + 6
JMP_RUN:                = JUMP_TABLE_ADDR + 9
JMP_RESET:              = JUMP_TABLE_ADDR + 12
JMP_PUTC:               = JUMP_TABLE_ADDR + 15
JMP_PRINT_HEX:          = JUMP_TABLE_ADDR + 18
JMP_XMODEM_RCV:         = JUMP_TABLE_ADDR + 21
JMP_GETC:               = JUMP_TABLE_ADDR + 24
JMP_INIT_KB:            = JUMP_TABLE_ADDR + 27
JMP_LINE_INPUT:         = JUMP_TABLE_ADDR + 30
JMP_IRQ_HANDLER:        = JUMP_TABLE_ADDR + 33
JMP_NMI_HANDLER:        = JUMP_TABLE_ADDR + 36
JMP_INIT_SERIAL:        = JUMP_TABLE_ADDR + 39
JMP_CURSOR_ON:          = JUMP_TABLE_ADDR + 42
JMP_CURSOR_OFF:         = JUMP_TABLE_ADDR + 45
JMP_DRAW_PIXEL:         = JUMP_TABLE_ADDR + 48
JMP_RMV_PIXEL:          = JUMP_TABLE_ADDR + 51

BYTE_OUT                = $40             ; address used for shifting bytes
BYTE_IN                 = $41             ; address used to shift reveived bits into
LAST_ACK_BIT            = $42
ARGS                    = $43             ; 6 bytes

DEVICE_BLOCK            = ARGS+0
DEVICE_ADDR_H           = ARGS+1
DEVICE_ADDR_L           = ARGS+2
LOCAL_ADDR_L            = ARGS+3
LOCAL_ADDR_H            = ARGS+4
READ_LENGTH             = ARGS+5

PORTA                   = $6001           ; Data port A
PORTA_DDR               = $6003           ; Data direction of port A

DATA_PIN                = %01            
CLOCK_PIN               = %10

EEPROM_CMD              = %10100000
WRITE_MODE              = 0
READ_MODE               = 1


DATA_STACK_PTR          = $3f
; data stack
DATA_STACK_START        = $90



                .org $2000

init:           lda     #DATA_STACK_START
                sta     DATA_STACK_PTR



start:
                jsr     init_storage
                ; lda     #"!"
                ; sta     $1000

                ;   - ARGS+0: Block / device address. Three bits: 00000BDD
                lda     #%00000100
                sta     ARGS+0
                ;   - ARGS+1: High byte of target address on the EEPROM
                lda     #%00000000
                sta     ARGS+1
                ;   - ARGS+2: Low byte of target address on the EEPROM
                lda     #%00000000
                sta     ARGS+2
                ;   - ARGS+3: Low byte of vector pointing to first byte to transmit
                lda     #<$1000
                sta     ARGS+3
                ;   - ARGS+4: High byte of vector pointing to first byte to transmit
                lda     #>$1000
                sta     ARGS+4
                ;   - ARGS+5: Number of bytes to write (max: 128)
                lda     #128
                sta     ARGS+5

                ; jsr     write_sequence

                jsr     read_sequence

                lda     $1000
                jsr     JMP_PUTC
                rts


init_storage:
                lda     PORTA_DDR
                ora     #(DATA_PIN | CLOCK_PIN)
                sta     PORTA_DDR

                rts


;=================================================================================
;               ROUTINES
;=================================================================================

;=================================================================================
; Write a sequence of bytes to the EEPROM
; Args:
;   - ARGS+0: Block / device address. Three bits: 00000BDD
;   - ARGS+1: High byte of target address on the EEPROM
;   - ARGS+2: Low byte of target address on the EEPROM
;   - ARGS+3: Low byte of vector pointing to first byte to transmit
;   - ARGS+4: High byte of vector pointing to first byte to transmit
;   - ARGS+5: Number of bytes to write (max: 128)
write_sequence:
                jsr     _init_sequence
                ldy     #0              ; start at 0
.byte_loop:
                lda     (LOCAL_ADDR_L),y
                jsr     transmit_byte
                iny
                cpy     READ_LENGTH            ; compare with string lengths in TMP1
                bne     .byte_loop
                jsr     _stop_condition

                ; wait for write sequence to be completely written to EEPROM.
                ; This isn't always needed, but it's safer to do so, and doesn't
                ; waste much time.
ack_loop:
                jsr     _start_condition
                lda     #(EEPROM_CMD | WRITE_MODE)
                ora     ARGS
                jsr     transmit_byte   ; send command to EEPROM
                lda     LAST_ACK_BIT
                bne     ack_loop
                rts
;=================================================================================
; Read a sequence of bytes from the EEPROM
; Args:
;   - ARGS+0: Block / device address. Three bits: 00000BDD
;   - ARGS+1: High byte of target address on the EEPROM
;   - ARGS+2: Low byte of target address on the EEPROM
;   - ARGS+3: Low byte of vector pointing to where to write the first byte
;   - ARGS+4: High byte of vector pointing to where to write the first byte
;   - ARGS+5: Number of bytes to read
.scope
read_sequence:
                phx
                jsr     _init_sequence

                ; Now that the address is set, start read mode
                jsr     _start_condition

                ; send block / device / read mode (same as used to write the address)
                lda     #(EEPROM_CMD | READ_MODE)
                ora     ARGS
                jsr     transmit_byte   ; send command to EEPROM

                ldy     #0              ; byte counter, counts up to length in ARGS+5
.byte_loop:
                jsr     _data_in
                ldx     #8              ; bit counter, counts down to 0
.bit_loop:
                jsr     _clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr                     ; shift the reveived bit onto the carry flag
                rol     BYTE_IN         ; shift the received bit into the the received byte
                jsr     _clock_low
                
                dex
                bne     .bit_loop       ; keep going until all 8 bits are shifted in

                lda     BYTE_IN
                sta     (LOCAL_ADDR_L),y      ; store the byte following the provided vector

                iny
                cpy     READ_LENGTH
                beq     .done           ; no ack for last byte, as per the datasheet

                ; ack the reception of the byte
                jsr     _data_out        ; set the data line as output so we can ackknowledge

                lda     PORTA
                and     #(DATA_PIN^$FF)  ; set data line low to ack
                sta     PORTA

                jsr     _clock_high      ; strobe it into the EEPROM
                jsr     _clock_low

                jmp     .byte_loop
.done:
                jsr     _data_out

                jsr     _stop_condition
                plx
                rts
.scend
;=================================================================================
;               PRIVATE ROUTINES
;=================================================================================

;=================================================================================
; This initializes a read or write sequence by generating the start condition,
; selecting the correct block and device by sending the command to the EEPROM,
; and setting the internal address pointer to the selected address.
;
; Args (sent to read_sequence or write_sequence):
;   - ARGS+0: Block / device address. Three bits: 00000BDD
;   - ARGS+1: High byte of target address on the EEPROM
;   - ARGS+2: Low byte of target address on the EEPROM
_init_sequence:
                ; send start condition
                jsr     _start_condition
                ; send block / device / write mode
                lda     ARGS            ; block / device
                asl                     
                sta     ARGS
                lda     #(EEPROM_CMD | WRITE_MODE)
                ora     ARGS
                jsr     transmit_byte   ; send command to EEPROM

                ; set high and low bytes of the target address
                lda     DEVICE_ADDR_H
                jsr     transmit_byte
                lda     DEVICE_ADDR_L
                jsr     transmit_byte
                rts
;=================================================================================
; Send the start condition to the EEPROM
_start_condition:
                ; 1. DEACTIVATE BUS
                lda     PORTA
                ora     #(DATA_PIN | CLOCK_PIN)      ; clock and data high
                sta     PORTA
                ; 2. START CONDITION
                and     #(DATA_PIN^$FF)     ; clock stays high, data goes low
                sta     PORTA
                and     #(CLOCK_PIN^$FF)     ; then pull clock low
                sta     PORTA
                rts

;=================================================================================
; Send the stop condition to the EEPROM
_stop_condition:
                lda     PORTA
                and     #(DATA_PIN^$FF)  ; data low
                sta     PORTA
                jsr     _clock_high      ; clock high
                lda     PORTA               ; TODO: can I get rid of this?
                ora     #DATA_PIN        ; data high
                sta     PORTA
                rts

;=================================================================================
; Set the data line as input
_data_in:
                lda     PORTA_DDR
                and     #(DATA_PIN^$FF)      ; set data line back to input
                sta     PORTA_DDR
                rts

;=================================================================================
; Set the data line as input
_data_out:
                lda     PORTA_DDR
                ora     #DATA_PIN       ; set data line to output
                sta     PORTA_DDR
                rts

;=================================================================================
; Transmit one byte to the EEPROM
; Args:
;   - A: the byte to transmit
.scope
transmit_byte:
                pha
                phy
                sta     BYTE_OUT
                ldy     #8
.transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     BYTE_OUT        ; shift next bit into carry
                lda     PORTA
                bcc     .send_zero

                ; send one
                ora     #DATA_PIN
                jmp     .continue
.send_zero:
                and     #(DATA_PIN^$FF)
.continue:
                and     #(CLOCK_PIN^$FF); make sure clock is low when placing the bit on the bus
                sta     PORTA

                jsr     _clock_high     ; toggle clock to strobe it into the eeprom
                jsr     _clock_low

                dey
                bne     .transmit_loop

                ; After each byte, the EEPROM expects a clock cycle during which 
                ; it pulls the data line low to signal that the byte was received
                jsr     _data_in
                jsr     _clock_high
                lda     PORTA
                and     #DATA_PIN       ; only save last bit
                sta     LAST_ACK_BIT
                jsr     _clock_low
                jsr     _data_out
                ply
                pla
                rts
.scend
;=================================================================================
; Toggle clock high
_clock_high:    ; toggle clock from high to low to strobe the bit into the eeprom
                lda     PORTA
                ora     #CLOCK_PIN      ; clock high
                sta     PORTA
                rts

;=================================================================================
; Toggle clock low
_clock_low:         
                lda     PORTA       
                and     #(CLOCK_PIN^$FF)  ; clock low
                sta     PORTA
                rts


push:           inc     DATA_STACK_PTR
                sta     (DATA_STACK_PTR)
                rts

pop:           lda     DATA_STACK_PTR
                cmp     #DATA_STACK_START
                beq     .underflow
                clc
                lda     (DATA_STACK_PTR)
                dec     DATA_STACK_PTR
                rts
.underflow:     sec
                lda     #0
                rts
