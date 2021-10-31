; SAVE "HELLO WORLD" TO EEPROM AND READ IT BACK

BYTE_OUT        =       $00             ; address used for shifting bytes
BYTE_IN         =       $01             ; address used to shift reveived bits into
LAST_ACK_BIT    =       $06
ARGS            =       $07             ; 6 bytes

DEVICE_BLOCK    =       ARGS+0
DEVICE_ADDR_H   =       ARGS+1
DEVICE_ADDR_L   =       ARGS+2
LOCAL_ADDR_L    =       ARGS+3
LOCAL_ADDR_H    =       ARGS+4
READ_LENGTH     =       ARGS+5

SER_DATA        =       $4800           ; Data register
SER_ST          =       $4801           ; Status register
SER_CMD         =       $4802           ; Command register
SER_CTL         =       $4803           ; Control register
SER_RXFL        =       %00001000       ; Serial Receive full bit
PORTA           =       $6001           ; Data port A
PORTA_DDR       =       $6003           ; Data direction of port A

DATA_PIN        =       %01            
CLOCK_PIN       =       %10

EEPROM_CMD      =       %10100000
WRITE_MODE      =       0
READ_MODE       =       1

                .ORG    $0700

; ========================= INITIALIZE ===========================
                sei                     ; Disable interrupts
                lda     #$0a            ; new line for debugging
                jsr     write_to_terminal

                ; set pins 0 and 1 to outputs
                lda     PORTA_DDR
                ora     #(DATA_PIN | CLOCK_PIN)
                sta     PORTA_DDR
                ; rts

                ; fill 4 pages in RAM to test
                lda     #"a"
                ldx     #0
.loop_a
                sta     $0a00, x
                inx
                bne     .loop_a

                lda     #"b"
                ldx     #0
.loop_b
                sta     $0b00, x
                inx
                bne     .loop_b

                lda     #"c"
                ldx     #0
.loop_c
                sta     $0c00, x
                inx
                bne     .loop_c

                lda     #"d"
                ldx     #0
.loop_d
                sta     $0d00, x
                inx
                bne     .loop_d

                ; jmp     test_read_sequence
;====================================================================================
;
;               TEST: COPY 1024 BYTES FROM SPECIFIC START ADDRESS
;               IN RAM TO SPECIFIC START ADDRESS IN EEPROM
;
;               A Forth block is 4 pages long (1024k). Each EEPROM block is 64k long
;               and can store 64 Forth blocks. We have 4 EEPROM blocks, so we can store
;               a maximum of 256 Forth blocks. Each of the 256 Forth block numbers
;               results in one of 4 EEPROM block / device possibilities and one of 64
;               possible starting addresses on the EEPROM. This translates to:
;
;               block/device:           2 bits
;               start address in block: 6 bits
;              
;               To align all the Forth blocks one after the other in the EEPROM, Forth
;               block numbers translate to EEPROM device / block ids as follows:
;               
;               Forth block#                                Device#     Device block
;               000-063 (00-3F / 0000.0000 - 0011.1111)     0           0
;               064-127 (40-7f / 0100.0000 - 0111.1111)     0           1
;               128-191 (80-BF / 1000.0000 - 1011.1111)     1           0
;               192-256 (C0-FF / 1100.0000 - 1111.1111)     1           1
;
;               This makes an easy translation possible because we can use bit 7 from
;               the Forth block number as the EEPROM device id, and bit 6 from the Forth
;               block number as device block id.
;
;               To get the starting address within a device block, we take the Forth
;               block number, and shift it left twice. This removes the left two bits
;               which were used to select the device and device block, and results in
;               the high byte of the address within the device block. Ie:
;               
;               Block 0000.0011 (3) shifted left twice gives high byte 0000.1100 (C)
;               for starting address in device 0 and device block 0.
;
;               This is achieved through the following steps:
;               1. Store the Forth block number in the argument for the high byte of
;                  the target address.
                lda     #6              ; 6 here is just an example Forth block number
                sta     DEVICE_ADDR_H   ; the argument for the high byte of the target address
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
;               10. Set the start address of where to start reading from RAM.
                stz     LOCAL_ADDR_L   ; Low byte, testing for now. TODO: load from stack
                lda     #$a
                sta     LOCAL_ADDR_H   ; High byte, testing for now. TODO: load from stack
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

                rts

;====================================================================================
;                TEST: CALL WRITE SEQUENCE ROUTINE 
;                           -----
;====================================================================================

;                 ; arg: block / device
;                 lda     #%101           ; BDD
;                 sta     DEVICE_BLOCK
;                 ; arg: target high address
;                 lda     #0              ; target address high byte
;                 sta     DEVICE_ADDR_H
;                 ; arg: target low address
;                 lda     #0              ; target address low byte
;                 sta     DEVICE_ADDR_L

;                 ; arg: address of start of string
;                 lda     #<text          ; low byte of address of first byte
;                 sta     LOCAL_ADDR_L
;                 lda     #>text          ; high byte of address of first byte
;                 sta     LOCAL_ADDR_H          

