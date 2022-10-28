    .include "../../pager_os/build/pager_os/pager_os.inc"

T1CL            = $6004
T1CH            = $6005
ACR             = $600B
IFR             = $600D
IER             = $600E


piece_x         =       $40
piece_y         =       $41
block_x         =       $42
block_y         =       $43
pixel_rtn       =       $44             ; 2 bytes
block_rtn       =       $46
ticks           =       $50             ; 4 bytes
toggle_time     =       $54

                .org $0600

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

                lda     #0
                sta     piece_x
                lda     #0
                sta     piece_y

loop:           sec
                lda     ticks
                sbc     toggle_time
                cmp     #25             ; 250ms
                bcc     loop
                jsr     move_piece
                lda     ticks
                sta     toggle_time
                jmp     loop

move_piece:     jsr     clear_piece
                inc     piece_y
                jsr     draw_piece
                rts
                
;===========================================================================
; Draw piece at position stored at block_x and block_y.
; This routine reads the piece bytes and calcuates the
; coordinates of the separate blocks that make up the
; piece. It calls draw_block with the grid coordinates
; for the actual drawing of the individual block.
;===========================================================================
draw_piece      lda     #<draw_block
                sta     block_rtn
                lda     #>draw_block
                sta     block_rtn + 1
                jmp     update_piece
clear_piece:    lda     #<clear_block
                sta     block_rtn
                lda     #>clear_block
                sta     block_rtn + 1
update_piece:   lda     piece_y         ; start drawing from the top
                sta     block_y         ; coordinate of the piece
                lda     piece           ; first byte of piece to draw
                jsr     .draw_byte
                inc     block_y         ; move one down for each nibble
                lda     piece+1         ; second byte of piece to draw
                jsr     .draw_byte      ; todo: remove jsr / rts?
                rts
.draw_byte:     beq     .done           ; empty byte, save some time
                jsr     .draw_nibble    ; split into two nibbles, and
                inc     block_y         ; move one down for each nibble
                jsr     .draw_nibble    ; increment y pos in between
                rts
.draw_nibble:   ldx     #4
                ldy     piece_x         ; return to left coordinate of piece
                sty     block_x
.bit_loop:      asl                     ; next bit into carry
                bcc     .empty_block
                jsr     block_jump
.empty_block:   inc     block_x         ; move one block to the right
                dex
                bne     .bit_loop
.done:          rts

block_jump:     jmp     (block_rtn)

;===========================================================================
; Draw a block at the position stored in block_x and block_y.
; These are positions within the grid, not pixels, so this routine
; needs to calculate the pixel positions from the grid coordinates.
;===========================================================================
draw_block:     pha
                phx
                phy
                lda     #<JMP_DRAW_PIXEL
                sta     pixel_rtn
                lda     #>JMP_DRAW_PIXEL
                sta     pixel_rtn+1
                jmp     _update_block
clear_block:    pha
                phx
                phy
                lda     #<JMP_RMV_PIXEL
                sta     pixel_rtn
                lda     #>JMP_RMV_PIXEL
                sta     pixel_rtn+1
_update_block:  lda     block_x
                asl
                asl
                tax
                lda     block_y
                asl
                asl
                tay

                jsr     pixel_jump
                inx
                jsr     pixel_jump
                inx
                jsr     pixel_jump
                dex
                dex
                iny
                jsr     pixel_jump
                inx
                jsr     pixel_jump
                inx
                jsr     pixel_jump
                dex
                dex
                iny
                jsr     pixel_jump
                inx
                jsr     pixel_jump
                inx
                jsr     pixel_jump
                ply
                plx
                pla
                rts


pixel_jump:     jmp     (pixel_rtn)


irq:            bit     T1CL            ; clear T1 interrupt
                inc     ticks
                bne     .done
                inc     ticks + 1
                bne     .done
                inc     ticks + 2
                bne     .done
                inc     ticks + 3
.done:          rti

; borders:        ldy     #0
;                 jsr     hline
;                 ldy     #99
;                 jsr     hline
;                 ldx     #0
;                 jsr     vline
;                 ldx     #159
;                 jsr     vline
;                 rts



; hline:          ldx     #0
; .loop:          jsr     JMP_DRAW_PIXEL
;                 inx
;                 cpx     #160
;                 bne     .loop

; .done:          rts

; vline:          ldy     #0
; .loop:          jsr     JMP_DRAW_PIXEL
;                 iny
;                 cpy     #100
;                 bne     .loop

; .done:          rts


piece:          .byte   %00101110, %00000000    ;   #
                                                ; ###
