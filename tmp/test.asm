; vasm6502_oldstyle -Fbin -dotdir -c02 test.asm -o test.rom && py65mon -m 65c02 -r test.rom

command_vector  =       $00
keybuffer_ptr   =       $02
keybuffer       =       $80

SPACE           =       $20
LF              =       $0A
CR              =       $0D
DEL             =       $7F
BS              =       $08

                .org $8000:

start:
                ldx #0
clear_zp:
                sta 0,x
                inx
                bne clear_zp

next_command:
                lda #LF
                jsr putc
                cmp #CR
                jsr putc
                lda #0
                sta keybuffer_ptr

                ldx #128
clear_buffer:                
                sta keybuffer,x
                dex
                bne clear_buffer
next_key:
                jsr getc

                cmp #DEL
                beq .backspace

                jsr putc

                cmp #SPACE
                bne .not_a_space
                lda #0                  ; save 0 instead of space
.not_a_space:
                cmp #CR                
                beq .enter

                ldx keybuffer_ptr
                sta keybuffer,x
                inc keybuffer_ptr

                bra next_key
.enter:
                lda #LF
                jsr putc
                jsr execute_command
                bra next_command
.backspace:
                lda #BS
                jsr putc
                lda #" "
                jsr putc
                lda #BS
                jsr putc

                lda keybuffer_ptr
                beq next_key
                dec keybuffer_ptr
                lda #0
                sta keybuffer,x

                bra next_key


execute_command:
                ldx #0                  ; index into list of commands
find_command_loop:
                ; set up the pointer
                lda commands,x
                sta command_vector
                inx
                lda commands,x
                sta command_vector+1

                lda (command_vector)
                bne .continue
                lda (command_vector+1)
                beq .done

.continue:
                jsr match_command
                inx
                bra find_command_loop
.done:
                rts

match_command:
                ldy #0                  ; index into strings
.char_cmp_loop:
                ; compare one character
                lda keybuffer,y
                cmp (command_vector),y
                bne .done
.char_match
                ; is it the last character?
                lda keybuffer,y
                beq .string_match
                iny
                jmp .char_cmp_loop
.string_match:         
                iny     ; skip past the 0 at the end of the string

                ; command_vector now points to the command that holds the address
                ; to jump to. Store that address in command_vector directly so we
                ; can jump to it.
                lda (command_vector), y
                sta command_vector

                lda (command_vector+1), y
                lda command_vector+1

                jmp (command_vector)
.done
                rts

rcv:
                lda keybuffer_ptr
                
                ; inx
                ; inx
                ; lda keybuffer,x
                jsr putnr
                rts

command2:
                lda #"2"
                jsr putc
                rts

command3:
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

commands:
                .word o_rcv, o_command2, o_command3, 0

o_rcv:           .byte "rcv", 0
                 .word rcv
o_command2:      .byte "command2", 0
                 .word command2
o_command3:      .byte "command3", 0
                 .word command3


; vectors
                .org $FFFA
                
                .word start
                .word start
                .word start