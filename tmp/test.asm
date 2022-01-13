; vasm6502_oldstyle -Fbin -dotdir -c02 test.asm -o test.rom && py65mon -m 65c02 -r test.rom

option_vector = $00
keybuffer_ptr = $02
keybuffer =     $80

                .org $8000:

start:
                ldx #0
clear_zp:
                sta 0,x
                inx
                bne clear_zp                

                ldx #0
init_loop:
                lda chosen,x
                beq .done
                sta keybuffer,x
                inx
                jmp init_loop
.done:

next_command:
                lda #$0A
                jsr putc
                cmp #$0D
                jsr putc
                lda #0
                sta keybuffer_ptr

                ldx #keybuffer_ptr
clear_buffer:                
                sta 0,x
                inx
                bne clear_buffer
next_key:
                jsr getc

                cmp #$7F
                beq .backspace

                jsr putc

                cmp #$20
                bne .not_a_space
                lda #0
.not_a_space:


                

                cmp #$0D
                beq .enter

                ldx keybuffer_ptr
                sta keybuffer,x
                inc keybuffer_ptr

                bra next_key
.enter:
                lda #$0A
                jsr putc
                jsr execute_option
                bra next_command
.backspace:
                lda #$08
                jsr putc
                lda #" "
                jsr putc
                lda #$08
                jsr putc

                lda keybuffer_ptr
                beq next_key
                dec keybuffer_ptr
                lda #0
                sta keybuffer,x

                bra next_key


execute_option:
                ldx #0                  ; index into list of options
find_option_loop:
                ; set up the pointer
                lda options,x
                sta option_vector
                inx
                lda options,x
                sta option_vector+1

                lda (option_vector)
                bne .continue
                lda (option_vector+1)
                beq .done

.continue:
                jsr match_option
                inx
                bra find_option_loop
.done:
                rts

match_option:
                ldy #0                  ; index into strings
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

chosen:         .byte "option3",0

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
                adc #48
putc:
                sta $F001
                rts

getc:
                lda $f004
                beq getc
                rts


options:
                .word o_option1, o_option2, o_option3, 0

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