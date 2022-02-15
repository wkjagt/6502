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

                .org    $2000


                lda     #"w"
                jsr     JMP_PUTC
                lda     #"i"
                jsr     JMP_PUTC
                lda     #"l"
                jsr     JMP_PUTC
                lda     #"l"
                jsr     JMP_PUTC
                lda     #"e"
                jsr     JMP_PUTC
                lda     #"m"
                jsr     JMP_PUTC
                rts
                ; jmp $8648

; hex_to_byte             = $8412


; cell                    = $32           ; the cell the cursor is on
; edit_page               = $34           ; 2 bytes
; input                   = $36           ; 2 bytes
; input_pointer           = $38
; tmp1                    = $39
; incomplete_entry        = $40

; ESC                     = $1B
; RIGHT                   = $1C
; LEFT                    = $1D
; UP                      = $1E
; DOWN                    = $1F
; LF                      = $0A
; PGUP                    = $14
; PGDN                    = $15
; LOW_NIBBLE              = %00001111
; HIGH_NIBBLE             = %11110000

;                 .org $2000

; start:          stz     edit_page
;                 lda     #$20
;                 sta     edit_page+1
; .restart:       stz     cell
; .reload         jsr     reset_input
;                 jsr     JMP_INIT_SCREEN
;                 lda     edit_page+1
;                 jsr     JMP_DUMP        ; use dump as data view
;                 jsr     set_cursor
; .next_key:      jsr     JMP_GETC
;                 tax                     ; puts pressed char in X

; .cmp_right:     cpx     #RIGHT
;                 bne     .cmp_left
;                 lda     cell
;                 and     #LOW_NIBBLE     ; in rightmost column the four last bits are always set
;                 cmp     #LOW_NIBBLE
;                 beq     .next_key
;                 lda     #1
;                 jsr     update_cell
;                 jmp     .next_key

; .cmp_left:      cpx     #LEFT
;                 bne     .cmp_up
;                 lda     cell
;                 and     #LOW_NIBBLE     ; ignore the 4 highest bits
;                 beq     .next_key            ; last 4 bits need to have something set
;                 lda     #-1
;                 jsr     update_cell
;                 jmp     .next_key

; .cmp_up:        cpx     #UP
;                 bne     .cmp_down
;                 lda     cell
;                 and     #HIGH_NIBBLE    ; for the top row the high nibble is always 0
;                 beq     .next_key
;                 lda     #-16
;                 jsr     update_cell
;                 jmp     .next_key

; .cmp_down:      cpx     #DOWN
;                 bne     .cmp_hex
;                 lda     cell
;                 and     #HIGH_NIBBLE    ; for the bottom row, the high nibble is always 1111
;                 cmp     #HIGH_NIBBLE
;                 beq     .next_key
;                 lda     #16
;                 jsr     update_cell
;                 jmp     .next_key
                
; .cmp_hex:       cpx     #"0"
;                 bcc     .check_save
;                 cpx     #":"            ; next ascii after 9
;                 bcs     .capital
;                 txa
;                 jsr     hex_input
;                 jmp     .next_key
; .capital        cpx     #"A"
;                 bcc     .check_save
;                 cpx     #"G"
;                 bcs     .letter
;                 txa
;                 jsr     hex_input
;                 jmp     .next_key
; .letter:        cpx     #"a"
;                 bcc     .check_save
;                 cpx     #"g"
;                 bcs     .check_save
;                 txa
;                 sec
;                 sbc     #32             ; make capital letter
;                 jsr     hex_input
;                 jmp     .next_key

; .check_save:    cpx     #"s"
;                 bne     .check_esc
;                 lda     incomplete_entry
;                 bne     .next
;                 lda     #input
;                 jsr     hex_to_byte     ; byte into A
;                 ldy     cell
;                 sta     (edit_page), y
;                 jsr     reset_input
;                 jsr     JMP_INIT_SCREEN
;                 lda     edit_page+1
;                 jsr     JMP_DUMP
;                 jsr     set_cursor
;                 jmp     .next_key

; .check_esc      cpx     #ESC
;                 bne     .check_exit
;                 jmp     .reload

; .check_exit:    cpx     #"q"
;                 beq     .exit

; .check_pgup     cpx     #PGUP
;                 bne     .check_pgdn
;                 inc     edit_page+1
;                 jmp     .restart

; .check_pgdn     cpx     #PGDN
;                 bne     .next
;                 dec     edit_page+1
;                 jmp     .restart

; .next:          jmp     .next_key

; .exit:          jsr     JMP_INIT_SCREEN
;                 rts
; ; ================================================================================
; ;      A hex nibble was input. treat it here
; ; ================================================================================
; hex_input:      ldx     input_pointer
;                 sta     input,x         ; store char in input and
;                 jsr     JMP_PUTC        ; overwrite the char on screen
;                 cpx     #1
;                 beq     .last_pos
;                 lda     #"_"
;                 jsr     JMP_PUTC
;                 jsr     cursor_left
;                 inc     input_pointer
;                 rts
; .last_pos:      jsr     cursor_left
;                 stz     incomplete_entry
;                 rts

; reset_input:    stz     input
;                 stz     input+1
;                 stz     input_pointer
;                 lda     #1
;                 sta     incomplete_entry
;                 rts

; update_cell:    beq     .no_adj
;                 jsr     set_cursor

;                 pha
;                 ldy     cell            ; cell before moving
;                 lda     (edit_page),y
;                 jsr     JMP_PRINT_HEX
;                 pla

;                 sta     tmp1
;                 clc
;                 lda     cell
;                 adc     tmp1
;                 sta     cell
; .no_adj:        jsr     reset_input     ; fall through to set_cursor


; set_cursor:     pha
;                 jsr     cursor_home
;                 jsr     cursor_down
;                 ldx     #6
; .to_start:      jsr     cursor_right
;                 dex
;                 bne     .to_start

; .hor_adjust:    lda     cell
;                 and     #LOW_NIBBLE      ; only keep low nibble
;                 tax
;                 beq     .ver_adjust
; .right:         jsr     cursor_right
;                 jsr     cursor_right
;                 jsr     cursor_right
;                 dex
;                 bne     .right

;                 ; if we're at the right of the separation, we need to move one
;                 ; more position to the right. 
;                 lda     cell
;                 and     #%00001000      ; on the right side, bit 3 is always set
;                 beq     .ver_adjust
;                 jsr     cursor_right

; .ver_adjust:    lda     cell
;                 lsr                     ; only keep high nibble
;                 lsr
;                 lsr
;                 lsr
;                 tax
;                 beq     .done
; .down:          jsr     cursor_down
;                 dex
;                 bne     .down
; .done           pla
;                 rts


; cursor_home:    lda     #$01
;                 jsr     JMP_PUTC
;                 rts
; cursor_right:   lda     #$1C
;                 jsr     JMP_PUTC
;                 rts
; cursor_left:    lda     #$1D
;                 jsr     JMP_PUTC
;                 rts
; cursor_down:    lda     #$1F
;                 jsr     JMP_PUTC
;                 rts

; text:
;                 .byte "This is a program!",0