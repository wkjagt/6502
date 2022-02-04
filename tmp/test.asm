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
JMP_INIT_STORAGE:       = JUMP_TABLE_ADDR + 54
JMP_STOR_READ:          = JUMP_TABLE_ADDR + 57
JMP_STOR_WRITE:         = JUMP_TABLE_ADDR + 60

BYTE_OUT                = $50             ; address used for shifting bytes
BYTE_IN                 = $51             ; address used to shift reveived bits into
LAST_ACK_BIT            = $52
ARGS                    = $40             ; 6 bytes

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



                .org $2000


; fill 4 pages with known bytes
                ldx #0
.store_loop:    txa
                sta     $1000,x
                sta     $1100,x
                sta     $1200,x
                sta     $1300,x
                inx
                bne     .store_loop



; write these 4 pages to EEPROM
                ldx     #$30
                lda     #0              ; block number
                sta     0,x
                sta     1,x

                sta     2,x             ; local address (low)
                lda     #$10
                sta     3,x             ; local address (high)

                jsr      write_forth_block

; clear the 4 pages
                ldx     #0
.clear_loop:    lda     #0
                sta     $1000,x
                sta     $1100,x
                sta     $1200,x
                sta     $1300,x
                inx
                bne     .clear_loop

; read the values back from the EEPROM
                ldx     #$30
                lda     #0              ; block number
                sta     0,x
                sta     1,x

                sta     2,x             ; local address (low)
                lda     #$10
                sta     3,x             ; local address (high)

                jsr      read_forth_block

                rts


read_forth_block:
                pha
                phy
                lda     0,x
                sta     DEVICE_ADDR_H   ; the argument for the high byte of the target address
                inx                     ; point to the next 16 bit value on the stack
                inx
;               2. Initialize argument for block/device with 0.
                stz     DEVICE_BLOCK
;               3. Shift Forth block id left. Carry now contains the device id and the Forth
;                  block id argument now contains the high byte of the target address.
                asl     DEVICE_ADDR_H
;               4. Rotate right into the block/device argument (shift right because device
;                  id is the right most bit in the argument because of the bit order in
;                  the byte sent to the physical device)
                ror     DEVICE_BLOCK
;               5. Shift right because we need a 0 in between the device id
;                  and the device block id.
                lsr     DEVICE_BLOCK
;               6. Shift Forth block id left. Carry now contains the device block id.
                asl     DEVICE_ADDR_H
;               7. Rotate right into the block/device argument. This argument now looks
;                  like B0D0.0000.
                ror     DEVICE_BLOCK
;               8. Shift right five times to have 0000.0B0D so this argument now contains
;                  the right value for the device block and id.
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
;               9. Since we only start writing at the start of a device block page,
;                  the low byte of the target address is always 0
                stz     DEVICE_ADDR_L
;               10. Set the start address of where to start reading from RAM. This is stored
;                   in the next position of the data stack.
                lda     0,x
                sta     LOCAL_ADDR_L   ; Low byte
                inx
                lda     0,x
                sta     LOCAL_ADDR_H   ; High byte
                inx
                phx                    ; preserve the x register so we don't break the data
                                       ; stack pointer
;               11. Since we're always reading 128 byte sequences, length can be hardcoded
                lda     #128
                sta     READ_LENGTH

;               12. Initialize a counter because we need to write in 8 128 byte sequences.
                ldx     #8
.next_128_bytes:
;               13. Everything is now set up to write the first 128 bytes to the device
                jsr     read_sequence

;               14. Point to the start of the next 128 bytes in RAM
                clc
                lda     LOCAL_ADDR_L
                adc     #128
                sta     LOCAL_ADDR_L
                lda     LOCAL_ADDR_H
                adc     #0
                sta     LOCAL_ADDR_H

