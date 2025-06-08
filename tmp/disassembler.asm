LF                      = $0A
CR                      = $0D


                .macro inc16
                inc \1
                bne .\@
                inc (\1)+1
.\@:          
                .endmacro

                .org    $600
                bbr0    $42, main
                lda     $1234
                nop
                nop
main:           lda     #0
                sta     code_pointer
                lda     #06
                sta     code_pointer+1
                ldx     #20
.loop:          jsr     print_line
                dex
                bne     .loop
                rts 

;==============================================================
; print one line of disassembled code, starting at the address
; stored at code_pointer
;==============================================================
print_line:     phx
                lda     code_pointer+1
                jsr     JMP_PRINT_HEX
                lda     code_pointer
                jsr     JMP_PRINT_HEX
                lda     #":"
                jsr     JMP_PUTC
                lda     #" "
                jsr     JMP_PUTC
                jsr     find_instruction
                ldy     addr_mode
                ldx     addressing_modes+1,y  ; instruction size
                ldy     #0
.byteloop:      lda     (code_pointer),y
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                iny
                dex
                bne     .byteloop
.spaceloop:     cpy     #4
                beq     .next
                lda     #" "
                jsr     JMP_PUTC
                lda     #" "
                jsr     JMP_PUTC
                lda     #" "
                jsr     JMP_PUTC
                iny
                bra     .spaceloop
.next:          jsr     print_instruction
                inc16   code_pointer
                lda     #CR
                jsr     JMP_PUTC
                lda     #LF
                jsr     JMP_PUTC
                plx
                rts


                .include "../../pager_os/build/pager_os/pager_os.inc"