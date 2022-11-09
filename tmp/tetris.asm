    .include "../../pager_os/build/pager_os/pager_os.inc"

T1CL            = $6004
T1CH            = $6005
ACR             = $600B
IFR             = $600D
IER             = $600E

rotation        =       $3d
piece           =       $3e
piece_x         =       $40
piece_y         =       $41
cell_x          =       $42
cell_y          =       $43
pixel_rtn       =       $44             ; 2 bytes
cell_rtn        =       $46             ; 2 bytes
last_ticks      =       $54             ; ticks at last continue
game_delay      =       $55             ; how many ticks between move down (game speed)
flags           =       $56             ; bit 0: exit, bit 1: drop

; flags
EXIT            =       1
DROP            =       2
GAME_OVER       =       4

                .org    $0600

init_game:      jsr     JMP_CURSOR_OFF
                lda     #12             ; clear screen
                jsr     JMP_PUTC
                jsr     draw_borders
                lda     #50
                sta     game_delay
                stz     flags
                jsr     clear_grid
                jsr     spawn
                jmp     loop
                
clear_grid:     ldx     #0
.loop:          stz     rows,x
                cpx     #250
                beq     .done
                inx
                bra     .loop
.done:          rts



spawn:          lda     #5
                sta     piece_x
                lda     #0
                sta     piece_y
                jsr     select_piece
                jsr     verify_piece
                bcc     .draw
                rts                     ; unable to spawn: end of game
.draw:          jsr     draw_piece
                clc
                rts

;============================================================
; select a piece to spawn
;============================================================
select_piece:   ldy     ticks
                ldx     #13
.loop2:         lda     pieces,x
                sta     piece+1
                dex
                lda     pieces,x
                sta     piece
                dex
                bpl     .next
                ldx     #13
.next:          dey
                bne     .loop2
                rts

;============================================================
; the main loop of the game
;============================================================
loop:           jsr     handle_input
                jsr     timed_down
                bcs     .exit           ; game over
                bbr0    flags, loop     ; bit 0: exit
.exit:          jsr     JMP_CURSOR_ON
                lda     #12             ; clear screen
                jsr     JMP_PUTC
                rts

;============================================================
; handle input from keyboard:
;    space:         rotate piece
;    left arrow:    move piece left
;    right arrow:   move piece right
;============================================================
handle_input:   lda     $6000           ; has key? todo: make nonblocking OS call for this
                bpl     .done
                jsr     JMP_GETC
                cmp     #" "            ; space to rotate
                bne     .left_q
                jsr     rotate
.left_q:        cmp     #29
                bne     .right_q
                jsr     move_left
                bra     .done
.right_q:       cmp     #28
                bne     .down_q
                jsr     move_right
.down_q         cmp     #31
                bne     .exit_q
                jsr     drop_piece
.exit_q:        cmp     #"q"
                bne     .done
                lda     flags
                ora     #EXIT
                sta     flags
.done           rts

;============================================================
; Move the piece to the left
;============================================================
move_left:      dec     piece_x
                jsr     verify_piece
                bcc     .do_move
                inc     piece_x
                rts
.do_move:       inc     piece_x
                jsr     clear_piece
                dec     piece_x
                jsr     draw_piece
                rts

;============================================================
; Move the piece to the right
;============================================================
move_right:     inc     piece_x
                jsr     verify_piece
                bcc     .do_move
                dec     piece_x
                rts
.do_move:       dec     piece_x
                jsr     clear_piece
                inc     piece_x
                jsr     draw_piece
                rts

drop_piece:     lda     flags
                ora     #DROP
                sta     flags
                rts
;============================================================
; Move the piece down. If it can't move down further, spawn
; a new block
;============================================================
move_down:      inc     piece_y
                jsr     verify_piece
                bcc     .do_move
                dec     piece_y         ; undo the inc
                lda     flags           ; reset the drop flag
                and     #~DROP
                sta     flags
                jsr     lock_piece      ; write the coordinates to the proper cells
                jsr     collapse_rows
                jsr     spawn
                bcc     .done
                rts
.do_move:       dec     piece_y
                jsr     clear_piece
                inc     piece_y
                jsr     draw_piece
.done           rts
;============================================================
; move the piece down using the ticks timer and
; a speed (delay) variable
;============================================================
timed_down:     bbs1    flags, .drop    ; skip delay if drop flag set
                lda     ticks
                sbc     last_ticks
                cmp     game_delay
                bcc     .done
.drop:          lda     ticks
                sta     last_ticks
                jsr     move_down
.done:          rts

rotate:         jsr     do_rotate
                jsr     verify_piece
                bcs     .no_rotate
                jsr     undo_rotate
                jsr     clear_piece
                jsr     do_rotate
                jsr     draw_piece
                bra     .done
.no_rotate:     jsr     undo_rotate
.done:          rts

