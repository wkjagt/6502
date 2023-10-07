I2C_DATABIT             = %01            
I2C_CLOCKBIT            = %10
I2C_DDR                 = $6003     ; use port b
I2C_PORT                = $6001     ; use port b

WRITE_MODE              = 0
READ_MODE               = 1

current_drive           = $32
stor_eeprom_addr_l      = $40
stor_eeprom_addr_h      = $41
stor_byte_in            = $42
stor_byte_out           = $43
stor_ram_addr_l         = $44
stor_ram_addr_h         = $45
stor_eeprom_i2c_addr    = $47
ZP_X                    = $48
ZP_Y                    = $49
ZP_I2C_DATA             = $50

                .org $0600

                jmp     start
                .include "libi2c.asm"

                ; read 5 pages from eeprom, starting at page 5 and save to RAM starting at page 10
start:          jsr     i2c_init        ; todo udpate init code in ROM
                lda     #10             ; start at page 10
                sta     stor_ram_addr_h

                lda     #5
                sta     stor_eeprom_addr_h ; start reading from page 5 in EEPROM

                jsr     read_page
                jsr     i2c_init
                rts


;===========================================================================
; read multiple pages from EEPROM into RAM.
; Uses:
;    - current_drive:      0-3. Used to determine the i2c address
;    - x:                  numbers of pages to read from EEPROM
;    - stor_ram_addr_h:    page in RAM to start writing data to
;    - stor_eeprom_addr_h: page in EEPROM to start reading data from
;===========================================================================
read_pages:     jsr     read_page
                inc     stor_ram_addr_h         ; next RAM page
                inc     stor_eeprom_addr_h      ; next EEPROM page
                dex
                bne     read_pages
                rts

;===========================================================================
; read one pages from EEPROM into RAM.
; Uses:
;    - current_drive:      0-3. Used to determine the i2c address
;    - stor_ram_addr_h:    page in RAM write data to
;    - stor_eeprom_addr_h: page in EEPROM to read data from
;===========================================================================
read_page:      pha
                phy
                phx

                ldx     current_drive
                lda     drive_to_ic2addr, X
                sta     stor_eeprom_i2c_addr

                stz     stor_ram_addr_l
                stz     stor_eeprom_addr_l
                jsr     read_sequence

                lda     #128
                sta     stor_ram_addr_l
                sta     stor_eeprom_addr_l
                jsr     read_sequence

                plx
                ply
                pla
                rts


;===========================================================================
; write multiple pages from RAM to EEPROM.
; Uses:
;    - current_drive:      0-3. Used to determine the i2c address
;    - x:                  numbers of pages to write to EEPROM
;    - stor_ram_addr_h:    page in RAM to start reading data from
;    - stor_eeprom_addr_h: page in EEPROM to start writing data to
; TODO: adapt this routine to use write_page
;===========================================================================
write_pages:    pha
                phy
                phx

                ldx     current_drive
                lda     drive_to_ic2addr, X
                sta     stor_eeprom_i2c_addr                

                plx                     ;page count

.next_page:     stz     stor_ram_addr_l
                stz     stor_eeprom_addr_l
                jsr     write_sequence

                lda     #128
                sta     stor_ram_addr_l
                sta     stor_eeprom_addr_l
                jsr     write_sequence

                inc     stor_ram_addr_h
                inc     stor_eeprom_addr_h
                dex
                bne     .next_page

                ply
                pla
                rts

;===========================================================================
; write one page from RAM to EEPROM.
; Uses:
;    - current_drive:      0-3. Used to determine the i2c address
;    - stor_ram_addr_h:    page in RAM to start reading data from
;    - stor_eeprom_addr_h: page in EEPROM to start writing data to
;===========================================================================
write_page:     pha
                phy
                phx

                ldx     current_drive
                lda     drive_to_ic2addr, X
                sta     stor_eeprom_i2c_addr

                stz     stor_ram_addr_l
                stz     stor_eeprom_addr_l
                jsr     write_sequence

                lda     #128
                sta     stor_ram_addr_l
                sta     stor_eeprom_addr_l
                jsr     write_sequence

                plx                     ;page count
                ply
                pla
                rts

;=================================================================================
;               PRIVATE ROUTINES
;=================================================================================

;=================================================================================
; Write a sequence of bytes to the EEPROM
write_sequence: jsr     _start_cond
                lda     stor_eeprom_i2c_addr
                clc
                jsr     send_i2c_addr
                jsr     set_address
                ldy     #0              ; start at 0
.byte_loop:     lda     (stor_ram_addr_l),y
                jsr     transmit_byte
                iny
                cpy     #128            ; compare with string lengths in TMP1
                bne     .byte_loop
                jsr     _stop_cond

.ack_loop:      jsr     _start_cond
                lda     stor_eeprom_i2c_addr
                clc
                jsr     send_i2c_addr
                bcs     .ack_loop
                rts
;=================================================================================
; Read a sequence of bytes from the EEPROM
read_sequence:  phx
                jsr     _start_cond
                lda     stor_eeprom_i2c_addr
                clc                     ; write
                jsr     send_i2c_addr
                
                jsr     set_address
                jsr     _start_cond

                lda     stor_eeprom_i2c_addr
                sec                     ; read
                jsr     send_i2c_addr

                ldy     #0
.byte_loop:     jsr     _data_in
                ldx     #8              ; bit counter, counts down to 0
