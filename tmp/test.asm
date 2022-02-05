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
CURRENT_DRIVE           = $53
ARGS                    = $40             ; 6 bytes

EEPROM_BLOCK            = ARGS+0
EEPROM_PAGE             = ARGS+1
EEPROM_ADDR_L           = ARGS+2
RAM_ADDR_L              = ARGS+3
RAM_ADDR_H              = ARGS+4

PORTA                   = $6001           ; Data port A
PORTA_DDR               = $6003           ; Data direction of port A

DATA_PIN                = %01            
CLOCK_PIN               = %10

EEPROM_CMD              = %10100000
WRITE_MODE              = 0
READ_MODE               = 1

LOAD_ADDRESS            = $1000

                .org $2000


                lda     #0
                sta     CURRENT_DRIVE

; fill 4 pages with known bytes
                ldx     #0
.store_loop:    txa
                sta     $1000,x
                sta     $1100,x
                sta     $1200,x
                sta     $1300,x
                inx
                bne     .store_loop

; write the 4 pages to EEPROM
                ldx     #4              ; number of pages
                stz     EEPROM_PAGE
                jsr     write_pages

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
                ldx     #4              ; number of pages
                stz     EEPROM_PAGE
                jsr     read_pages

                rts

;=================================================================================
;               ROUTINES
;=================================================================================
read_pages:     pha
                phy
                phx
                
                ldx     CURRENT_DRIVE
                lda     drive_to_eeprom_block, x
                sta     EEPROM_BLOCK
                
                plx                     ;page count
                lda     #>LOAD_ADDRESS
                sta     RAM_ADDR_H

.next_page:     stz     RAM_ADDR_L
                stz     EEPROM_ADDR_L
                jsr     read_sequence

                lda     #128
                sta     RAM_ADDR_L
                sta     EEPROM_ADDR_L
                jsr     read_sequence

                inc     RAM_ADDR_H
                inc     EEPROM_PAGE
                dex
                bne     .next_page

                ply
                pla
                rts


write_pages:    pha
                phy
                phx
                
                ldx     CURRENT_DRIVE
                lda     drive_to_eeprom_block, x
                sta     EEPROM_BLOCK
                
                plx                     ;page count
                lda     #>LOAD_ADDRESS
                sta     RAM_ADDR_H

.next_page:     stz     RAM_ADDR_L
                stz     EEPROM_ADDR_L
                jsr     write_sequence

                lda     #128
                sta     RAM_ADDR_L
                sta     EEPROM_ADDR_L
                jsr     write_sequence

                inc     RAM_ADDR_H
                inc     EEPROM_PAGE
                dex
                bne     .next_page

                ply
                pla
                rts

;=================================================================================
;               PRIVATE ROUTINES
;=================================================================================

;=================================================================================
; Write a sequence of bytes to the EEPROM
write_sequence: jsr     _init_sequence
                ldy     #0              ; start at 0
.byte_loop:     lda     (RAM_ADDR_L),y
                jsr     transmit_byte
                iny
                cpy     #128            ; compare with string lengths in TMP1
                bne     .byte_loop
                jsr     _stop_cond

.ack_loop:      jsr     _init_write
                bcs     .ack_loop
                rts
;=================================================================================
; Read a sequence of bytes from the EEPROM
read_sequence:  phx
                jsr     _init_sequence
                jsr     _init_read

                ldy     #0
.byte_loop:     jsr     _data_in
                ldx     #8              ; bit counter, counts down to 0
.bit_loop:      jsr     _clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr                     ; shift the reveived bit onto the carry flag
                rol     BYTE_IN         ; shift the received bit into the the received byte
                jsr     _clock_low
                
                dex
                bne     .bit_loop       ; keep going until all 8 bits are shifted in

                lda     BYTE_IN
                sta     (RAM_ADDR_L),y      ; store the byte

                iny
                cpy     #128
                beq     .done           ; no ack for last byte, as per the datasheet

                ; ack the reception of the byte
                jsr     _data_out        ; set the data line as output so we can ackknowledge

                lda     PORTA
                and     #(DATA_PIN^$FF)  ; set data line low to ack
                sta     PORTA

                jsr     _clock_high      ; strobe it into the EEPROM
                jsr     _clock_low

                jmp     .byte_loop
.done:          jsr     _data_out

                jsr     _stop_cond
                plx
                rts

;=================================================================================
; An init sequence starts a write mode and sets the address. This is also used
; when we want to read, in which case _init_read is called after this, which sets
; the EEPROM to read mode, starting the read at the address provided.
_init_sequence: jsr     _init_write
                lda     EEPROM_PAGE
                jsr     transmit_byte
                lda     EEPROM_ADDR_L
                jsr     transmit_byte
                rts

;=================================================================================
; Set read mode
_init_read:     jsr     _start_cond
                lda     EEPROM_BLOCK            ; block / device
                asl                     
                ora     #(EEPROM_CMD | READ_MODE)
                jsr     transmit_byte   ; send command to EEPROM
                rts
 ;=================================================================================
; Set write mode               
_init_write:    jsr     _start_cond
                lda     EEPROM_BLOCK            ; block / device
                asl                     
                ora     #(EEPROM_CMD | WRITE_MODE)
                jsr     transmit_byte   ; send command to EEPROM
                rts

;=================================================================================
; Send the start condition to the EEPROM
_start_cond     ; 1. DEACTIVATE BUS
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
_stop_cond:     lda     PORTA
                and     #(DATA_PIN^$FF)  ; data low
                sta     PORTA
                jsr     _clock_high      ; clock high
                lda     PORTA               ; TODO: can I get rid of this?
                ora     #DATA_PIN        ; data high
                sta     PORTA
                rts

;=================================================================================
; Set the data line as input
_data_in:       lda     PORTA_DDR
                and     #(DATA_PIN^$FF)      ; set data line back to input
                sta     PORTA_DDR
                rts

;=================================================================================
; Set the data line as input
_data_out:      lda     PORTA_DDR
                ora     #DATA_PIN       ; set data line to output
                sta     PORTA_DDR
                rts

;=================================================================================
; Transmit one byte to the EEPROM
; Args:
;   - A: the byte to transmit
transmit_byte:  pha
                phy
                sta     BYTE_OUT
                ldy     #8
_transmit_loop: ; Set next byte on bus while clock is still low
                asl     BYTE_OUT        ; shift next bit into carry
                lda     PORTA
                bcc     _send_zero

                ; send one
                ora     #DATA_PIN
                jmp     _continue
_send_zero:     and     #(DATA_PIN^$FF)
_continue:      and     #(CLOCK_PIN^$FF); make sure clock is low when placing the bit on the bus
                sta     PORTA

                jsr     _clock_high     ; toggle clock to strobe it into the eeprom
                jsr     _clock_low

                dey
                bne     _transmit_loop

                ; After each byte, the EEPROM expects a clock cycle during which 
                ; it pulls the data line low to signal that the byte was received
                jsr     _data_in
                jsr     _clock_high
                lsr     PORTA           ; put ack bit in Carry
                jsr     _clock_low
                jsr     _data_out
                ply
                pla
                rts
;=================================================================================
; Toggle clock high
_clock_high:    lda     PORTA
                ora     #CLOCK_PIN      ; clock high
                sta     PORTA
                rts

;=================================================================================
; Toggle clock low
_clock_low:     lda     PORTA       
                and     #(CLOCK_PIN^$FF)  ; clock low
                sta     PORTA
                rts


; 2, 3, 7, 8 are not used because there are no EEPROMS connected with A1 high
drive_to_eeprom_block:
                .byte   0, 1, 4, 5