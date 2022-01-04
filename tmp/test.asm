; vasm6502_oldstyle -Fbin -dotdir -c02 test.asm -o test.rom && py65mon -m 65c02 -r test.rom

                .org $8000
start:
                lda     #$FF
                sta     1
                
                ldx     #0
                ldy     #17
loop:
                dey
                bne     .continue
                lda     #13
                jsr     putc
                lda     #10
                jsr     putc
                ldy     #16
.continue:
                lda     $8000,x
                jsr     print_formatted_byte_as_hex
                inx
                bne     loop
.done
                rts

print_formatted_byte_as_hex:
                jsr     print_byte_as_hex
                lda     #" "
                jsr     putc
                rts

print_byte_as_hex:
                pha                     ; keep a copy for the low nibble

                lsr                     ; shift high nibble into low nibble
                lsr
                lsr
                lsr

                jsr     print_nibble

                pla                     ; get original value back
                and     #$0F            ; reset high nibble
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
                jsr     putc
                rts


putc:
                sta     $F001
                rts

; vectors
                .org $FFFA
                
                .word start
                .word start
                .word start