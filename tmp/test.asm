JUMP_TABLE_ADDR         = $300
JMP_DUMP:               = JUMP_TABLE_ADDR + 0
JMP_RCV:                = JUMP_TABLE_ADDR + 3
JMP_INIT_SCREEN:        = JUMP_TABLE_ADDR + 6
JMP_RUN:                = JUMP_TABLE_ADDR + 9
JMP_RESET:              = JUMP_TABLE_ADDR + 12
JMP_PUTC:               = JUMP_TABLE_ADDR + 15
JMP_PRINT_HEX:          = JUMP_TABLE_ADDR + 18
JMP_XMODEM_RCV:         = JUMP_TABLE_ADDR + 21
JMP_GETC:               = JUMP_TABLE_ADDR + 24
JMP_INIT_KB:            = JUMP_TABLE_ADDR + 27
JMP_LINE_INPUT:         = JUMP_TABLE_ADDR + 30
JMP_IRQ_HANDLER:        = JUMP_TABLE_ADDR + 33
JMP_NMI_HANDLER:        = JUMP_TABLE_ADDR + 36
JMP_INIT_SERIAL:        = JUMP_TABLE_ADDR + 39
JMP_CURSOR_ON:          = JUMP_TABLE_ADDR + 42
JMP_CURSOR_OFF:         = JUMP_TABLE_ADDR + 45
JMP_DRAW_PIXEL:         = JUMP_TABLE_ADDR + 48
JMP_RMV_PIXEL:          = JUMP_TABLE_ADDR + 51
JMP_INIT_STORAGE:       = JUMP_TABLE_ADDR + 54
JMP_STOR_READ:          = JUMP_TABLE_ADDR + 57
JMP_STOR_WRITE:         = JUMP_TABLE_ADDR + 60


cursor_x                = $30
cursor_y                = $31
cell                    = $32           ; the cell the cursor is on
prev_cell               = $33
edit_page               = $34           ; two bytes

RIGHT                   = $1C
LEFT                    = $1D
UP                      = $1E
DOWN                    = $1F

                .org $2000

start:          stz     cell
                stz     prev_cell
                jsr     JMP_INIT_SCREEN
                stz     edit_page
                lda     #$20
                sta     edit_page+1

                jsr     JMP_DUMP
                jsr     move_cursor
loop:           jsr     JMP_GETC
                tax                     ; puts pressed char in X

.cmp_right:     cpx     #RIGHT
                bne     .cmp_left
                lda     cell
                and     #%00001111      ; in rightmost column the four last bits are always set
                cmp     #%00001111
                beq     ignore
                inc     cell
                jmp     .move_cursor

.cmp_left:      cpx     #LEFT
                bne     .cmp_up
                lda     cell
                and     #%00001111      ; ignore the 4 highest bits
                beq     ignore          ; last 4 bits need to have something set
                dec     cell
                jmp     .move_cursor

.cmp_up:        cpx     #UP
                bne     .cmp_down
                lda     cell
                and     #%11110000      ; for the top row the high nibble is always 0
                beq     ignore
                sec
                lda     cell
                sbc     #16
                sta     cell
                jmp     .move_cursor

.cmp_down:      cpx     #DOWN
                bne     .cmp_hex
                lda     cell
                and     #%11110000      ; for the bottom row, the high nibble is always 1111
                cmp     #%11110000
                beq     ignore
                clc
                lda     cell
                adc     #16
                sta     cell
                jmp     .move_cursor

.move_cursor:   lda     prev_cell
                tay
                lda     (edit_page), y
                jsr     JMP_PRINT_HEX   ; put original value back
                lda     cell
                sta     prev_cell
                jsr     move_cursor
                bra     loop
                

.cmp_hex:       jsr     JMP_INIT_SCREEN
                rts
ignore:         bra     loop
                rts



; low nibble = x
; high nibble = y
move_cursor:    jsr     cursor_home
                jsr     cursor_down
                ldx     #6
.loop:          jsr     cursor_right
                dex
                bne     .loop

.hor_adjust:    lda     cell
                and     #%00001111      ; only keep low nibble
                tax
                beq     .ver_adjust
.loop2:         jsr     cursor_right
                jsr     cursor_right
                jsr     cursor_right
                dex
                bne     .loop2

                ; if we're at the right of the separation, we need to move one
                ; more position to the right. 
                lda     cell
                and     #%00001000      ; on the right side, bit 3 is always set
                beq     .ver_adjust
                jsr     cursor_right

.ver_adjust:    lda     cell
                lsr                     ; only keep high nibble
                lsr
                lsr
                lsr
                tax
                beq     .done
.loop3:         jsr     cursor_down
                dex
                bne     .loop3
.done           
                lda     #"_"
                jsr     JMP_PUTC
                jsr     JMP_PUTC
                jsr     cursor_Left
                jsr     cursor_Left
                rts





cursor_home:    lda     #$01
                jsr     JMP_PUTC
                rts
cursor_right:   lda     #$1C
                jsr     JMP_PUTC
                rts
cursor_Left:    lda     #$1D
                jsr     JMP_PUTC
                rts
cursor_up:      lda     #$1E
                jsr     JMP_PUTC
                rts
cursor_down:    lda     #$1F
                jsr     JMP_PUTC
                rts

text:
                .byte "This is a program!",0