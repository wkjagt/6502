; 0 = input, 1 = output
; PORT A: screen and storage
; PORT B: keyboard
IO_PORTB        =       $6000           ; Data port B
IO_PORTA        =       $6001           ; Data port A
IO_DDRB         =       $6002           ; Data direction of port B
IO_DDRA         =       $6003           ; Data direction of port A
IO_PCR          =       $600c           ; Peripheral control register
IO_IFR          =       $600d           ; Interrupt flag register
IO_IER          =       $600e           ; Interrupt enable register

SER_DATA        =       $4800           ; Data register
SER_CMD         =       $4802           ; Command register

NAK             =       $15
ACK             =       $06
EOT             =       $04
SOH             =       $01

CLEAR_SCREEN    =       $0c
CHOOSE_CURSOR   =       2               ; choose cursor command to screen
CURSOR_CHAR     =       $db             ; solid block
CURSOR_BLINK    =       3

SCRN_DATA_PINS  =       %11110000       ; In 4 bit mode: send 4 bits of data at a time
SCRN_AVAILABLE  =       %00000100       ; To tell the screen that new data is available
SCRN_ACK        =       %00001000       ; Input pin for the screen to ack the data
SCRN_OUT_PINS   =       SCRN_DATA_PINS | SCRN_AVAILABLE
SCRN_UNUSED     =       %00000011       ; unused pins on this port

; kb
KB_CHAR_IN      =       $0
KB_ACK          =       %01000000


RD_SRL_B        =       $838D

tmp1            =       $04             ; two bytes / 16 bits
tmp2            =       $06             ; two bytes / 16 bits
tmp3            =       $08             ; two bytes / 16 bits

                .ORG    $0700


screen_init:
                ; Set up data pins to communicate with the screen controller
                lda     IO_DDRA
                ora     #SCRN_OUT_PINS
                and     #(SCRN_OUT_PINS | SCRN_UNUSED)
                sta     IO_DDRA

                ; start with all pins low. Not needed (maybe) but
                ; it's nice to start with clean outputs
                lda     IO_PORTA
                and     #SCRN_UNUSED
                sta     IO_PORTA

                ; initialization sequence for screen controller
                lda     #str_screen_init
                jsr     print_string

                ; startup message
                lda     #str_startup
                jsr     print_string

kb_init:
                ; data direction on port B
                lda     #KB_ACK         ; only the ack pin is output
                sta     IO_DDRB

                lda     #str_any_key
                jsr     print_string

wait_for_key_press:
                ; The sender starts transmitting bytes as soon as
                ; it receives a NAK byte from the receiver. To be
                ; able to synchronize the two, the workflow is:
                ; 1. start sending command on sender
                ; 2. Press any key on the receiver to start the
                ;    transmission
                lda     IO_PORTB
                bpl     wait_for_key_press

                ; take the key from the buffer and ignore it
                jsr     receive_nibble
                jsr     receive_nibble
                jsr     receive_nibble

xmodem_receive:
                ; tell the sender to start sending
                lda     #NAK
                sta     SER_DATA

; Receiving bytes are done in two nested loops:
; .next_packet receives xmodem packets of 131 bytes long,
; including the 128 data bytes, and loops until an EOT byte
; is received right after a 
; .next_data_byte receives each of the 128 data bytes
.next_packet:
                jsr     receive_byte    ; receive SOH or EOT
                cmp     #EOT
                beq     .eot

                cmp     #SOH
                beq     .continue_header

                ; todo: error if ending up here?
.continue_header:
                jsr     receive_byte    ; packet sequence number
                jsr     receive_byte    ; packet sequence number checksum
                ; todo: add up and check if 0

                ldy     #128            ; 128 data bytes
.next_data_byte:
                jsr     receive_byte
                jsr     print_formatted_byte_as_hex

                dey
                bne     .next_data_byte 

                jsr     receive_byte    ; receive the data packet checksum

                ; todo: verify checksum and send ACK or NAK

                lda     #ACK
                sta     SER_DATA

                jmp     .next_packet
.eot:
                lda     #ACK
                sta     SER_DATA
                rts

receive_byte:
                ; reading a byte through serial connection
                ; is wrapped in turning DTR on and off. However
                ; it seems to not completely work, since we still
                ; need a short pause between the bytes when sending.
                lda     #%11001011      ; terminal ready
                sta     SER_CMD

                jsr     RD_SRL_B        ; blocking
                pha

                lda     #%11001010      ; terminal not ready
                sta     SER_CMD

                pla
                rts