do_rotate:      clc
                lda     rotation
                adc     #2
                and     #%00000111      ; rollover at 8
                sta     rotation
                rts

undo_rotate:    jsr     do_rotate
                jsr     do_rotate
                jsr     do_rotate
                rts

;===========================================================================
; Handle piece at position stored at cell_x and cell_y.
; This routine reads the piece bytes and calcuates the
; coordinates of the separate blocks that make up the
; piece.
;===========================================================================
draw_piece      lda     #<draw_cell
                sta     cell_rtn
                lda     #>draw_cell
                sta     cell_rtn+1
                jmp     handle_piece
clear_piece:    lda     #<erase_cell
                sta     cell_rtn
                lda     #>erase_cell
                sta     cell_rtn+1
                jmp     handle_piece
verify_piece:   lda     #<verify_cell
                sta     cell_rtn
                lda     #>verify_cell
                sta     cell_rtn+1
                jmp     handle_piece
lock_piece:     lda     #<lock_cell
                sta     cell_rtn
                lda     #>lock_cell
                sta     cell_rtn+1
handle_piece:   lda     piece_y         ; start drawing from the top
                sta     cell_y         ; coordinate of the piece
                ldy     rotation
                lda     (piece),y       ; first byte of piece to draw
                jsr     handle_byte
                bcs     .done
                inc     cell_y         ; move one down for each nibble
                iny
                lda     (piece),y       ; second byte of piece to draw
                jsr     handle_byte      ; todo: remove jsr / rts?
.done:          rts

;===========================================================================
; Handle one byte (two rows) of a piece
;===========================================================================
handle_byte:    phy
                jsr     handle_nibble    ; split into two nibbles, and
                bcs     .done
                inc     cell_y         ; move one down for each nibble
                jsr     handle_nibble    ; increment y pos in between
.done:          ply
                rts

;===========================================================================
; Handle one nibble (row) of a piece
;===========================================================================
handle_nibble:  ldx     #4
                ldy     piece_x         ; return to left coordinate of piece
                sty     cell_x
.bit_loop:      asl                     ; next bit into carry
                bcc     .empty_cell
                jsr     handle_cell
                bcs     .done           ; carry set means error: return and keep the carry flag
.empty_cell:    inc     cell_x         ; move one block to the right
                dex
                bne     .bit_loop
.done:          rts


;===========================================================================
; This is called by handle_nibble, and calls this for each bit in a nibble.
; cell_rtn is set before calling this, and can be either verify_cell,
; erase_cell, or draw_cell. This indirection is needed because the
; 6502 doesn't have an indirect jsr operation, so it's done by jsr-ing to
; this routine that does an indirect jmp
;===========================================================================
handle_cell:    jmp     (cell_rtn)

;===========================================================================
; This draws a block by setting pixel_rtn to JMP_DRAW_PIXEL and caling
; update_block
;===========================================================================
draw_cell:      pha
                lda     #<JMP_DRAW_PIXEL
                sta     pixel_rtn
                lda     #>JMP_DRAW_PIXEL
                sta     pixel_rtn+1
                jsr     update_block
                pla
                clc                     ; always success
                rts

;===========================================================================
; This clears a block by setting pixel_rtn to JMP_RMV_PIXEL and caling
; update_block
;===========================================================================
erase_cell:     pha
                lda     #<JMP_RMV_PIXEL
                sta     pixel_rtn
                lda     #>JMP_RMV_PIXEL
                sta     pixel_rtn+1
                jsr     update_block
                pla
                clc                     ; always success
                rts

;===========================================================================
; This verifies if a block can be placed at the given coordinate. If the
; verification fails, the carry flag is set. Otherwise it's cleared.
; Verifications:
;   - Does the block fall outside the side walls
;===========================================================================
verify_cell:    pha
                lda     cell_x
                cmp     #-1             ; to left of left wall
                beq     .fail
                cmp     #10             ; to right of right wall
                beq     .fail
                lda     cell_y         ; bottom
                cmp     #25
                beq     .fail
                jsr     cell_filled
                bcs     .fail
                bra     .success
.fail:          sec
.success:       pla
                rts

;===========================================================================
; This locks a block into place when it can't move down further
; This saves the coordinates of the block to the grid by transforming
; its coordinates (cell_x, cell_y) to a cell in the grid and set that
; cell to 1.
;===========================================================================
lock_cell:      pha
                phx
                jsr     cell_index
                lda     #1
                sta     rows, x
                plx
                pla
                rts

free_cell:      pha
                phx
                jsr     cell_index
                stz     rows, x
                plx
                pla
                rts

cell_filled:    pha
                phx
                jsr     cell_index
                lda     rows, x
                ror                     ; if cell is filled, this rotates 1 into carry
                plx
                pla
                rts

cell_index:     clc
                ldx     cell_y
                lda     row_indeces, x
                adc     cell_x
                tax
                rts
