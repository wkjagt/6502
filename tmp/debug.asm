    ; .include "../../pager_os/build/pager_os/pager_os.inc"

                .org $0600

SVADDR          = $50   ; 16 bytes before input buffer
BRKRET          = SVADDR                ; 2 bytes
SAVEA           = SVADDR + 2            ; 1 byte
SAVEX           = SVADDR + 3            ; 1 byte
SAVEY           = SVADDR + 4            ; 1 byte
STATUS          = SVADDR + 5            ; 1 byte

VIA_IER_TIMER1  = %01000000

                sei
                lda     #<int_handler
                sta     JMP_IRQ_HANDLER + 1
                lda     #>int_handler
                sta     JMP_IRQ_HANDLER + 2

                lda     #VIA_IER_TIMER1      ; disable timer (for testing)
                sta     __VIA1_START__ + $0e ; IER
                

                lda     #%10010000           ; enable CB1
                sta     __VIA1_START__ + $0e ; IER

                cli

                ; ldx     #5
                ; lda     #$ff
                ; sec
                ; brk
                ; nop
                ; jmp     ($4000)
                rts

int_handler:    sta     SAVEA
                stx     SAVEX
                sty     SAVEY

                pla                     ; A = status register before interrupt
                sta     STATUS
                plx                     ; X = low byte of return
                stx     BRKRET
                ply                     ; Y = high byte of return
                sty     BRKRET+1
                phy
                phx
                pha
                and     #%00010000
                beq     .is_irq           ; ignore IRQ

                ;========= this is a BRK instruction =========
                jsr     breakpoint
                bra     .done
                
.is_irq         ;lda     __VIA1_START__ + $0d ; IFR
                ;jsr     JMP_PRINT_HEX
                ; and     #%00010000
                ; beq     .done
                ; lda     #"I"
                ; jsr     JMP_PUTC
                jsr     breakpoint

                bit     __VIA1_START__  ; clear interrupt

.done:          lda     SAVEA
                ldx     SAVEX
                ldy     SAVEY
                rti


breakpoint:     lda     #1
                jsr     set_output_dev
                jsr     lcd_clear
                jsr     lcd_home


                jsr     lcd_line1
                jsr     JMP_PRINT_STRING
                .byte   "        NV1BDIZC",0


                jsr     lcd_line2
                jsr     JMP_PRINT_STRING
                .byte   "Status: ",0

                ldx     #8
                lda     STATUS
.statusloop     rol     a
                pha
                lda     #"0"
                adc     #0
                jsr     JMP_PUTC
                dex
                pla
                bne     .statusloop

                jsr     lcd_line3
                jsr     JMP_PRINT_STRING
                .byte   "A:",0
                lda     SAVEA
                jsr     JMP_PRINT_HEX
                
                jsr     JMP_PRINT_STRING
                .byte   " X:",0
                lda     SAVEX
                jsr     JMP_PRINT_HEX

                jsr     JMP_PRINT_STRING
                .byte   " Y:",0
                lda     SAVEY
                jsr     JMP_PRINT_HEX

                jsr     lcd_line4
                jsr     JMP_PRINT_STRING
                .byte   "P:",0
                lda     BRKRET+1
                jsr     JMP_PRINT_HEX
                lda     BRKRET
                jsr     JMP_PRINT_HEX

                lda     #" "
                jsr     JMP_PUTC

                lda     BRKRET
                sta     code_pointer
                lda     BRKRET+1
                sta     code_pointer+1
                jsr     find_instruction
                jsr     print_instruction

                ; jsr     read_key
                lda     #0
                jsr     set_output_dev
                rts


lcd_line1:      lda     #($80 + 0)
                jsr     lcd_instruction
                rts

lcd_line2:      lda     #($80 + $40)
                jsr     lcd_instruction
                rts

lcd_line3:      lda     #($80 + $14)
                jsr     lcd_instruction
                rts

lcd_line4:      lda     #($80 + $54)
                jsr     lcd_instruction
                rts

lcd_instruction:ldx     #0
                jsr     lcd_write_4bit
                rts

                .include "../../pager_os/build/pager_os/pager_os.inc"
