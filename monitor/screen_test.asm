IO_PORTB = $6000                        ; Data port B
IO_PORTA = $6001                        ; Data port A
IO_DDRB  = $6002                        ; Data direction of port B
IO_DDRA  = $6003                        ; Data direction of port A
IO_PCR   = $600c                        ; Peripheral control register
IO_IFR   = $600d                        ; Interrupt flag register
IO_IER   = $600e                        ; Interrupt enable register


CLEAR_SCREEN    =       $0c
CHOOSE_CURSOR   =       2
CURSOR_CHAR     =       $db
CURSOR_BLINK    =       3

DATA_PINS       =       %11110000
AVAILABLE       =       %00000100
ACK             =       %00001000
OUTPUT_PINS     =       DATA_PINS | AVAILABLE
UNUSED_PINS     =       %00000011

                .ORG    $0700

screen_init:
                ; set data direction for the 6 needed pins, while keeping
                ; the unused ones unchanged
                lda     IO_DDRA
                ora     #OUTPUT_PINS
                and     #(OUTPUT_PINS | UNUSED_PINS)
                sta     IO_DDRA

                ; set all used pins low, while keeping the unused ones unchanged
                lda     IO_PORTA
                and     #UNUSED_PINS
                sta     IO_PORTA

                lda     #CLEAR_SCREEN
                jsr     send_byte
                lda     #CHOOSE_CURSOR
                jsr     send_byte
                lda     #CURSOR_CHAR
                jsr     send_byte
                lda     #CURSOR_BLINK
                jsr     send_byte
                
                ldx     #0
.text_loop:
                lda     text,x
                beq     .done
                inx
                jsr     send_byte
                jmp     .text_loop
.done
                rts

text:                             ; CR   LF  Null
    .asciiz "Shallow Thought v0.01 / 14-10-2021", $0d, $0a, $00

send_byte:
                pha                     ; we pull off the arg twice, once for high
                pha                     ; nibble and once for low nibble

                lda     IO_PORTA
                and     #!DATA_PINS     ; clear data
                sta     IO_PORTA

                jsr     wait_ack_low
                pla
                and     #%11110000      ; mask out low nibble
                ora     IO_PORTA
                sta     IO_PORTA

                ora     #AVAILABLE      ; flip available = high
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

                and     #~AVAILABLE     ; flip available = low
                sta     IO_PORTA

                jsr     wait_ack_low

                rts


wait_ack_high:
                pha
.loop
                lda     IO_PORTA
                and     #ACK
                beq     .loop
                pla
                rts
wait_ack_low:
                pha
.loop:
                lda     IO_PORTA
                and     #ACK
                bne     .loop
                pla
                rts