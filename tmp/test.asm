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

read_line:      stz     write_ptr
                lda     #$10
                sta     write_ptr+1

.next_line:     lda     #$0A
                jsr     JMP_PUTC
                lda     #$0D
                jsr     JMP_PUTC

                lda     write_ptr+1
                jsr     JMP_PRINT_HEX
                lda     write_ptr
                jsr     JMP_PRINT_HEX

                jsr     JMP_PRINT_STRING
                .byte   "            ",0
                
                jsr     JMP_GET_INPUT

                lda     #$0e
                jsr     JMP_PUTC
                lda     #5
                jsr     JMP_PUTC

                jsr     save_line

                bra     .next_line


save_line:      jsr     find_instrctn
                bcs     .error
                lda     found_opcode
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                
                inc16   write_ptr       ; to next write address for the args, if any

                lda     arg_byte_size
                beq     .done
                cmp     #2
                beq     .two_byte_arg

.one_byte_arg:  clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+4)
                jsr     hex_to_byte
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                bra     .done

.two_byte_arg:  clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+6) ; read low byte first
                jsr     hex_to_byte
                sta     (write_ptr)
                jsr     JMP_PRINT_HEX
                lda     #" "
                jsr     JMP_PUTC
                
                inc16   write_ptr
                clc
                lda     arg_byte_offset
                adc     #(__INPUTBFR_START__+4) ; read low byte first
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
                cmp     #"*"            ; match anything, this is where the hex values are
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


putc:           sta     $f001
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

                ; pattern string, null byte, arg size, arg offset in string
mode_iax:       .byte "($****,x)", 0, 2, 2
mode_izp:       .byte "($**)", 0, 1, 2
mode_zpx:       .byte "$**,x", 0, 1, 1
mode_zpy:       .byte "$**,y", 0, 1, 1
mode_izx:       .byte "($**,x)", 0, 1, 2
mode_imm:       .byte "#$**", 0, 1, 2
mode_izy:       .byte "($**),y", 0, 1, 2
mode_ind:       .byte "($****)", 0, 2, 2
mode_abs:       .byte "$****", 0, 2, 1
mode_rel:       .byte "", 0, 0, 0
mode_aby:       .byte "$****,y", 0, 2, 1
mode_abx:       .byte "$****,x", 0, 2, 1
mode_zp:        .byte "$**", 0, 1, 1
mode_impl:      .byte "", 0, 0, 1

; this table is 64 words / 128 bytes long, so we can index into it
; using one byte
mnemonics:      .word inst_dex, inst_dey, inst_tax, inst_tsb, inst_bpl
                .word inst_bcc, inst_cpx, inst_eor, inst_tsx, inst_dec
                .word inst_sta, inst_lda, inst_beq, inst_rol, inst_sty
                .word inst_jmp, inst_bmi, inst_rti, inst_tay, inst_txa
                .word inst_rts, inst_sed, inst_lsr, inst_bne, inst_jsr
                .word inst_ldy, inst_sec, inst_bit, inst_ldx, inst_txs
                .word inst_sei, inst_asl, inst_bvs, inst_cpy, inst_cli
                .word inst_cld, inst_trb, inst_clc, inst_bcs, inst_adc
                .word inst_clv, inst_stx, inst_ror, inst_stz, inst_and
                .word inst_php, inst_inx, inst_iny, inst_plp, inst_pha
                .word inst_cmp, inst_tya, inst_ply, inst_plx, inst_bvc
                .word inst_sbc, inst_phy, inst_phx, inst_brk, inst_pla
                .word inst_inc, inst_nop, inst_bra, inst_ora
end_mnemonics:
mnemonics_size = end_mnemonics - mnemonics

instructions:
inst_dex:       .byte "DEX", 1
                    .word mode_impl
                    .byte $ca
inst_dey:       .byte "DEY", 1
                    .word mode_impl
                    .byte $88
inst_tax:       .byte "TAX", 1
                    .word mode_impl
                    .byte $aa
inst_tsb:       .byte "TSB", 2
                    .word mode_abs
                    .byte $0c
                    .word mode_zp
                    .byte $04
inst_bpl:       .byte "BPL", 1
                    .word mode_rel
                    .byte $10
inst_bcc:       .byte "BCC", 1
                    .word mode_rel
                    .byte $90
inst_cpx:       .byte "CPX", 3
                    .word mode_zp
                    .byte $e4
                    .word mode_abs
                    .byte $ec
                    .word mode_imm
                    .byte $e0
inst_eor:       .byte "EOR", 9
                    .word mode_zpx
                    .byte $55
                    .word mode_imm
                    .byte $49
                    .word mode_izp
                    .byte $52
                    .word mode_abx
                    .byte $5d
                    .word mode_abs
                    .byte $4d
                    .word mode_aby
                    .byte $59
                    .word mode_izx
                    .byte $41
                    .word mode_izy
                    .byte $51
                    .word mode_zp
                    .byte $45
inst_tsx:       .byte "TSX", 1
                    .word mode_impl
                    .byte $ba
