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
block_x         =       $42
block_y         =       $43
pixel_rtn       =       $44             ; 2 bytes
block_rtn       =       $46
ticks           =       $50             ; 4 bytes
toggle_time     =       $54
game_delay      =       $55
temp            =       $56             ; 2 bytes
halt            =       $58
temp2           =       $5a

                .org    $0600

                lda     #<irq
                sta     JMP_IRQ_HANDLER + 1
                lda     #>irq
                sta     JMP_IRQ_HANDLER + 2

init_timer:     lda     #%01000000      ; T1 free run mode
                sta     ACR
                lda     #$0e            ; every 10ms @ 1Mhz
                sta     T1CL
                lda     #$27
                sta     T1CH
                lda     #%11000000      ; enable interrupt for T1
                sta     IER
                stz     ticks
                stz     ticks + 1
                stz     ticks + 2
                stz     ticks + 3
                stz     toggle_time
                cli

init_game:      jsr     JMP_CURSOR_OFF
                lda     #12             ; clear screen
                jsr     JMP_PUTC
                jsr     draw_borders
                lda     #10
                sta     game_delay
                stz     halt
                jsr     spawn
                jmp     loop
                
spawn:          lda     #5
                sta     piece_x
                lda     #0
                sta     piece_y
                jsr     select_piece
                jsr     draw_piece
                rts

;============================================================
; the main loop of the game
;============================================================
loop:           jsr     handle_input
                jsr     timed_down
                lda     halt
                beq     loop
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
                bne     .done
                jsr     move_right
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

;============================================================
; Move the piece down. If it can't move down further, spawn
; a new block
;============================================================
move_down:      inc     piece_y
                jsr     verify_piece
                bcc     .do_move
                dec     piece_y
                jsr     lock_piece      ; write the coordinates to the proper cells
                jsr     spawn
                bra     .done
.do_move:       dec     piece_y
                jsr     clear_piece
                inc     piece_y
                jsr     draw_piece
.done           rts
;============================================================
; move the piece down using the ticks timer and
; a speed (delay) variable
;============================================================
timed_down:     lda     ticks
                sbc     toggle_time
                cmp     game_delay
                bcc     .done
                lda     ticks
                sta     toggle_time
                jsr     move_down
.done:          rts

select_piece:   lda     #<piece_j
                sta     piece
                lda     #>piece_j
                sta     piece + 1
                rts

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
; Handle piece at position stored at block_x and block_y.
; This routine reads the piece bytes and calcuates the
; coordinates of the separate blocks that make up the
; piece.
;===========================================================================
draw_piece      lda     #<draw_block
                sta     block_rtn
                lda     #>draw_block
                sta     block_rtn+1
                jmp     handle_piece
clear_piece:    lda     #<clear_block
                sta     block_rtn
                lda     #>clear_block
                sta     block_rtn+1
                jmp     handle_piece
verify_piece:   lda     #<verify_block
                sta     block_rtn
                lda     #>verify_block
                sta     block_rtn+1
                jmp     handle_piece
lock_piece:     lda     #<lock_block
                sta     block_rtn
                lda     #>lock_block
                sta     block_rtn+1
handle_piece:   lda     piece_y         ; start drawing from the top
                sta     block_y         ; coordinate of the piece
                ldy     rotation
                lda     (piece),y       ; first byte of piece to draw
                jsr     handle_byte
                bcs     .done
                inc     block_y         ; move one down for each nibble
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
                inc     block_y         ; move one down for each nibble
                jsr     handle_nibble    ; increment y pos in between
.done:          ply
                rts

;===========================================================================
; Handle one nibble (row) of a piece
;===========================================================================
handle_nibble:  ldx     #4
                ldy     piece_x         ; return to left coordinate of piece
                sty     block_x
.bit_loop:      asl                     ; next bit into carry
                bcc     .empty_block
                jsr     handle_block
                bcs     .done           ; carry set means error: return and keep the carry flag
.empty_block:   inc     block_x         ; move one block to the right
                dex
                bne     .bit_loop
.done:          rts


;===========================================================================
; This is called by handle_nibble, and calls this for each bit in a nibble.
; block_rtn is set before calling this, and can be either verify_block,
; clear_block, or draw_block. This indirection is needed because the
; 6502 doesn't have an indirect jsr operation, so it's done by jsr-ing to
; this routine that does an indirect jmp
;===========================================================================
handle_block:   jmp     (block_rtn)

;===========================================================================
; This draws a block by setting pixel_rtn to JMP_DRAW_PIXEL and caling
; update_block
;===========================================================================
draw_block:     pha
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
clear_block:    pha
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
verify_block:   pha
                lda     block_x
                cmp     #-1             ; to left of left wall
                beq     .fail
                cmp     #10             ; to right of right wall
                beq     .fail
                lda     block_y         ; bottom
                cmp     #25
                beq     .fail
                jsr     has_block
                bcs     .fail
                bra     .success