;                 ; arg: string length
;                 lda     #10             ; number of bytes to write
;                 sta     READ_LENGTH

;                 jsr     write_sequence
;                 rts
; text:
;                 .asciiz "DEVICE 1!"


;====================================================================================
;                TEST: CALL READ SEQUENCE ROUTINE 
;                           ----
;====================================================================================
; test_read_sequence
;                 lda     #%000           ; BDD
;                 sta     DEVICE_BLOCK
;                 ; arg: target high address
;                 lda     #26              ; target address high byte
;                 sta     DEVICE_ADDR_H
;                 ; arg: target low address
;                 lda     #0              ; target address low byte
;                 sta     DEVICE_ADDR_L

;                 ; arg: address to write string to
;                 lda     #0              ; low byte of address of first byte
;                 sta     LOCAL_ADDR_L
;                 lda     #2              ; high byte of address of first byte
;                 sta     LOCAL_ADDR_H          

;                 ; arg: string length
;                 lda     #10             ; number of bytes to read
;                 sta     READ_LENGTH

;                 jsr     read_sequence
;                 ldy     #0
; .loop:
;                 lda     (LOCAL_ADDR_L),y
;                 jsr     write_to_terminal
;                 iny
;                 cpy     READ_LENGTH
;                 bne     .loop

;                 rts

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
                jsr     write_to_terminal
                jsr     _transmit_byte
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
                jsr     _transmit_byte   ; send command to EEPROM
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
                jsr     _transmit_byte   ; send command to EEPROM

                ldy     #0              ; byte counter, counts up to length in ARGS+5
.byte_loop:
                jsr     _data_in
                ldx     #8              ; bit counter, counts down to 0
.bit_loop:
                jsr     _clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr     A               ; shift the reveived bit onto the carry flag
                rol     BYTE_IN         ; shift the received bit into the the received byte
                jsr     _clock_low
                
                dex
                bne     .bit_loop       ; keep going until all 8 bits are shifted in

                lda     BYTE_IN
                sta     (LOCAL_ADDR_L),y      ; store the byte following the provided vector
                jsr     write_to_terminal

                iny
                cpy     READ_LENGTH
                beq     .done           ; no ack for last byte, as per the datasheet

                ; ack the reception of the byte
                jsr     _data_out        ; set the data line as output so we can ackknowledge

                lda     PORTA
                and     #~DATA_PIN      ; set data line low to ack
                sta     PORTA

                jsr     _clock_high      ; strobe it into the EEPROM
                jsr     _clock_low

                jmp     .byte_loop
.done:
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
                jsr     _transmit_byte   ; send command to EEPROM

                ; set high and low bytes of the target address
                lda     DEVICE_ADDR_H
                jsr     _transmit_byte
                lda     DEVICE_ADDR_L
                jsr     _transmit_byte
                rts
;=================================================================================
; Send the start condition to the EEPROM
_start_condition:
                ; 1. DEACTIVATE BUS
                lda     PORTA
                ora     #(DATA_PIN | CLOCK_PIN)      ; clock and data high
                sta     PORTA
                ; 2. START CONDITION
                and     #~DATA_PIN      ; clock stays high, data goes low
                sta     PORTA
                and     #~CLOCK_PIN     ; then pull clock low
                sta     PORTA
                rts

;=================================================================================
; Send the stop condition to the EEPROM
_stop_condition:
                lda     PORTA
                and     #~DATA_PIN      ; data low
                sta     PORTA
                jsr     _clock_high      ; clock high
                lda     PORTA
                ora     #DATA_PIN       ; data high
                sta     PORTA
                rts

;=================================================================================
; Set the data line as input
_data_in:
                lda     PORTA_DDR
                and     #~DATA_PIN      ; set data line back to input
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
_transmit_byte:
                pha
                phy
                sta     BYTE_OUT
                ldy     #8
.transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     BYTE_OUT        ; shift next bit into carry
                rol     A               ; shift carry into bit 0 of A
                and     #~CLOCK_PIN     ; make sure clock is low when placing the bit on the bus
                sta     PORTA
                jsr     _clock_high      ; toggle clock to strobe it into the eeprom
                jsr     _clock_low

                dey
                bne     .transmit_loop

                ; After each byte, the EEPROM expects a clock cycle during which 
                ; it pulls the data line low to signal that the byte was received
                lda     PORTA_DDR
                and     #~DATA_PIN      ; set data line as input to receive ack
                sta     PORTA_DDR
                jsr     _clock_high
                lda     PORTA
                and     #DATA_PIN       ; only save last bit
                sta     LAST_ACK_BIT
                jsr     _clock_low
                lda     PORTA_DDR
                ora     #DATA_PIN       ; set data line back to output
                sta     PORTA_DDR
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
                and     #~CLOCK_PIN     ; clock low
                sta     PORTA
                rts

;=================================================================================
; Write to terminal (for debugging)
write_to_terminal:
                PHY
                LDY #$ff
delay:
                DEY
                BNE delay
                STA SER_DATA
                PLY
                RTS
