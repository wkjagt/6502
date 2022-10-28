    .include "../../pager_os/build/pager_os/pager_os.inc"

MNEMONIC_SIZE   = 3

inst_ptr        =      $40     ; 2 bytes
mode_ptr        =      $42     ; 2 bytes
found_opcode    =      $44     ; 1 bytes
arg_byte_size   =      $45     ; 1 byte
arg_byte_offset =      $46     ; 1 byte
write_ptr       =      $47     ; 2 bytes

                .macro inc16
                inc \1
                bne .\@
                inc (\1)+1
.\@:          
                .endm

                .org $0600

; The main routine. This formats the line, gets input, calls the routine that
; parses the assembly, and outputs the assembled instructions and arguments
; to the 
main:           lda     input_flags
                ora     #1              ; enable uppercase conversion
                sta     input_flags

                ; setup some values. These will come as arguments at some point
read_line:      stz     write_ptr
                lda     #$10
                sta     write_ptr+1

.next_line:     lda     #$0A
                jsr     JMP_PUTC
                lda     #$0D
                jsr     JMP_PUTC

                lda     write_ptr+1     ; print the current address at the start of the line
                jsr     JMP_PRINT_HEX
                lda     write_ptr
                jsr     JMP_PRINT_HEX

                jsr     JMP_PRINT_STRING
                .byte   ":            | ",0
                
                jsr     JMP_GET_INPUT
                bcs     .exit

                lda     #$0e            ; go to column 5 to print assembled bytes
                jsr     JMP_PUTC
                lda     #7
                jsr     JMP_PUTC

                jsr     save_line       ; save line also outputs, can we make this nicer?
                bra     .next_line
.exit:          lda     input_flags
                and     #%11111110      ; disable uppercase conversion
                sta     input_flags
                rts                


save_line:      jsr     find_instrctn
                bcs     .error
                lda     found_opcode
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                
                lda     arg_byte_size
                beq     .done
                cmp     #2
                beq     .two_byte_arg

.one_byte_arg:  inc16   write_ptr               ; todo: lots of repetition
                clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+4)
                jsr     hex_to_byte
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                bra     .done

.two_byte_arg:  inc16   write_ptr
                clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+6)
                jsr     hex_to_byte
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                
                inc16   write_ptr
                clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+4)
                jsr     hex_to_byte
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX

.done:          inc16   write_ptr
.error          rts

; In the list of instructions, find the entry that matches the mnnemonic.
; It loops over the list of mnemonic pointers, and calls `match_mnemonic`
; for each of these.
find_instrctn:  ldx     #0
.loop:          lda     mnemonics,x
                sta     inst_ptr
                inx
                lda     mnemonics,x
                sta     inst_ptr + 1
                jsr     match_mnemonic
                bcc     .match
                inx
                cpx     #mnemonics_size
                bne     .loop
                sec                     ; end up here: no match for mnemonic, flag as not found
                bra     .done           ; and don't look for address mode
.match:         jsr     find_mode
.done:          rts

match_mnemonic: phx
                ldx     #MNEMONIC_SIZE  ; mnemonics are 3 characters long
                ldy     #0
.loop:          lda     (inst_ptr), y
                ; jsr     JMP_PUTC
                cmp     __INPUTBFR_START__, y
                bne     .no_match
                iny
                dex
                bne     .loop
                clc
                bra     .match
.no_match:      sec
.match          plx
                rts

; When the mnemonic is matched, the addressing mode needs to be matched as well
; based on the pattern of the argument. This loops over the available mode pointers
; for the matched mnemonic. Once the address mode is matched, the resuling opcode
; for the mnemonic / addressing mode are stored in found_opcode
find_mode:      lda     #MNEMONIC_SIZE  ; inst_ptr now points to the matching instruction
                clc                     ; add three to skip the mnemonic string, and point
                adc     inst_ptr        ; to the number of available modes for this instruction
                sta     inst_ptr
                bcc     .cont
                inc     inst_ptr+1
.cont:          lda     (inst_ptr)
                tax                     ; the number of times to loop
                inc16   inst_ptr        ; go to the next byte which is the first byte of the
                                        ; pointer to the first available mode of this mnemonic
.next_mode:     jsr     match_mode
                bcc     .found_mode
                inc16   inst_ptr        ; point at opcode for this mnemonic / mode
                inc16   inst_ptr        ; point at first byte of the next available mode
                dex
                bne     .next_mode
                sec                     ; not found
                rts
.found_mode:    inc16   inst_ptr
                lda     (inst_ptr)
                sta     found_opcode

                ; now use mode_ptr to get the arg size and hex index to translate the hex
                iny                     ; Pointer was left at the end of string marker for the pattern
                                        ; Point it to the next byte which contains the number of chars
                                        ; in the arg to skip to get to the start of the hex value
                lda     (mode_ptr), y
                sta     arg_byte_size
                iny
                lda     (mode_ptr), y
                sta     arg_byte_offset
                clc                     ; flag as found
                rts

; inst_ptr points to the first byte of the address of the first
; mode of the instruction that matched.
match_mode:     phx
                ; build the pointer to the addressing mode string
                lda     (inst_ptr)      ; loads the low byte of the address where the pattern is stored
                sta     mode_ptr
                inc16   inst_ptr        ; now point to the hight byte of the word
                lda     (inst_ptr)
                sta     mode_ptr+1

                ldy     #0
.loop:          ;lda     (mode_ptr), y
                ;jsr     JMP_PUTC
                lda     (mode_ptr), y
                cmp     #"*"            ; match hex
                bne     .not_hex
                lda     __INPUTBFR_START__ + 4, y    ; load the input character into A
                jsr     match_hex
                bcc     .next
                bra     .not_found
.not_hex:       lda     (mode_ptr), y
                cmp     __INPUTBFR_START__ + 4, y    ; match to the next char from the input
                beq     .next
.not_found:     sec
                bra     .done
.next:          lda     (mode_ptr), y
                beq     .match          ; if we get to the end of string, it's a match
                iny
                bra     .loop
.match:         clc
.done:          plx
                rts


; derermine if the byte in A is a hex character.
; set carry if it isn't. Clear carry if it is.
match_hex:      phy
                ldy     #16

.next:          cmp     hex-1, y
                beq     .match
                dey
                bne     .next
                sec
                bra     .done
.match:         clc
.done:          ply
                rts

hex:            .byte "0123456789ABCDEF"