.bit_loop:      jsr     _clock_high
                lda     I2C_PORT           ; the eeprom should output the next bit on the data line
                lsr                     ; shift the reveived bit onto the carry flag
                rol     stor_byte_in         ; shift the received bit into the the received byte
                jsr     _clock_low
                
                dex
                bne     .bit_loop       ; keep going until all 8 bits are shifted in

                lda     stor_byte_in
                sta     (stor_ram_addr_l),y  ; store the byte

                iny
                cpy     #128
                beq     .done           ; no ack for last byte, as per the datasheet

                ; ack the reception of the byte
                jsr     _data_out       ; set the data line as output so we can ackknowledge

                ; lda     I2C_PORT
                ; and     #(I2C_DATABIT^$FF) ; set data line low to ack
                ; sta     I2C_PORT
                lda     #I2C_DATABIT
                tsb     I2C_DDR

                jsr     _clock_high     ; strobe it into the EEPROM
                jsr     _clock_low

                jmp     .byte_loop
.done:          jsr     _data_out

                jsr     _stop_cond
                plx
                rts
;=================================================================================
; 
;=================================================================================
send_i2c_addr:  rol     a
                jsr     transmit_byte   ; send command to EEPROM
                rts

;=================================================================================
; This sets the address in the EEPROM, that is then used by the read or write
; that follows. It uses the write mode, regardless if the operation that follows
; is a read or write.
;=================================================================================
set_address:    lda     stor_eeprom_addr_h
                jsr     transmit_byte
                lda     stor_eeprom_addr_l
                jsr     transmit_byte
                rts

;=================================================================================
; Send the start condition to the EEPROM
; 1. clock and data high
; 2. data transit to low
; 3. clock low
;=================================================================================
_start_cond:    
                ; 1. DEACTIVATE BUS
                ; lda     I2C_PORT
                ; ora     #(I2C_DATABIT | I2C_CLOCKBIT)      ; clock and data high
                ; sta     I2C_PORT

                ; clock and data high
                lda     #(I2C_DATABIT | I2C_CLOCKBIT)
                trb     I2C_DDR
                nop
                nop
                nop
                nop
                nop
                nop
                ; data low
                lda     #I2C_DATABIT
                tsb     I2C_DDR
                nop
                nop
                nop
                nop
                nop

                ; clock low
                lda     #I2C_CLOCKBIT
                tsb     I2C_DDR
                nop
                nop
                nop
                nop
                nop

                ; lda     #(I2C_DATABIT^$FF) ; clock stays high, data goes low
                ; sta     I2C_PORT
                ; and     #(I2C_CLOCKBIT^$FF); then pull clock low
                ; sta     I2C_PORT
                rts

;=================================================================================
; Send the stop condition to the EEPROM
_stop_cond:     ;lda     I2C_PORT
                ; and     #(I2C_DATABIT^$FF) ; data low
                ; sta     I2C_PORT
                ; jsr     _clock_high     ; clock high
                ; lda     I2C_PORT           ; TODO: can I get rid of this?
                ; ora     #I2C_DATABIT       ; data high
                ; sta     I2C_PORT
                ; rts
                lda     #I2C_DATABIT
                tsb     I2C_DDR
                jsr     _clock_high     ; clock high
                lda     #I2C_DATABIT
                trb     I2C_DDR
                rts


;=================================================================================
; Set the data line as input
_data_in:       lda     I2C_DDR
                and     #(I2C_DATABIT^$FF) ; set data line back to input
                sta     I2C_DDR
                rts

;=================================================================================
; Set the data line as input
_data_out:      lda     I2C_DDR
                ora     #I2C_DATABIT       ; set data line to output
                sta     I2C_DDR
                rts

;=================================================================================
; Transmit one byte to the EEPROM
; Args:
;   - A: the byte to transmit
transmit_byte:  pha
                phy
                sta     stor_byte_out
                ldy     #8
_transmit_loop: ; Set next byte on bus while clock is still low
                asl     stor_byte_out           ; shift next bit into carry
                lda     I2C_DDR                 ; load current data direction
                bcc     _send_zero              ; if carry clear: send 9, otherwise send 1
                and     #(I2C_DATABIT^$FF)      ; set databit to 0 in DDR (input: float up)
                jmp     _continue
_send_zero:     ora     #I2C_DATABIT            ; set databit to 1 in DDR (output: 0)
_continue:      ora     #I2C_CLOCKBIT           ; make sure clock is low when placing the bit on the bus
                sta     I2C_DDR                 ; store new value in DDR

                jsr     _clock_high             ; toggle clock to strobe it into the eeprom
                jsr     _clock_low

                dey
                bne     _transmit_loop

                ; After each byte, the EEPROM expects a clock cycle during which 
                ; it pulls the data line low to signal that the byte was received
                jsr     _data_in
                jsr     _clock_high
                lda     I2C_PORT
                lsr     a
                jsr     _clock_low
                jsr     _data_out
                ply
                pla
                rts
;=================================================================================
; Toggle clock high
_clock_high:    ; lda     I2C_PORT
                ; ora     #I2C_CLOCKBIT      ; clock high
                ; sta     I2C_PORT
                ; rts
                lda     #I2C_CLOCKBIT
                trb     I2C_DDR
                rts

;=================================================================================
; Toggle clock low
_clock_low:     ; lda     I2C_PORT       
                ; and     #(I2C_CLOCKBIT^$FF); clock low
                ; sta     I2C_PORT
                ; rts
                lda     #I2C_CLOCKBIT
                tsb     I2C_DDR
                rts


; 2, 3, 7, 8 are not used because there are no EEPROMS connected with A1 high
drive_to_eeprom_block:
                .byte   0, 1, 4, 5
drive_to_ic2addr:
                .byte   $50, $51, $54, $55

                ; .include "libi2c.asm"