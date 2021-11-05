IO_PORTB = $6000                        ; Data port B
IO_PORTA = $6001                        ; Data port A
IO_DDRB  = $6002                        ; Data direction of port B
IO_DDRA  = $6003                        ; Data direction of port A
IO_PCR   = $600c                        ; Peripheral control register
IO_IFR   = $600d                        ; Interrupt flag register
IO_IER   = $600e                        ; Interrupt enable register

; pins:
; 2 : 0000.0100 AVAIL (write)
; 3 : 0000.1000 ACK   (read)
; 4 : 0001.0000 DATA0 (read)
; 5 : 0010.0000 DATA1 (read)
; 6 : 0100.0000 DATA2 (read)
; 7 : 1000.0000 DATA3 (read)

; char A: ASCII: 0100.0001
                .ORG    $0700

screen_init:
                ; set data direction for the 6 needed pins, while keeping
                ; the unused ones unchanged
                lda     IO_DDRA
                ora     #%11110100      ; set output bits (1s)
                and     #%11110111      ; set input bits (0s)
                sta     IO_DDRA

                ; set all used pins low, while keeping the unused ones unchanged
                lda     IO_PORTA
                and     #%00000011
                sta     IO_PORTA


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
    .asciiz "123", $00

send_byte:
                pha                     ; we need this back later for the low nibble
                jsr     wait_ack_low
                
                and     #%11110000      ; mask out low nibble
                ora     IO_PORTA
                sta     IO_PORTA

                ora     #%00000100      ; flip available = high
                sta     IO_PORTA

                jsr     wait_ack_high

                and     #%00001111      ; clear data so we can ora with high nibble
                sta     IO_PORTA

                pla                     ; get the original byte back
                asl                     ; shift low nibble i
                asl                     
                asl
                asl                     

                ora     IO_PORTA        ; 0001 0100
                sta     IO_PORTA

                and     #%11111011          ; 0001 0000
                sta     IO_PORTA

                jsr     wait_ack_low

                rts


wait_ack_high:
                pha
.loop
                lda     IO_PORTA
                and     #%00001000
                beq     .loop
                pla
                rts
wait_ack_low:
                pha
.loop:
                lda     IO_PORTA
                and     #%00001000
                bne     .loop
                pla
                rts