inst_dec:       .byte "DEC", 5
                    .word mode_abx
                    .byte $de
                    .word mode_zpx
                    .byte $d6
                    .word mode_abs
                    .byte $ce
                    .word mode_zp
                    .byte $c6
                    .word mode_impl
                    .byte $3a
inst_sta:       .byte "STA", 8
                    .word mode_zpx
                    .byte $95
                    .word mode_izp
                    .byte $92
                    .word mode_abx
                    .byte $9d
                    .word mode_abs
                    .byte $8d
                    .word mode_aby
                    .byte $99
                    .word mode_izx
                    .byte $81
                    .word mode_izy
                    .byte $91
                    .word mode_zp
                    .byte $85
inst_lda:       .byte "LDA", 9
                    .word mode_zpx
                    .byte $b5
                    .word mode_imm
                    .byte $a9
                    .word mode_izp
                    .byte $b2
                    .word mode_abx
                    .byte $bd
                    .word mode_abs
                    .byte $ad
                    .word mode_aby
                    .byte $b9
                    .word mode_izx
                    .byte $a1
                    .word mode_izy
                    .byte $b1
                    .word mode_zp
                    .byte $a5
inst_beq:       .byte "BEQ", 1
                    .word mode_rel
                    .byte $f0
inst_rol:       .byte "ROL", 5
                    .word mode_abx
                    .byte $3e
                    .word mode_zpx
                    .byte $36
                    .word mode_abs
                    .byte $2e
                    .word mode_zp
                    .byte $26
                    .word mode_impl
                    .byte $2a
inst_sty:       .byte "STY", 3
                    .word mode_zpx
                    .byte $94
                    .word mode_abs
                    .byte $8c
                    .word mode_zp
                    .byte $84
inst_jmp:       .byte "JMP", 3
                    .word mode_ind
                    .byte $6c
                    .word mode_abs
                    .byte $4c
                    .word mode_iax
                    .byte $7c
inst_bmi:       .byte "BMI", 1
                    .word mode_rel
                    .byte $30
inst_rti:       .byte "RTI", 1
                    .word mode_impl
                    .byte $40
inst_tay:       .byte "TAY", 1
                    .word mode_impl
                    .byte $a8
inst_txa:       .byte "TXA", 1
                    .word mode_impl
                    .byte $8a
inst_rts:       .byte "RTS", 1
                    .word mode_impl
                    .byte $60
inst_sed:       .byte "SED", 1
                    .word mode_impl
                    .byte $f8
inst_lsr:       .byte "LSR", 5
                    .word mode_abx
                    .byte $5e
                    .word mode_zpx
                    .byte $56
                    .word mode_abs
                    .byte $4e
                    .word mode_zp
                    .byte $46
                    .word mode_impl
                    .byte $4a
inst_bne:       .byte "BNE", 1
                    .word mode_rel
                    .byte $d0
inst_jsr:       .byte "JSR", 1
                    .word mode_abs
                    .byte $20
inst_ldy:       .byte "LDY", 5
                    .word mode_abx
                    .byte $bc
                    .word mode_zp
                    .byte $a4
                    .word mode_abs
                    .byte $ac
                    .word mode_imm
                    .byte $a0
                    .word mode_zpx
                    .byte $b4
inst_sec:       .byte "SEC", 1
                    .word mode_impl
                    .byte $38
inst_bit:       .byte "BIT", 5
                    .word mode_abx
                    .byte $3c
                    .word mode_zpx
                    .byte $34
                    .word mode_abs
                    .byte $2c
                    .word mode_zp
                    .byte $24
                    .word mode_imm
                    .byte $89
inst_ldx:       .byte "LDX", 5
                    .word mode_zpy
                    .byte $b6
                    .word mode_zp
                    .byte $a6
                    .word mode_abs
                    .byte $ae
                    .word mode_imm
                    .byte $a2
                    .word mode_aby
                    .byte $be
inst_txs:       .byte "TXS", 1
                    .word mode_impl
                    .byte $9a
inst_sei:       .byte "SEI", 1
                    .word mode_impl
                    .byte $78
inst_asl:       .byte "ASL", 5
                    .word mode_abx
                    .byte $1e
                    .word mode_zpx
                    .byte $16
                    .word mode_abs
                    .byte $0e
                    .word mode_zp
                    .byte $06
                    .word mode_impl
                    .byte $0a
inst_bvs:       .byte "BVS", 1
                    .word mode_rel
                    .byte $70
inst_cpy:       .byte "CPY", 3
                    .word mode_zp
                    .byte $c4
                    .word mode_abs
                    .byte $cc
                    .word mode_imm
                    .byte $c0
inst_cli:       .byte "CLI", 1
                    .word mode_impl
                    .byte $58
inst_cld:       .byte "CLD", 1
                    .word mode_impl
                    .byte $d8
inst_trb:       .byte "TRB", 2
                    .word mode_abs
                    .byte $1c
                    .word mode_zp
                    .byte $14
