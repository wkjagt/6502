SER_DATA        =       $4800           ; Data register
SER_ST          =       $4801           ; Status register
SER_CMD         =       $4802           ; Command register
SER_CTL         =       $4803           ; Control register
SER_RXFL        =       %00001000       ; Serial Receive full bit
PORTA           =       $6001           ; Data port A
PORTA_DDR       =       $6003           ; Data direction of port A


CHAR            =       $0
ACK             =       %01000000

                .ORG    $0700

setup:
                ; 0 = input, 1 = output
                lda     #%01000000
                sta     PORTA_DDR
                ldx     #0
.startup_text_loop:
                lda     startup_text, x
                beq     .done
                jsr     write_to_terminal
                inx
                jmp     .startup_text_loop
.done:
                jsr     keyboard
                rts

keyboard:
                jsr     receive_nibble
                jsr     receive_nibble

                lda     CHAR
                jsr     write_to_terminal

                jmp     keyboard

receive_nibble:
                lda     PORTA
                bpl     receive_nibble

                asl                     ; move low nibble to high nibble
                asl
                asl
                asl

                ldx     #4
.shift:
                asl                     ; shift bit into carry
                rol     CHAR            ; rotate carry into CHAR
                dex
                bne     .shift

                lda     PORTA           ; send ack signal to kb controller
                ora     #ACK
                sta     PORTA
.wait_avail_low:
                lda     PORTA           ; wait for available to go low
                bmi     .wait_avail_low ; negative means bit 7 (avail) high

                lda     PORTA           ; set ack low
                and     #!ACK
                sta     PORTA
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
