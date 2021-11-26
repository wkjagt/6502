SER_DATA        =       $4800           ; Data register
SER_ST          =       $4801           ; Status register
SER_CMD         =       $4802           ; Command register
SER_CTL         =       $4803           ; Control register
SER_RXFL        =       %00001000       ; Serial Receive full bit
PORTB           =       $6000           ; Data port B
PORTA           =       $6001           ; Data port A
PORTB_DDR       =       $6002           ; Data direction of port B
PORTA_DDR       =       $6003           ; Data direction of port A

CHAR            =       $0
ACK             =       %01000000

                .ORG    $0700

setup:
                ; 0 = input, 1 = output
                lda     #ACK
                sta     PORTB_DDR

keyboard_loop:
                ; receive the character
                jsr     receive_nibble
                jsr     receive_nibble

                ; write the character
                lda     CHAR
                jsr     write_to_terminal

                ; receive the flags
                jsr     receive_nibble

                jmp     keyboard_loop

receive_nibble:
                lda     PORTB           ; LDA loads bit 7 (avail) into N
                bpl     receive_nibble  ; repeat until avail is 1

                ldx     #4
.shift:
                asl                     ; move low nibble to high nibble
                dex
                bne     .shift

                ldx     #4
.rotate:
                asl                     ; shift bit into carry
                rol     CHAR            ; rotate carry into CHAR
                dex
                bne     .rotate

                lda     PORTB           ; send ack signal to kb controller
                ora     #ACK
                sta     PORTB
.wait_avail_low:
                lda     PORTB           ; wait for available to go low
                bmi     .wait_avail_low ; negative means bit 7 (avail) high

                lda     PORTB           ; set ack low
                and     #!ACK
                sta     PORTB
                rts

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

startup_text:
                .asciiz "Start", $0d, $0a, $00
