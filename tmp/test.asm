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
FAT_BUFFER              = $0400
DIR_BUFFER              = $0500
__INPUTBFR_START__      = $B0

                .org    $1000

                ; jsr     clear_fat
                ; jsr     clear_dir
                

; add a filename to the input buffer. Later this will have to come from user input
                ldx     #0
.loop:          lda     test_file_name,x
                beq     .done
                sta     __INPUTBFR_START__,x
                inx
                bra     .loop
.done:

; pretend we have received 3 pages into RAM
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
                jsr     load_dir 
;====================================================================================
;               Save a new file to EEPROM
;               Start reading from RAM at page held at rcv_page
;               Read number of pages held at rcv_size
;====================================================================================

save_file:      jsr     find_empty_dir  ; x contains entry index
                bcs     .drive_full
                jsr     add_to_dir
                
                ldy     rcv_size
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
                sta     FAT_BUFFER,x     ; store at the right offset in the FAT in RAM

                dey
                beq     .done

                inc     rcv_page   ; to read the next page when looping again
                jsr     find_empty_page     ; find the next available page in the EEPROM
                ldx     stor_current_page   ; 
                sta     FAT_BUFFER,x        ; current page in FAT points to next avail page
                sta     stor_current_page   ; update the current page pointer for the next loop

                bra     .save_page
.done           jsr     save_fat        ; all done, save the updated FAT back to the EEPROM
                jsr     save_dir        ; save the updated directory
                clc                     ; success
.drive_full:    rts


;============================================================
;               Find the next empty page in the FAT
;============================================================
find_empty_page:phx
                ldx     #0
.loop:          lda     FAT_BUFFER,x
                beq     found
                inx
                bra     .loop

                ; this should have found page 5 when the FAT is empty
found:          txa
                plx
                rts

;============================================================
;               Clear the FAT
;============================================================
clear_fat:      ldx     #0
.clear_buffer:  stz     FAT_BUFFER,x
                inx
                bne     .clear_buffer

                ; don't make the first 5 pages available
                lda     #$FF
                sta     FAT_BUFFER+0
                sta     FAT_BUFFER+1
                sta     FAT_BUFFER+2
                sta     FAT_BUFFER+3
                sta     FAT_BUFFER+4

                ; write this new clear FAT buffer from RAM to the drive
                ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE
                rts

;============================================================
;               Read FAT into RAM
;============================================================
read_fat:       phx
                pha
                ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_READ

                ; set the current page to the first empty page
                jsr     find_empty_page
                sta     stor_current_page

                pla
                plx
                rts

;============================================================
;               Save updated FAT to the drive
;============================================================
save_fat:       phx
                pha
                ldx     #1                  ; page count
                stz     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE

                pla
                plx
                rts

;============================================================
;               Clear the whole directory
;============================================================
clear_dir:      ldx     #0
.clear_buffer:  stz     DIR_BUFFER,x
                inx
                bne     .clear_buffer

                ldy     #4              ; dir takes up 4 pages
.clear_page:    ldx     #1                  ; page count
                sty     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>DIR_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE
                dey
                bne     .clear_page     ; don't do page 0 because that's FAT
                rts

;===============================================================
;               Find an empty spot in the directory
;===============================================================
find_empty_dir: ldx     #0
.try_next:      lda     DIR_BUFFER,x
                beq     .found
                txa
                clc
                adc     #16
                tax
                beq     .not_found
                bra     .try_next                
.found:         txa
                jsr     JMP_PRINT_HEX
                clc                     ; "found" flag
                rts
.not_found:     sec
                rts



;===============================================================
;               Load a page from the directory into RAM
;===============================================================
load_dir:       ldx     #1                  ; page count
                lda     #1                  ; first dir page
                sta     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>DIR_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_READ
                rts

save_dir:       phx
                pha
                ldx     #1                  ; page count
                lda     #1                  ; first dir page
                sta     stor_eeprom_addr_h  ; page 0 in eeprom
                lda     #>DIR_BUFFER
                sta     stor_ram_addr_h     ; where we stored the 0s
                jsr     JMP_STOR_WRITE
                pla
                plx
                rts


;===============================================================
;               Add a file to the directory
;               X contains the start of the first free dir entry
;                 in page 5 (ie 32 for the 3rd entry)
;               The inputbuffer is used to read a filename
;===============================================================
; x contains the start of the first free dir entry in page 5 (ie 32 for the 3rd entry)
add_to_dir:     ldy     #0
                phx                     ; keep this for a bit later when we save the page number
.loop:          lda     __INPUTBFR_START__,y
                beq     .done
                sta     DIR_BUFFER,x
                inx
                iny
                cpy     #9              ; max length is 8
                bne     .loop
.done:          plx                     ; the index to the start of the entr
                txa
                clc
                adc     #8
                tax
                lda     stor_current_page
                sta     DIR_BUFFER,x
                rts


test_file_name: .byte "filenamezzz", 0