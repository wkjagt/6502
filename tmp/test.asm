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
READ_PAGE:              = JUMP_TABLE_ADDR + 60
WRITE_PAGE:             = JUMP_TABLE_ADDR + 63
JMP_GET_INPUT:          = JUMP_TABLE_ADDR + 66

drive_page              = $10
ram_page                = $12
stor_current_page       = $40           ; reserve
rcv_size                = $00           ; for realsies
rcv_page                = $01           ; for realsies
error_code              = $43
dir_page                = $44           ; the current dir page read from drive
                                        ; values: 1-4

LAST_PAGE               = $FF
FAT_BUFFER              = $0400
DIR_BUFFER              = $0500
MAX_FILE_NAME_LEN       = 8

ERR_DIR_FULL            = 1
ERR_DRIVE_FULL          = 2
ERR_FILE_NOT_FOUND      = 3
ERR_FILE_EXISTS         = 4

__INPUTBFR_START__      = $B0

                .org    $0600

                ; jsr     clear_fat
                ; jsr     clear_dir
                ; rts

; add a filename to the input buffer. Later this will have to come from user input
;                 ldx     #0
; .loop:          lda     test_file_name,x
;                 beq     .done
;                 sta     __INPUTBFR_START__,x
;                 inx
;                 bra     .loop
; .done:

; pretend we have received 3 pages into RAM
;                 lda     #3
;                 sta     rcv_size
;                 lda     #6
;                 sta     rcv_page

;                 ldx     #0
; fill_buffer:    lda     #1
;                 sta     $0600,x
;                 lda     #2
;                 sta     $0700,x
;                 lda     #3
;                 sta     $0800,x
;                 inx
;                 bne     fill_buffer


;====================================================================================
;               Read the FAT from the EEPROM into RAM
;====================================================================================
init:           lda     #1
                sta     dir_page
                jsr     load_fat
                jsr     load_dir
                ; rts
save:           jsr     JMP_GET_INPUT
                jsr     save_file
                rts

load:           jsr     JMP_GET_INPUT
                jsr     load_file
                rts


;====================================================================================
;               Save a new file to EEPROM
;               Start reading from RAM at page held at rcv_page
;               Read number of pages held at rcv_size
;====================================================================================

save_file:      jsr     find_file       ; to see if it exists already
                bcc     .file_exists
                jsr     find_empty_dir  ; x contains entry index
                bcs     .dir_full
                
                jsr     add_to_dir
                
                ldy     rcv_size
.save_page:     ; set the current page as target
                lda     stor_current_page
                sta     drive_page

                ; the page in RAM to save
                lda     rcv_page
                sta     ram_page

                jsr     WRITE_PAGE      ; write the page

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
                rts
.file_exists:   lda     ERR_FILE_EXISTS
                sta     error_code
                sec
                rts
.dir_full:      lda     ERR_DIR_FULL
                sta     error_code
                sec
                rts


;============================================================
;               Find the next empty page in the FAT
;============================================================
find_empty_page:phx
                ldx     #0
.loop:          lda     FAT_BUFFER,x
                beq     found
                inx
                bra     .loop
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
                sta     FAT_BUFFER+0    ; FAT
                sta     FAT_BUFFER+1    ; DIR 1
                sta     FAT_BUFFER+2    ; DIR 2
                sta     FAT_BUFFER+3    ; DIR 3
                sta     FAT_BUFFER+4    ; DIR 4

                ; write this new clear FAT buffer from RAM to the drive
                stz     drive_page      ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     ram_page        ; where we stored the 0s
                jsr     WRITE_PAGE
                rts

;============================================================
;               Read FAT into RAM
;============================================================
load_fat:       phx
                pha
                stz     drive_page      ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     ram_page        ; where we stored the 0s
                jsr     READ_PAGE

                ; set the current page to the first empty page
                jsr     find_empty_page
                sta     stor_current_page

                pla
                plx
                rts

;============================================================
;               Save updated FAT to the drive
;               This saves page 4 in RAM (the FAT buffer) to
;               page 0 on the EEPROM (where the FAT is stored)
;============================================================
save_fat:       phx
                pha
                stz     drive_page      ; page 0 in eeprom
                lda     #>FAT_BUFFER
                sta     ram_page
                jsr     WRITE_PAGE

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
.clear_page:    sty     drive_page
                lda     #>DIR_BUFFER
                sta     ram_page
                jsr     WRITE_PAGE
                dey
                bne     .clear_page     ; don't do page 0 because that's FAT
                rts

;===============================================================
;               Load a page from one of the 4 DIR pages of
;               the directory into RAM.
;===============================================================
load_dir:       jsr     dir_args
                jsr     READ_PAGE
                rts

save_dir:       phx                     ; todo: document why this is needed
                pha
                jsr     dir_args
                jsr     WRITE_PAGE
                pla
                plx
                rts

dir_args:       lda     dir_page
                sta     drive_page
                lda     #>DIR_BUFFER
                sta     ram_page        ; where we stored the 0s
                rts

;===============================================================
;               Add a file to the directory
;               X contains the start of the first free dir entry
;                 in page 5 (ie 32 for the 3rd entry)
;               The inputbuffer is used to read a filename
;               stor_current_page was initialized by load_fat to point
;               to the next empry page that can be written to
;
;               NOTE: this only interacts with the DIR buffer
;               currently in RAM. It doesn't need to know anything
;               about multiple DIR pages in a drive, because 
;               find_empty_dir is called first and sets X and dir_page
;===============================================================
add_to_dir:     ldy     #0
                phx                     ; keep this for a bit later when we save the page number
.loop:          lda     __INPUTBFR_START__,y
                sta     DIR_BUFFER,x
                inx
                iny
                cpy     #MAX_FILE_NAME_LEN + 1
                bne     .loop
.done:          plx                     ; the index to the start of the entr
                txa
                clc
                adc     #8
                tax
                lda     stor_current_page
                sta     DIR_BUFFER,x
                rts


;===========================================================================
;               Load file
;===========================================================================
load_file:      jsr     find_file
                bcs     .not_found
                lda     DIR_BUFFER+8,x  ; start page

                sta     drive_page  ; read from dir/fat
                lda     #6              ; default start page, todo: don't hardcode
                sta     ram_page
                
.next_page:     jsr     READ_PAGE

                ldx     drive_page
                lda     FAT_BUFFER,x    ; next page
                cmp     #$FF            ; last page
                beq     .done

                sta     drive_page
                inc     ram_page
                bra     .next_page
.done:          
.not_found:     rts

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
.found:         clc                     ; "found" flag
                rts
.not_found:     sec
                rts
                
;===========================================================================
;               Find a file in the directory buffer
;               When the file is found, carry is clear
;               and the X register points to the start of the entry.
;               When the file is not found, carry is set, and X
;               should be ignored.
;===========================================================================
find_file:      ldx     #0
.loop:          jsr     match_filename
                bcc     .found          ; carry clear means file found
                txa
                clc
                adc     #16
                tax
                bne     .loop
                sec                     ; set carry to signal file not found
.found:         rts

; x: pointer to start of dir entry in RAM
; return:
;     carry set:   no match
;     carry clear: matched
match_filename: phx
                phy
                ldy     #0
.loop:          lda    DIR_BUFFER,x
                cmp    __INPUTBFR_START__,y
                bne    .no_match
                inx
                iny
                cpy     #MAX_FILE_NAME_LEN
                bne     .loop
                clc                     ; matched
                bra     .done
.no_match:      sec
.done:          ply
                plx
                rts

test_file_name: .byte "newfil", 0