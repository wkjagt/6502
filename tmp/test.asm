; vasm6502_oldstyle -Fbin -dotdir -c02 test.asm -o test.rom && py65mon -m 65c02 -r test.rom

command_vector  =       $00
keybuffer_ptr   =       $02
tmp1            =       $04
tmp2            =       $06
dump_start      =       $08
param_index     =       $0a
keybuffer       =       $80

SPACE           =       $20
LF              =       $0A
CR              =       $0D
DEL             =       $7F
BS              =       $08

                .org $8000

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
                lda commands,x
                sta tmp1
                inx
                lda commands,x
                sta tmp1+1

                lda (tmp1)
                bne .continue
                lda (tmp1+1)
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
                cmp (tmp1),y
                bne .done
.char_match
                ; is it the last character?
                lda keybuffer,y
                beq .string_match
                iny
                jmp .char_cmp_loop
.string_match:         
                iny     ; skip past the 0 at the end of the string
                ; tmp1 now points to the command that holds the address
                ; to jump to. Store that address in command_vector so we
                ; can jump to it.
                sty param_index

                lda (tmp1), y
                sta command_vector      
                iny
                lda (tmp1), y
                sta command_vector+1

                jmp (command_vector)
.done
                rts

dump:
                clc
                lda #keybuffer
                adc param_index
                
                jsr hex_to_byte
                jsr dump_page
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


hex_to_byte:
                sta     tmp2            ; we need the address to do lda (tmp2), y

                ldy     #0              ; high byte
                lda     (tmp2),y
                jsr     shift_in_nibble

                iny
                lda     (tmp2),y        ; low byte
                jsr     shift_in_nibble

                lda     tmp1            ; put the result back in A as return value
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


                .org $a000
commands:
                .word o_dump, o_command2, o_command3, 0

o_dump:          .byte "dump", 0
                 .word dump
o_command2:      .byte "command2", 0
                 .word command2
o_command3:      .byte "command3", 0
                 .word command3


; vectors
                .org $FFFA
                
                .word start
                .word start
                .word start