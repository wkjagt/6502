SCRN_DATA_PINS  =       %11110000       ; In 4 bit mode: send 4 bits of data at a time
SCRN_AVAILABLE  =       %00000100       ; To tell the screen that new data is available
SCRN_ACK        =       %00001000       ; Input pin for the screen to ack the data
SCRN_OUT_PINS   =       SCRN_DATA_PINS | SCRN_AVAILABLE
SCRN_UNUSED     =       %00000011       ; unused pins on this port

VIA1_PORTA      =       $6001
VIA1_DDRA      =        $6003

                .org $600

                jmp     main
    .include "../../pager_os/build/pager_os/pager_os.inc"
    .include "liblcd.asm"


; what happens if pin is set to 0 when on output
; and a 1 is read when on input
main:           
                
                ; lda     #1
                ; tsb     VIA1_DDRA       ; set pin 1 to output
                ; trb     VIA1_PORTA      ; set pin 0 to value 0

                jsr     seeporta

        
                ; jsr     JMP_INIT_STORAGE
                ; jsr     seeporta

;                 jsr     lcd_init
;                 ldy     #0
; .loop:          lda     message,y
;                 beq     .done
;                 ldx     #LCD_RS_DATA
;                 jsr     lcd_write_4bit
;                 iny     
;                 bne     .loop
                
; .done:          jsr     seeporta
                rts


seeporta:       lda     VIA1_DDRA
                pha
                lda     #1
                tsb     VIA1_DDRA       ; set pin 1 to output
                lda     VIA1_PORTA
                jsr     JMP_PRINT_HEX
                pla
                sta     VIA1_DDRA
                rts

message:
        .byte "P:0603 LDA ($2000),y"
        .byte "WATCH 1: 20         "
        .byte "A:00 X:05 Y:FF S:FF "
        .byte "WATCH 2: 40         "
        .byte 0

