JUMP_TABLE_ADDR         = $300
JMP_RCV:                = JUMP_TABLE_ADDR + 0
JMP_INIT_SCREEN:        = JUMP_TABLE_ADDR + 3
JMP_RUN:                = JUMP_TABLE_ADDR + 6
JMP_RESET:              = JUMP_TABLE_ADDR + 9
JMP_PUTC:               = JUMP_TABLE_ADDR + 12
JMP_PRINT_HEX:          = JUMP_TABLE_ADDR + 15
JMP_XMODEM_RCV:         = JUMP_TABLE_ADDR + 18
JMP_GETC:               = JUMP_TABLE_ADDR + 21
JMP_INIT_KB:            = JUMP_TABLE_ADDR + 24
JMP_LINE_INPUT:         = JUMP_TABLE_ADDR + 27
JMP_IRQ_HANDLER:        = JUMP_TABLE_ADDR + 30
JMP_NMI_HANDLER:        = JUMP_TABLE_ADDR + 33
JMP_INIT_SERIAL:        = JUMP_TABLE_ADDR + 36
JMP_CURSOR_ON:          = JUMP_TABLE_ADDR + 39
JMP_CURSOR_OFF:         = JUMP_TABLE_ADDR + 42
JMP_DRAW_PIXEL:         = JUMP_TABLE_ADDR + 45
JMP_RMV_PIXEL:          = JUMP_TABLE_ADDR + 48
JMP_INIT_STORAGE:       = JUMP_TABLE_ADDR + 51
JMP_STOR_READ:          = JUMP_TABLE_ADDR + 54
JMP_STOR_WRITE:         = JUMP_TABLE_ADDR + 57

stor_eeprom_addr_h      = $0E
stor_ram_addr_h         = $10
stor_current_page       = $40           ; reserve
rcv_size                = $41
rcv_page                = $42

LAST_PAGE               = $FF

                .org    $1000

                ldx     #0
clear_buffer:   stz     $0400,x
                inx
                bne     clear_buffer

                ; don't make the first 5 pages available
                lda     #$FF
                sta     $0400
                sta     $0401
                sta     $0402
                sta     $0403
                sta     $0404

; write this new clear FAT buffer from RAM to the drive
clear_fat:      ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #4
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE


; set up 3 pages of data to copy to a file
                lda     #3
                sta     rcv_size
                lda     #6
                sta     rcv_page

                ldx     #0
fill_buffer:    lda     #1
                sta     $0600,x
                lda     #2
                sta     $0700,x
                lda     #3
                sta     $0800,x
                inx
                bne     fill_buffer


;====================================================================================
;               Read the FAT from the EEPROM into RAM
;====================================================================================
init:           jsr     read_fat

;====================================================================================
;               Save a new file to EEPROM
;               Start reading from RAM at page held at rcv_page
;               Read number of pages held at rcv_size
;====================================================================================
save_file:      ldy     rcv_size
.save_page:     ldx     #1              ; one page at a time

                ; set the current page as target
                lda     stor_current_page
                sta     stor_eeprom_addr_h

                ; the page in RAM to save
                lda     rcv_page
                sta     stor_ram_addr_h

                jsr     JMP_STOR_WRITE  ; write the page

                ; note: this needs to be here because find_empty_page needs to
                ; not find this page as an empty one
                lda     #LAST_PAGE        ; mark as last page
                ldx     stor_current_page ; if it's not, it'll be updated after
                sta     $0400,x           ; store at the right offset in the FAT in RAM

                dey
                beq     .done

                inc     rcv_page   ; to read the next page when looping again
                jsr     find_empty_page     ; find the next available page in the EEPROM
                ldx     stor_current_page   ; 
                sta     $0400,x             ; current page in FAT points to next avail page
                sta     stor_current_page   ; update the current page pointer for the next loop

                bra     .save_page
.done           jsr     save_fat        ; all done, save the updated FAT back to the EEPROM
                rts

;============================================================
; Find the next empty page in the FAT
find_empty_page:phx
                ldx     #0
.loop:          lda     $0400,x
                beq     found
                inx
                bra     .loop

                ; this should have found page 5 when the FAT is empty
found:          txa
                plx
                rts

                ; read the FAT into RAM page 4
read_fat:       phx
                pha
                ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #4
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_READ

                ; set the current page to the first empty page
                jsr     find_empty_page
                sta     stor_current_page

                pla
                plx
                rts

save_fat:       phx
                pha
                ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #4
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE

                pla
                plx
                rts
