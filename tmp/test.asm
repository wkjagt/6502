; vasm6502_oldstyle -Fbin -dotdir -c02 test.asm -o test.rom && py65mon -m 65c02 -r test.rom

option_vector = $7e
keybuffer =     $80


                .org $8000
start:
                ldx #0
init_loop:
                lda chosen,x
                beq .done
                sta keybuffer,x
                inx
                jmp init_loop
.done:

                ldx #0 ; index into list of options
find_option_loop:
                lda options,x
                sta option_vector
                inx
                lda options,x
                sta option_vector+1

                jsr compare_option
                inx
                cpx #6                  ; temp until the loop exits at the end of the list
                bne find_option_loop
                rts

compare_option:
                ldy #0
.char_cmp_loop:
                ; compare one character
                lda keybuffer,y
                cmp (option_vector),y
                bne .not_a_match

                ; is it the last character?
                lda keybuffer,y
                beq .found
                iny
                jmp .char_cmp_loop
.not_a_match:
                lda #"N"
                jsr putc
                rts
.found:         
                iny     ; skip past the 0 at the end of the string

                ; option_vector now points to the option that holds the address
                ; to jump to. Store that address in option_vector directly so we
                ; can jump to it.
                lda (option_vector), y
                sta option_vector

                lda (option_vector+1), y
                lda option_vector+1

                jmp (option_vector)
                rts

chosen:         .byte "option1",0

option1:
                lda #"1"
                jsr putc
                rts

option2:
                lda #"2"
                jsr putc
                rts

option3:
                lda #"3"
                jsr putc
                rts

putnr:
                adc     #48
putc:
                sta     $F001
                rts

options:
                .word o_option1, o_option2, o_option3

o_option1:      .byte "option1", 0
test1:          .word option1
o_option2:      .byte "option2", 0
test2:          .word option2
o_option3:      .byte "option3", 0
test3:          .word option3




; vectors
                .org $FFFA
                
                .word start
                .word start
                .word start