;===========================================================================
; Update a block at the position stored in cell_x and cell_y.
; This either draws or clears a block, depending on the method
; stored at pixel_rtn.
; These are positions within the grid, not pixels, so this routine
; needs to calculate the pixel positions from the grid coordinates.
;===========================================================================
update_block:   pha
                phx
                phy
                lda     cell_x
                asl
                asl
                adc     #60             ; offset 60 because that's where the grid is
                tax
                lda     cell_y
                asl
                asl
                tay

                jsr     handle_pixel
                inx
                jsr     handle_pixel
                inx
                jsr     handle_pixel
                dex
                dex
                iny
                jsr     handle_pixel
                inx
                inx
                jsr     handle_pixel
                dex
                dex
                iny
                jsr     handle_pixel
                inx
                jsr     handle_pixel
                inx
                jsr     handle_pixel
                ply
                plx
                pla
                rts


handle_pixel:   jmp     (pixel_rtn)

;===========================================================================
; Go over all rows and collapse complete rows
;===========================================================================
collapse_rows:  ldx     #24
.next_row       jsr     verify_row
                bcc     .not_complete
                jsr     move_rows_down  ; move the rows above this
                bra     .next_row
.not_complete:  dex
                bne     .next_row
                rts
;===========================================================================
; Verify if a row is complete
; X contains the index into the row to verify
;
; Carry set: complete
; Carry clear: not complete
;===========================================================================
verify_row:     phx
                lda     row_indeces,x
                tax
                ldy     #10
.next_cell:     lda     rows,x
                beq     .not_complete
                inx
                dey
                bne     .next_cell
                sec
                bra     .done
.not_complete   clc
.done:          plx
                rts

move_rows_down: phx
                dex     ; the row above the completed
.next_row:      jsr     move_row_down
                dex
                bne     .next_row
                plx
                rts

;===========================================================================
; Move a row down by copying and redrawingall its cells
; one row lower. This is used when a completed row is
; removed and the ones above it are moved down.
; Example, when row 24 is complete, row 23 is moved to 24,
; 22 is moved to 23 etc.
;
; x contains the completed row, so the one above it needs to
; move down
;===========================================================================
move_row_down:  pha
                phx
                phy
                stx     cell_y     
                stz     cell_x          ; start from x=0 (left)
.loop:          jsr     cell_filled     ; is the above cell filled?
                bcc     .erase          ; if the source row is empty, erase the one below
                inc     cell_y          ; inc to draw/erase a cell in the row below
                jsr     cell_filled     ; is the target cell filled?
                bcs     .next           ; already filled, no need to fill
                jsr     draw_cell
                jsr     lock_cell
                bra     .next
.erase:         inc     cell_y
                jsr     cell_filled
                bcc     .next           ; already empty, no need to erase
                jsr     erase_cell
                jsr     free_cell
.next:          dec     cell_y
                inc     cell_x          ; next cell to the right
                lda     cell_x
                cmp     #10
                bne     .loop
.done:          ply
                plx
                pla
                rts

draw_borders:   ldx     #58
                jsr     vline
                ldx     #100
                jsr     vline
                rts

hline:          ldx     #0
.loop:          jsr     JMP_DRAW_PIXEL
                inx
                cpx     #160
                bne     .loop

.done:          rts

vline:          ldy     #0
.loop:          jsr     JMP_DRAW_PIXEL
                iny
                cpy     #100
                bne     .loop

.done:          rts

pieces:         .word   piece_l, piece_i, piece_j, piece_o, piece_s
                .word   piece_t, piece_z

piece_l:        .byte   %00101110, %00000000
                .byte   %10001000, %11000000
                .byte   %11101000, %00000000
                .byte   %11000100, %01000000
piece_i:        .byte   %10001000, %10001000
                .byte   %11110000, %00000000
                .byte   %10001000, %10001000
                .byte   %11110000, %00000000
piece_j:        .byte   %10001110, %00000000
                .byte   %11001000, %10000000
                .byte   %11100010, %00000000
                .byte   %01000100, %11000000
piece_o:        .byte   %11001100, %00000000
                .byte   %11001100, %00000000
                .byte   %11001100, %00000000
                .byte   %11001100, %00000000
piece_s:        .byte   %01101100, %00000000
                .byte   %10001100, %01000000
                .byte   %01101100, %00000000
                .byte   %10001100, %01000000
piece_t:        .byte   %01001110, %00000000
                .byte   %10001100, %10000000
                .byte   %11100100, %00000000
                .byte   %01001100, %01000000
piece_z:        .byte   %11000110, %00000000
                .byte   %01001100, %10000000
                .byte   %11000110, %00000000
                .byte   %01001100, %10000000

row_indeces:    .byte   0,   10,  20,  30,  40
                .byte   50,  60,  70,  80,  90
                .byte   100, 110, 120, 130, 140
                .byte   150, 160, 170, 180, 190
                .byte   200, 210, 220, 230, 240

rows:           ; 250 bytes are set to 0 on init