inst_clc:       .byte "CLC", 1
                    .word mode_impl
                    .byte $18
inst_bcs:       .byte "BCS", 1
                    .word mode_rel
                    .byte $b0
inst_adc:       .byte "ADC", 9
                    .word mode_zpx
                    .byte $75
                    .word mode_imm
                    .byte $69
                    .word mode_izp
                    .byte $72
                    .word mode_abx
                    .byte $7d
                    .word mode_abs
                    .byte $6d
                    .word mode_aby
                    .byte $79
                    .word mode_izx
                    .byte $61
                    .word mode_izy
                    .byte $71
                    .word mode_zp
                    .byte $65
inst_clv:       .byte "CLV", 1
                    .word mode_impl
                    .byte $b8
inst_stx:       .byte "STX", 3
                    .word mode_zpy
                    .byte $96
                    .word mode_abs
                    .byte $8e
                    .word mode_zp
                    .byte $86
inst_ror:       .byte "ROR", 5
                    .word mode_abx
                    .byte $7e
                    .word mode_zpx
                    .byte $76
                    .word mode_abs
                    .byte $6e
                    .word mode_zp
                    .byte $66
                    .word mode_impl
                    .byte $6a
inst_stz:       .byte "STZ", 4
                    .word mode_abx
                    .byte $9e
                    .word mode_zpx
                    .byte $74
                    .word mode_abs
                    .byte $9c
                    .word mode_zp
                    .byte $64
inst_and:       .byte "AND", 9
                    .word mode_zpx
                    .byte $35
                    .word mode_imm
                    .byte $29
                    .word mode_izp
                    .byte $32
                    .word mode_abx
                    .byte $3d
                    .word mode_abs
                    .byte $2d
                    .word mode_aby
                    .byte $39
                    .word mode_izx
                    .byte $21
                    .word mode_izy
                    .byte $31
                    .word mode_zp
                    .byte $25
inst_php:       .byte "PHP", 1
                    .word mode_impl
                    .byte $08
inst_inx:       .byte "INX", 1
                    .word mode_impl
                    .byte $e8
inst_iny:       .byte "INY", 1
                    .word mode_impl
                    .byte $c8
inst_plp:       .byte "PLP", 1
                    .word mode_impl
                    .byte $28
inst_pha:       .byte "PHA", 1
                    .word mode_impl
                    .byte $48
inst_cmp:       .byte "CMP", 9
                    .word mode_zpx
                    .byte $d5
                    .word mode_imm
                    .byte $c9
                    .word mode_izp
                    .byte $d2
                    .word mode_abx
                    .byte $dd
                    .word mode_abs
                    .byte $cd
                    .word mode_aby
                    .byte $d9
                    .word mode_izx
                    .byte $c1
                    .word mode_izy
                    .byte $d1
                    .word mode_zp
                    .byte $c5
inst_tya:       .byte "TYA", 1
                    .word mode_impl
                    .byte $98
inst_ply:       .byte "PLY", 1
                    .word mode_impl
                    .byte $7a
inst_plx:       .byte "PLX", 1
                    .word mode_impl
                    .byte $fa
inst_bvc:       .byte "BVC", 1
                    .word mode_rel
                    .byte $50
inst_sbc:       .byte "SBC", 9
                    .word mode_zpx
                    .byte $f5
                    .word mode_imm
                    .byte $e9
                    .word mode_izp
                    .byte $f2
                    .word mode_abx
                    .byte $fd
                    .word mode_abs
                    .byte $ed
                    .word mode_aby
                    .byte $f9
                    .word mode_izx
                    .byte $e1
                    .word mode_izy
                    .byte $f1
                    .word mode_zp
                    .byte $e5
inst_phy:       .byte "PHY", 1
                    .word mode_impl
                    .byte $5a
inst_phx:       .byte "PHX", 1
                    .word mode_impl
                    .byte $da
inst_brk:       .byte "BRK", 1
                    .word mode_impl
                    .byte $00
inst_pla:       .byte "PLA", 1
                    .word mode_impl
                    .byte $68
inst_inc:       .byte "INC", 5
                    .word mode_abx
                    .byte $fe
                    .word mode_zpx
                    .byte $f6
                    .word mode_abs
                    .byte $ee
                    .word mode_zp
                    .byte $e6
                    .word mode_impl
                    .byte $1a
inst_nop:       .byte "NOP", 1
                    .word mode_impl
                    .byte $ea
inst_bra:       .byte "BRA", 1
                    .word mode_rel
                    .byte $80
inst_ora:       .byte "ORA", 9
                    .word mode_zpx
                    .byte $15
                    .word mode_imm
                    .byte $09
                    .word mode_izp
                    .byte $12
                    .word mode_abx
                    .byte $1d
                    .word mode_abs
                    .byte $0d
                    .word mode_aby
                    .byte $19
                    .word mode_izx
                    .byte $01
                    .word mode_izy
                    .byte $11
                    .word mode_zp
                    .byte $05
end_instructions: