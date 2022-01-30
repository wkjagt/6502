; vasm6502_oldstyle -Fbin -dotdir -c02 dump.asm -o dump.rom && py65mon -m 65c02 -r dump.rom
LF              =       $0A
CR              =       $0D
dump_start      =       $00 ; byte 0: 0, byte 1: selected page
tmp1            =       $02
buffer_ptr      =       $04
buffer          =       $80

                .org    $8000

start:
                lda     #0
                sta     buffer_ptr
key_loop:
                jsr     getc
                cmp     #CR                
                beq     .enter
.enter:
                jsr     hex_to_byte     ; get the byte value for the page to dump
                jsr     dump_page
                rts

hex_to_byte:
                lda     buffer
                jsr     shift_in_nibble
                lda     buffer+1
                jsr     shift_in_nibble
                lda     tmp1
                rts
shift_in_nibble:
                cmp     #":"            ; the next ascii char after "9"
                bcc     .number
                                        ; assume it's a letter
                sbc     #87             ; get the letter value
                jmp     .continue
.number:
                sec
                sbc     #48
.continue:      
                ; calculated nibble is now in low nibble
                ; shift low nibble to high nibble
                asl 
                asl 
                asl 
                asl

                ; left shift hight nibble into result
                asl
                rol     tmp1
                asl
                rol     tmp1
                asl
                rol     tmp1
                asl
                rol     tmp1

                rts

dump_page:
                sta     dump_start+1
                ldx     #0
                ldy     #0
.rowloop:
                lda     (dump_start),y
                jsr     print_byte_as_hex
                lda     #" "
                jsr     putc
                iny
                beq     .done
                inx
                cpx     #16
                beq     .next_row
                bra     .rowloop
.next_row:
                lda     #LF
                jsr     putc
                lda     #CR
                jsr     putc
                ldx     #0
                bra     .rowloop
.done:
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
                jsr     putc
                rts

putc:
                sta $F001
                rts

getc:
                lda $f004
                beq getc
                rts

; vectors
                .org $FFFA
                
                .word start
                .word start
                .word start