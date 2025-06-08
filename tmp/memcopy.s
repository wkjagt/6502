; vasm6502_oldstyle -Fbin -dotdir -c02 exercise.s -o exercise.rom && py65mon -m 65c02 -r exercise.rom

                .org    $600


reset:          jsr     newline
                jsr     newline
                ldx     #0

;================================================
; Helpers
;================================================
newline:        lda     #$0d
                jsr     putc
                lda     #$0a
                jsr     putc
                rts

putc:           sta     $f001
                rts

getc:           lda     $f004
                beq     getc
                rts

                .org    $fffa
                .word   reset
                .word   reset
                .word   reset

                .org    $800

rows:           .byte   1,2,3,4,5,6,7,8,9,10
                .byte   0,0,0,0,0,0,0,0,0,0
                .byte   10,9,8,7,6,5,4,3,2,1
                .byte   0,0,0,0,0,0,0,0,0,0