; this only adds a space
print_formatted_byte_as_hex:
                jsr     print_byte_as_hex
                lda     #" "
                jsr     send_byte_to_screen
                rts

print_byte_as_hex:
                pha                     ; keep a copy for the low nibble

                lsr                     ; shift high nibble into low nibble
                lsr
                lsr
                lsr

                jsr     print_nibble

                pla                     ; get original value back
                and     #%00001111      ; reset high nibble
                jsr     print_nibble
                rts

print_nibble:
                cmp     #10
                bcs     .letter         ; >= 10 (hex letter A-F)
                adc     #48             ; ASCII offset to numbers 0-9
                jmp     .print
.letter:
                adc     #54             ; ASCII offset to letters A-F
.print:
                jsr     send_byte_to_screen
                rts

keyboard_loop:
                lda     IO_PORTB
                bpl     keyboard_loop

                ; receive the character. each receive_nibble call
                ; shifts 4 bits into KB_CHAR_IN
                jsr     receive_nibble
                jsr     receive_nibble

                ; write the character
                lda     KB_CHAR_IN
                jsr     send_byte_to_screen

                ; receive the flags; ignore for now
                jsr     receive_nibble

                jmp     keyboard_loop

receive_nibble:
                lda     IO_PORTB        ; LDA loads bit 7 (avail) into N
                ; move low nibble from PORT B to high nibble
                asl
                asl
                asl
                asl

                ldx     #4
.rotate:
                asl                     ; shift bit into carry
                rol     KB_CHAR_IN      ; rotate carry into CHAR
                dex
                bne     .rotate

                lda     IO_PORTB        ; send ack signal to kb controller
                ora     #KB_ACK
                sta     IO_PORTB
.wait_avail_low:
                lda     IO_PORTB        ; wait for available to go low
                bmi     .wait_avail_low ; negative means bit 7 (avail) high

                lda     IO_PORTB           ; set ack low
                and     #!KB_ACK
                sta     IO_PORTB
                rts


send_byte_to_screen:
                pha                     ; we pull off the arg twice, once for high
                pha                     ; nibble and once for low nibble

                lda     IO_PORTA
                and     #!SCRN_DATA_PINS; clear data
                sta     IO_PORTA

                jsr     wait_ack_low
                pla
                and     #%11110000      ; mask out low nibble
                ora     IO_PORTA
                sta     IO_PORTA

                ora     #SCRN_AVAILABLE ; flip available = high
                sta     IO_PORTA

                jsr     wait_ack_high

                and     #%00001111      ; clear data so we can ora with high nibble
                sta     IO_PORTA

                pla                     ; get the original byte back
                asl                     ; shift low nibble into high nibble
                asl                     
                asl
                asl                     

                ora     IO_PORTA
                sta     IO_PORTA

                and     #~SCRN_AVAILABLE     ; flip available = low
                sta     IO_PORTA

                jsr     wait_ack_low

                rts


wait_ack_high:
                pha
.loop
                lda     IO_PORTA
                and     #SCRN_ACK
                beq     .loop
                pla
                rts
wait_ack_low:
                pha
.loop:
                lda     IO_PORTA
                and     #SCRN_ACK
                bne     .loop
                pla
                rts


print_string:
                asl                     ; multiply by 2 because size of memory address is 2 bytes
                tay
                lda     string_table,y  ; string index into string table
                sta     tmp3            ; LSB
                iny
                lda     string_table,y
                sta     tmp3+1          ; MSB

                                ldy #0
.next_char:
                lda (tmp3),y
                beq .done

                jsr send_byte_to_screen
                iny
                bra .next_char
.done:
                lda     #$0d
                jsr     send_byte_to_screen
                lda     #$0a
                jsr     send_byte_to_screen
                rts

; strings ========================================

str_screen_init =       0
str_startup     =       1
str_any_key     =       2

string_table:
                .word s_screen_init, s_startup, s_any_key

s_screen_init:  .byte CLEAR_SCREEN, CHOOSE_CURSOR, CURSOR_CHAR, CURSOR_BLINK, 0
s_startup:      .byte "Shallow Thought v0.01", 0                
s_any_key:      .byte "Press any key", 0
