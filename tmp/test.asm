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


hex_to_byte             = $8412

cursor_x                = $30
cursor_y                = $31
cell                    = $32           ; the cell the cursor is on
prev_cell               = $33
edit_page               = $34           ; 2 bytes
input                   = $36           ; 2 bytes
input_pointer           = $38
tmp1                    = $39

ESC                     = $1B
RIGHT                   = $1C
LEFT                    = $1D
UP                      = $1E
DOWN                    = $1F
LF                      = $0A
LOW_NIBBLE              = %00001111
HIGH_NIBBLE             = %11110000

                .org $2000

start:          stz     cell
                stz     prev_cell
                jsr     JMP_INIT_SCREEN
                stz     edit_page
                lda     #$20
                sta     edit_page+1
                jsr     reset_input


                jsr     JMP_DUMP
                jsr     move_to_cell
loop:           jsr     JMP_GETC
                tax                     ; puts pressed char in X

.cmp_right:     cpx     #RIGHT
                bne     .cmp_left
                lda     cell
                and     #LOW_NIBBLE     ; in rightmost column the four last bits are always set
                cmp     #LOW_NIBBLE
                beq     loop
                lda     #1
                jsr     update_cell
                jmp     loop

.cmp_left:      cpx     #LEFT
                bne     .cmp_up
                lda     cell
                and     #LOW_NIBBLE     ; ignore the 4 highest bits
                beq     loop          ; last 4 bits need to have something set
                lda     #-1
                jsr     update_cell
                jmp     loop

.cmp_up:        cpx     #UP
                bne     .cmp_down
                lda     cell
                and     #HIGH_NIBBLE    ; for the top row the high nibble is always 0
                beq     loop
                lda     #-16
                jsr     update_cell
                jmp     loop

.cmp_down:      cpx     #DOWN
                bne     .cmp_hex
                lda     cell
                and     #HIGH_NIBBLE    ; for the bottom row, the high nibble is always 1111
                cmp     #HIGH_NIBBLE
                beq     loop
                lda     #16
                jsr     update_cell
                jmp     loop
                
.cmp_hex:       cpx     #"0"
                bcc     .check_enter
                cpx     #":"            ; next ascii after 9
                bcs     .capital
                txa
                bra     .is_hex
.capital        cpx     #"A"
                bcc     .check_enter
                cpx     #"G"
                bcs     .letter
                txa
                bra     .is_hex
.letter:        cpx     #"a"
                bcc     .check_enter
                cpx     #"g"
                bcs     .check_enter
                txa
                sec
                sbc     #32
.is_hex:        jsr     hex_input
                jmp     loop


.check_enter:   cpx     #LF
                bne     .check_esc
                lda     #input
                jsr     hex_to_byte     ; byte into A
                ldy     cell
                sta     (edit_page), y
                jsr     reset_input
                jmp     loop

.check_esc:     cpx     #ESC
                beq     .exit
                jmp     loop

.exit:          jsr     JMP_INIT_SCREEN
                rts



hex_input:      ldx     input_pointer
                sta     input,x         ; store char in input
                jsr     JMP_PUTC        ; overwrite the char on screen
                cpx     #1
                beq     .last_pos
                inc     input_pointer
                rts
.last_pos:      jsr     cursor_Left
                rts

reset_input:    stz     input
                stz     input+1
                stz     input_pointer
                rts



update_cell:    beq     .no_adj
                jsr     move_to_cell

                pha
                ldy     cell            ; cell before moving
                lda     (edit_page),y
                jsr     JMP_PRINT_HEX
                pla

                sta     tmp1
                clc
                lda     cell
                adc     tmp1
                sta     cell
.no_adj:        jsr     reset_input     ; fall through to move_to_cell


move_to_cell:   pha
                jsr     cursor_home
                jsr     cursor_down
                ldx     #6
.loop:          jsr     cursor_right
                dex
                bne     .loop

.hor_adjust:    lda     cell
                and     #LOW_NIBBLE      ; only keep low nibble
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
.done           pla
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