.fail:          sec
.success:       pla
                rts

;===========================================================================
; This locks a block into place when it can't move down further
; This saves the coordinates of the block to the grid by transforming
; its coordinates (block_x, block_y) to a cell in the grid and set that
; cell to 1.
;
; Steps:
;    1. for the y coordinate, get the address of the corresponding row.
;       Example, for the bottom row, this is `row24`. This address can be
;       found in the list of 16 bit addresses at `rows`. For `row24`, this
;       is the 48th and 49th byte after `rows`, or y*2 and (y*2)+1. So
;       loading these two value give the address of the start of the
;       correct row. This needs to be read into a temp value in RAM so
;       it can be accessed indirectly in the next step.
;    2. With the address of the start of the correct row in temp and temp+1,
;       we can index into that row with block_x
;===========================================================================
lock_block:     pha
                phx
                phy
                jsr     ref_row_addr
                lda     #1
                ldy     block_x
                sta     (temp2),y
                ; sta     halt
                ply                     ; always success
                plx
                pla
                rts

has_block:      pha
                phx
                phy
                jsr     ref_row_addr
                ldy     block_x
                lda     (temp2),y
                ror
                ply                     ; cell contains 1 when there's a block, rotate into carry
                plx
                pla
                rts

ref_row_addr:   clc
                lda     #<rows          ; low byte of `rows` in A
                adc     block_y         ; add block y twice
                adc     block_y
                sta     temp             ; store in temp
                lda     #0              ; add carry to high byte of `rows`
                adc     #>rows
                sta     temp+1           ; store in temp+1

                lda     (temp)            ; load from 08b5, this returns the high byte of the start address of the row
                sta     temp2
                ldy     #1
                lda     (temp),y
                sta     temp2+1

                rts
;===========================================================================
; Update a block at the position stored in block_x and block_y.
; This either draws or clears a block, depending on the method
; stored at pixel_rtn.
; These are positions within the grid, not pixels, so this routine
; needs to calculate the pixel positions from the grid coordinates.
;===========================================================================
update_block:   pha
                phx
                phy
                lda     block_x
                asl
                asl
                adc     #60             ; offset 60 because that's where the grid is
                tax
                lda     block_y
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
                jsr     handle_pixel
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


irq:            bit     T1CL            ; clear T1 interrupt
                inc     ticks
                bne     .done
                inc     ticks + 1
                bne     .done
                inc     ticks + 2
                bne     .done
                inc     ticks + 3
.done:          rti



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

rows:           .word   row00, row01, row02, row03, row04, row05, row06
                .word   row07, row08, row09, row10, row11, row12, row13
                .word   row14, row15, row16, row17, row18, row19, row20
                .word   row21, row22, row23, row24

row00:          .byte   0,0,0,0,0,0,0,0,0,0
row01:          .byte   0,0,0,0,0,0,0,0,0,0
row02:          .byte   0,0,0,0,0,0,0,0,0,0
row03:          .byte   0,0,0,0,0,0,0,0,0,0
row04:          .byte   0,0,0,0,0,0,0,0,0,0
row05:          .byte   0,0,0,0,0,0,0,0,0,0
row06:          .byte   0,0,0,0,0,0,0,0,0,0
row07:          .byte   0,0,0,0,0,0,0,0,0,0
row08:          .byte   0,0,0,0,0,0,0,0,0,0
row09:          .byte   0,0,0,0,0,0,0,0,0,0
row10:          .byte   0,0,0,0,0,0,0,0,0,0
row11:          .byte   0,0,0,0,0,0,0,0,0,0
row12:          .byte   0,0,0,0,0,0,0,0,0,0
row13:          .byte   0,0,0,0,0,0,0,0,0,0
row14:          .byte   0,0,0,0,0,0,0,0,0,0
row15:          .byte   0,0,0,0,0,0,0,0,0,0
row16:          .byte   0,0,0,0,0,0,0,0,0,0
row17:          .byte   0,0,0,0,0,0,0,0,0,0
row18:          .byte   0,0,0,0,0,0,0,0,0,0
row19:          .byte   0,0,0,0,0,0,0,0,0,0
row20:          .byte   0,0,0,0,0,0,0,0,0,0
row21:          .byte   0,0,0,0,0,0,0,0,0,0
row22:          .byte   0,0,0,0,0,0,0,0,0,0
row23:          .byte   0,0,0,0,0,0,0,0,0,0
row24:          .byte   0,0,0,0,0,0,0,0,0,0