;               15. Point to the start of the next 128 bytes in the device.
                clc
                lda     DEVICE_ADDR_L
                adc     #128
                sta     DEVICE_ADDR_L
                lda     DEVICE_ADDR_H
                adc     #0
                sta     DEVICE_ADDR_H

                dex
                bne     .next_128_bytes

                plx                                 ; restore data stack pointer
                ply
                pla
                rts

write_forth_block:
                pha
                phy

                lda     0,x
                sta     DEVICE_ADDR_H   ; the argument for the high byte of the target address
                inx                     ; point to the next 16 bit value on the stack
                inx
;               2. Initialize argument for block/device with 0.
                stz     DEVICE_BLOCK
;               3. Shift Forth block id left. Carry now contains the device id and the Forth
;                  block id argument now contains the high byte of the target address.
                asl     DEVICE_ADDR_H
;               4. Rotate right into the block/device argument (shift right because device
;                  id is the right most bit in the argument because of the bit order in
;                  the byte sent to the physical device)
                ror     DEVICE_BLOCK
;               5. Shift right because we need a 0 in between the device id
;                  and the device block id.
                lsr     DEVICE_BLOCK
;               6. Shift Forth block id left. Carry now contains the device block id.
                asl     DEVICE_ADDR_H
;               7. Rotate right into the block/device argument. This argument now looks
;                  like B0D0.0000.
                ror     DEVICE_BLOCK
;               8. Shift right five times to have 0000.0B0D so this argument now contains
;                  the right value for the device block and id.
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
                lsr     DEVICE_BLOCK
;               9. Since we only start writing at the start of a device block page,
;                  the low byte of the target address is always 0
                stz     DEVICE_ADDR_L
;               10. Set the start address of where to start reading from RAM. This is stored
;                   in the next position of the data stack.
                lda     0,x
                sta     LOCAL_ADDR_L   ; Low byte
                inx
                lda     0,x
                sta     LOCAL_ADDR_H   ; High byte
                inx
                phx                    ; preserve the x register so we don't break the data
                                       ; stack pointer
;               11. Since we're always reading 128 byte sequences, length can be hardcoded
                lda     #128
                sta     READ_LENGTH

;               12. Initialize a counter because we need to write in 8 128 byte sequences.
                ldx     #8
.next_128_bytes:
;               13. Everything is now set up to write the first 128 bytes to the device
                jsr     write_sequence

;               14. Point to the start of the next 128 bytes in RAM
                clc
                lda     LOCAL_ADDR_L
                adc     #128
                sta     LOCAL_ADDR_L
                lda     LOCAL_ADDR_H
                adc     #0
                sta     LOCAL_ADDR_H

;               15. Point to the start of the next 128 bytes in the device.
                clc
                lda     DEVICE_ADDR_L
                adc     #128
                sta     DEVICE_ADDR_L
                lda     DEVICE_ADDR_H
                adc     #0
                sta     DEVICE_ADDR_H

                dex
                bne     .next_128_bytes

                plx                                 ; restore data stack pointer
                ply
                pla
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
                beq     _done           ; no ack for last byte, as per the datasheet

                ; ack the reception of the byte
                jsr     _data_out        ; set the data line as output so we can ackknowledge

                lda     PORTA
                and     #(DATA_PIN^$FF)  ; set data line low to ack
                sta     PORTA

                jsr     _clock_high      ; strobe it into the EEPROM
                jsr     _clock_low

                jmp     .byte_loop
_done:
                jsr     _data_out

                jsr     _stop_condition
                plx
                rts
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
transmit_byte:
                pha
                phy
                sta     BYTE_OUT
                ldy     #8
_transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     BYTE_OUT        ; shift next bit into carry
                lda     PORTA
                bcc     _send_zero

                ; send one
                ora     #DATA_PIN
                jmp     _continue
_send_zero:
                and     #(DATA_PIN^$FF)
_continue:
                and     #(CLOCK_PIN^$FF); make sure clock is low when placing the bit on the bus
                sta     PORTA

                jsr     _clock_high     ; toggle clock to strobe it into the eeprom
                jsr     _clock_low

                dey
                bne     _transmit_loop

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