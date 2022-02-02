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

tmp1                    = $40             ; address used for shifting bytes
tmp2                    = $42             ; address used to shift reveived bits into
tmp3                    = $44

stor_target_block       = $46          ; ARGS0
stor_target_addr:       = $48          ; ARGS1/2 (H/L)
stor_src_addr:          = $4a          ; ARGS3/4 (L/H) 
stor_byte_cnt:          = $4c          ; ARGS5

PORTA                   = $6001           ; Data port A
PORTA_DDR               = $6003           ; Data direction of port A

DATA_PIN                = %01            
CLOCK_PIN               = %10

EEPROM_CMD              = %10100000
WRITE_MODE              = 0
READ_MODE               = 1

CURRENT_DRIVE           = $40
LOAD_ADDRESS            = $1000

                .org $2000

start:          lda     #0
                sta     CURRENT_DRIVE

                ldx     #1              ; number of pages
                lda     #0              ; start page on EEPROM

                jsr     read_pages

                rts


;=================================================================================
;               ROUTINES
;=================================================================================

;=================================================================================
; Write a sequence of bytes to the EEPROM
write_sequence:
                jsr     _init_sequence
                ldy     #0              ; start at 0
.byte_loop:
                lda     (stor_src_addr),y
                jsr     transmit_byte
                iny
                cpy     stor_byte_cnt            ; compare with string lengths in TMP1
                bne     .byte_loop
                jsr     _stop_condition

                ; wait for write sequence to be completely written to EEPROM.
                ; This isn't always needed, but it's safer to do so, and doesn't
                ; waste much time.
ack_loop:
                jsr     _start_condition
                lda     #(EEPROM_CMD | WRITE_MODE)
                ora     stor_target_block
                jsr     transmit_byte   ; send command to EEPROM
                lda     tmp3
                bne     ack_loop
                rts

; The main routine to read multiple pages from EEPROM to RAM
; Arguments:
; X: number of pages to read
; A: start page in EEPROM
read_pages:     ldy     #>LOAD_ADDRESS  ; start page in RAM
.page_loop:     clc                     ; read BOTTOM 128 bytes
                jsr     read_packet
                sec                     ; read TOP 128 bytes
                jsr     read_packet
                ina                     ; next page in EEPROM
                iny                     ; next page in RAM
                dex                     ; x was passed as an arg
                bne     .page_loop
                rts

; A: EEPROM page
; Y: RAM page
; C: BOTTOM/TOP 128 bytes 
read_packet:    pha
                phx
                phy

                ; set up RAM address beofore carry flag is overwritten
                sty     tmp2+1          ; high RAM byte (page)
                stz     tmp2            
                ror     tmp2            ; low byte. 0 if carry clear, 128 if carry set

                ; pha
                ; lda     tmp2+1
                ; jsr     JMP_PRINT_HEX
                ; pla

                ; this includes setting up EEPROM start address
                jsr     _init_sequence
                jsr     _read_mode

                ldy     #0                      ; byte counter, counts up to 128 bytes (max for this eeprom)
.byte_loop:     jsr     _data_in
                jsr     _receive_byte           ; loads the next byte into A


                sta     (tmp2),y                ; store the byte following the provided vector
                iny
                cpy     #128                    ; see if we've reached 128 bytes yet
                beq     .done                   ; no ack for last byte, as per the datasheet

                ; ---- ack the reception of the byte
                jsr     _data_out               ; set the data line as output so we can ackknowledge
                lda     PORTA
                and     #(DATA_PIN^$FF)         ; set data line low to ack
                sta     PORTA
                jsr     _clock_high             ; strobe the ack into the EEPROM
                jsr     _clock_low
                ; ---- end of ack
                
                jmp     .byte_loop              ; next byte
.done:          jsr     _data_out

                jsr     _stop_condition
                ply
                plx
                pla
                rts

_receive_byte:  phx
                ldx     tmp2            ; also keep tmp2 "register"
                phx

                ldx     #8              ; bit counter, counts down to 0
                ; receive one bit
.bit_loop:      jsr     _clock_high
                lda     PORTA           ; the eeprom should output the next bit on the data line
                lsr                     ; shift the reveived bit onto the carry flag
                rol     tmp2            ; shift the received bit into the the received byte
                jsr     _clock_low
                
                dex
                bne     .bit_loop       ; keep going until all 8 bits are shifted in
                lda     tmp2
                plx
                stx     tmp2            ; restore tmp2 
                plx
                rts
;=================================================================================
;               PRIVATE ROUTINES
;=================================================================================

;=================================================================================
; This initializes a read or write sequence by generating the start condition,
; selecting the correct block and device by sending the command to the EEPROM,
; and setting the internal address pointer to the selected address.
_init_sequence: pha
                jsr     _write_mode

                jsr     transmit_byte   ; A = EEPROM page number
                lda     tmp2            ; shitty
                jsr     transmit_byte
                pla
                rts
;=================================================================================

_write_mode:    pha
                jsr     _start_condition
                lda     CURRENT_DRIVE
                asl                     
                ora     #(EEPROM_CMD | WRITE_MODE)
                jsr     transmit_byte   ; send command to EEPROM
                pla
                rts

_read_mode:     pha
                jsr     _start_condition
                lda     CURRENT_DRIVE
                asl                     
                ora     #(EEPROM_CMD | READ_MODE)
                jsr     transmit_byte   ; send command to EEPROM
                pla
                rts

_start_condition:
                pha
                ; 1. DEACTIVATE BUS
                lda     PORTA
                ora     #(DATA_PIN | CLOCK_PIN)      ; clock and data high
                sta     PORTA
                ; 2. START CONDITION
                and     #(DATA_PIN^$FF)     ; clock stays high, data goes low
                sta     PORTA
                and     #(CLOCK_PIN^$FF)     ; then pull clock low
                sta     PORTA
                pla
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
transmit_byte:
                pha                     ; keep a copy of A (the byte to transmit)
                phy
                sta     tmp1
                ldy     #8
.transmit_loop:
                ; Set next byte on bus while clock is still low
                asl     tmp1        ; shift next bit into carry
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
                sta     tmp3
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


; push:           inc     DATA_STACK_PTR
;                 sta     (DATA_STACK_PTR)
;                 rts

; pop:           lda     DATA_STACK_PTR
;                 cmp     #DATA_STACK_START
;                 beq     .underflow
;                 clc
;                 lda     (DATA_STACK_PTR)
;                 dec     DATA_STACK_PTR
;                 rts
; .underflow:     sec
;                 lda     #0
;                 rts
