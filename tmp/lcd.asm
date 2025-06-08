                .org $0600

main:           jsr     lcd_clear
                ldy     #0
.loop:          lda     message,y
                beq     .done
                jsr     lcd_putc
                iny     
                bne     .loop
.done:          rts

message:
                .byte "P:0603 LDA ($2000),y"
                .byte "WATCH 1: 20         "
                .byte "A:00 X:05 Y:FF S:FF "
                .byte "WATCH 2: 40         "
                .byte 0

    .include "../../pager_os/build/pager_os/pager_os.inc"
