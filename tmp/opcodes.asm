LF                      = $0A
CR                      = $0D


MN_DEX = 0
MN_DEY = 1 
MN_TAX = 2
MN_TSB = 3
MN_BPL = 4
MN_BCC = 5
MN_CPX = 6
MN_EOR = 7
MN_TSX = 8
MN_DEC = 9
MN_STA = 10
MN_LDA = 11
MN_BEQ = 12
MN_ROL = 13
MN_STY = 14
MN_JMP = 15
MN_BMI = 16
MN_RTI = 17
MN_TAY = 18
MN_TXA = 19
MN_RTS = 20
MN_SED = 21
MN_LSR = 22
MN_BNE = 23
MN_JSR = 24
MN_LDY = 25
MN_SEC = 26
MN_BIT = 27
MN_LDX = 28
MN_TXS = 29
MN_SEI = 30
MN_ASL = 31
MN_BVS = 32
MN_CPY = 33
MN_CLI = 34
MN_CLD = 35
MN_TRB = 36
MN_CLC = 37
MN_BCS = 38
MN_ADC = 39
MN_CLV = 40
MN_STX = 41
MN_ROR = 42
MN_STZ = 43
MN_AND = 44
MN_PHP = 45
MN_INX = 46
MN_INY = 47
MN_PLP = 48
MN_PHA = 49
MN_CMP = 50
MN_TYA = 51
MN_PLY = 52
MN_PLX = 53
MN_BVC = 54
MN_SBC = 55
MN_PHY = 56
MN_PHX = 57
MN_BRK = 58
MN_PLA = 59
MN_INC = 61
MN_NOP = 62
MN_BRA = 63
MN_ORA = 64

MODE_IAX  = 0 * 2
MODE_IZP  = 1 * 2
MODE_ZPX  = 2 * 2
MODE_ZPY  = 3 * 2
MODE_IZX  = 4 * 2
MODE_IMM  = 5 * 2
MODE_IZY  = 6 * 2
MODE_IND  = 7 * 2
MODE_ABS  = 8 * 2
MODE_REL  = 9 * 2
MODE_ABY  = 10 * 2
MODE_ABX  = 11 * 2
MODE_ZP   = 12 * 2
MODE_IMPL = 13 * 2

                .macro inc16
                inc \1
                bne .\@
                inc (\1)+1
.\@:          
                .endm

                .macro dec16
                lda \1
                bne .\@
                dec (\1)+1
.\@:          
                dec \1
                .endm


search          =       $40             ; 2 bytes
mnemonic        =       $42
addr_mode       =       $43
code_pointer    =       $44             ; 2 bytes

                .org    $600

main:           lda     #0
                sta     code_pointer
                lda     #06
                sta     code_pointer+1
                ldx     #20
.loop:          jsr     print_line
                dex
                bne     .loop
                rts 

;==============================================================
; print one line of disassembled code, starting at the address
; stored at code_pointer
;==============================================================
print_line:     phx
                lda     code_pointer+1
                jsr     JMP_PRINT_HEX
                lda     code_pointer
                jsr     JMP_PRINT_HEX
                lda     #":"
                jsr     JMP_PUTC
                jsr     JMP_PRINT_STRING
                .byte   "          ",0
                jsr     print_instuction
                inc16   code_pointer
                lda     #CR
                jsr     JMP_PUTC
                lda     #LF
                jsr     JMP_PUTC
                plx
                rts

;==============================================================
; print the instruction stored at code_pointer
;==============================================================
print_instuction:
                lda     (code_pointer)
                jsr     search_op
                ldy     #1
                lda     (search),y      ; skip first byte of entry (opcode)
                sta     mnemonic
                iny
                lda     (search),y
                sta     addr_mode
                jsr     print_mn
                lda     #" "
                jsr     JMP_PUTC
                jsr     print_args
                rts


search_op:      ldx     #<opcodes
                stx     search
                ldx     #>opcodes
                stx     search+1
.next           ldy     #0
                cmp     (search),y
                beq     .found
                inc16   search
                inc16   search
                inc16   search
                bra     .next
.found:         rts

print_mn:       ldx     #<mnemonics2
                stx     search
                ldx     #>mnemonics2
                stx     search+1
                lda     mnemonic
.next           ldy     #0
                cmp     (search),y
                beq     .found
                inc16   search
                inc16   search
                inc16   search
                inc16   search
                bra     .next
.found:         inc16   search
.nextchar:      lda     (search),y
                jsr     JMP_PUTC
                iny
                cpy     #3
                bne     .nextchar
                rts

print_args:     ldy     addr_mode
                lda     addressing_modes,y    ; index into formats table
                ldx     addressing_modes+1,y  ; arg size
                tay
.loop:          lda     addressing_mode_formats,y
                beq     .done
                cmp     #"*"
                bne     .notargval
                cpx     #1
                beq     .1bytearg
                jsr     print2bytearg
                bra     .next
.1bytearg:      jsr     print1bytearg
                bra     .next
.notargval      jsr     JMP_PUTC
.next           iny
                bra     .loop
.done           rts

; x contains arg size
print1bytearg:  inc16   code_pointer
                lda     (code_pointer)
                jsr     JMP_PRINT_HEX
                rts

print2bytearg:  phy
                ldy     #2
.loop:          lda     (code_pointer),y
                jsr     JMP_PRINT_HEX
                dey
                bne     .loop
                inc16   code_pointer
                inc16   code_pointer
                ply
                rts

opcodes:        .byte $00, MN_BRK, MODE_IMPL
                .byte $01, MN_ORA, MODE_IZX
                .byte $04, MN_TSB, MODE_ZP
                .byte $05, MN_ORA, MODE_ZP
                .byte $06, MN_ASL, MODE_ZP
                .byte $08, MN_PHP, MODE_IMPL
                .byte $09, MN_ORA, MODE_IMM
                .byte $0a, MN_ASL, MODE_IMPL
                .byte $0c, MN_TSB, MODE_ABS
                .byte $0d, MN_ORA, MODE_ABS
                .byte $0e, MN_ASL, MODE_ABS
                .byte $10, MN_BPL, MODE_REL
                .byte $11, MN_ORA, MODE_IZY
                .byte $12, MN_ORA, MODE_IZP
                .byte $14, MN_TRB, MODE_ZP
                .byte $15, MN_ORA, MODE_ZPX
                .byte $16, MN_ASL, MODE_ZPX
                .byte $18, MN_CLC, MODE_IMPL
                .byte $19, MN_ORA, MODE_ABY
                .byte $1a, MN_INC, MODE_IMPL
                .byte $1c, MN_TRB, MODE_ABS
                .byte $1d, MN_ORA, MODE_ABX
                .byte $1e, MN_ASL, MODE_ABX
                .byte $20, MN_JSR, MODE_ABS
                .byte $21, MN_AND, MODE_IZX
                .byte $24, MN_BIT, MODE_ZP
                .byte $25, MN_AND, MODE_ZP
                .byte $26, MN_ROL, MODE_ZP
                .byte $28, MN_PLP, MODE_IMPL
                .byte $29, MN_AND, MODE_IMM
                .byte $2a, MN_ROL, MODE_IMPL
                .byte $2c, MN_BIT, MODE_ABS
                .byte $2d, MN_AND, MODE_ABS
                .byte $2e, MN_ROL, MODE_ABS
                .byte $30, MN_BMI, MODE_REL
                .byte $31, MN_AND, MODE_IZY
                .byte $32, MN_AND, MODE_IZP
                .byte $34, MN_BIT, MODE_ZPX
                .byte $35, MN_AND, MODE_ZPX
                .byte $36, MN_ROL, MODE_ZPX
                .byte $38, MN_SEC, MODE_IMPL
                .byte $39, MN_AND, MODE_ABY
                .byte $3a, MN_DEC, MODE_IMPL
                .byte $3c, MN_BIT, MODE_ABX
                .byte $3d, MN_AND, MODE_ABX
                .byte $3e, MN_ROL, MODE_ABX
                .byte $40, MN_RTI, MODE_IMPL
                .byte $41, MN_EOR, MODE_IZX
                .byte $45, MN_EOR, MODE_ZP
                .byte $46, MN_LSR, MODE_ZP
                .byte $48, MN_PHA, MODE_IMPL
                .byte $49, MN_EOR, MODE_IMM
                .byte $4a, MN_LSR, MODE_IMPL
                .byte $4c, MN_JMP, MODE_ABS
                .byte $4d, MN_EOR, MODE_ABS
                .byte $4e, MN_LSR, MODE_ABS
                .byte $50, MN_BVC, MODE_REL
                .byte $51, MN_EOR, MODE_IZY
                .byte $52, MN_EOR, MODE_IZP
                .byte $55, MN_EOR, MODE_ZPX
                .byte $56, MN_LSR, MODE_ZPX
                .byte $58, MN_CLI, MODE_IMPL
                .byte $59, MN_EOR, MODE_ABY
                .byte $5a, MN_PHY, MODE_IMPL
                .byte $5d, MN_EOR, MODE_ABX
                .byte $5e, MN_LSR, MODE_ABX
                .byte $60, MN_RTS, MODE_IMPL
                .byte $61, MN_ADC, MODE_IZX
                .byte $64, MN_STZ, MODE_ZP
                .byte $65, MN_ADC, MODE_ZP
                .byte $66, MN_ROR, MODE_ZP
                .byte $68, MN_PLA, MODE_IMPL
                .byte $69, MN_ADC, MODE_IMM
                .byte $6a, MN_ROR, MODE_IMPL
                .byte $6c, MN_JMP, MODE_IND
                .byte $6d, MN_ADC, MODE_ABS
                .byte $6e, MN_ROR, MODE_ABS
                .byte $70, MN_BVS, MODE_REL
                .byte $71, MN_ADC, MODE_IZY
                .byte $72, MN_ADC, MODE_IZP
                .byte $74, MN_STZ, MODE_ZPX
                .byte $75, MN_ADC, MODE_ZPX
                .byte $76, MN_ROR, MODE_ZPX
                .byte $78, MN_SEI, MODE_IMPL
                .byte $79, MN_ADC, MODE_ABY
                .byte $7a, MN_PLY, MODE_IMPL
                .byte $7c, MN_JMP, MODE_IAX
                .byte $7d, MN_ADC, MODE_ABX
                .byte $7e, MN_ROR, MODE_ABX
                .byte $80, MN_BRA, MODE_REL
                .byte $81, MN_STA, MODE_IZX
                .byte $84, MN_STY, MODE_ZP
                .byte $85, MN_STA, MODE_ZP
                .byte $86, MN_STX, MODE_ZP
                .byte $88, MN_DEY, MODE_IMPL
                .byte $89, MN_BIT, MODE_IMM
                .byte $8a, MN_TXA, MODE_IMPL
                .byte $8c, MN_STY, MODE_ABS
                .byte $8d, MN_STA, MODE_ABS
                .byte $8e, MN_STX, MODE_ABS
                .byte $90, MN_BCC, MODE_REL
                .byte $91, MN_STA, MODE_IZY
                .byte $92, MN_STA, MODE_IZP
                .byte $94, MN_STY, MODE_ZPX
                .byte $95, MN_STA, MODE_ZPX
                .byte $96, MN_STX, MODE_ZPY
                .byte $98, MN_TYA, MODE_IMPL
                .byte $99, MN_STA, MODE_ABY
                .byte $9a, MN_TXS, MODE_IMPL
                .byte $9c, MN_STZ, MODE_ABS
                .byte $9d, MN_STA, MODE_ABX
                .byte $9e, MN_STZ, MODE_ABX
                .byte $a0, MN_LDY, MODE_IMM
                .byte $a1, MN_LDA, MODE_IZX
                .byte $a2, MN_LDX, MODE_IMM
                .byte $a4, MN_LDY, MODE_ZP
                .byte $a5, MN_LDA, MODE_ZP
                .byte $a6, MN_LDX, MODE_ZP
                .byte $a8, MN_TAY, MODE_IMPL
                .byte $a9, MN_LDA, MODE_IMM
                .byte $aa, MN_TAX, MODE_IMPL
                .byte $ac, MN_LDY, MODE_ABS
                .byte $ad, MN_LDA, MODE_ABS
                .byte $ae, MN_LDX, MODE_ABS
                .byte $b0, MN_BCS, MODE_REL
                .byte $b1, MN_LDA, MODE_IZY
                .byte $b2, MN_LDA, MODE_IZP
                .byte $b4, MN_LDY, MODE_ZPX
                .byte $b5, MN_LDA, MODE_ZPX
                .byte $b6, MN_LDX, MODE_ZPY
                .byte $b8, MN_CLV, MODE_IMPL
                .byte $b9, MN_LDA, MODE_ABY
                .byte $ba, MN_TSX, MODE_IMPL
                .byte $bc, MN_LDY, MODE_ABX
                .byte $bd, MN_LDA, MODE_ABX
                .byte $be, MN_LDX, MODE_ABY
                .byte $c0, MN_CPY, MODE_IMM
                .byte $c1, MN_CMP, MODE_IZX
                .byte $c4, MN_CPY, MODE_ZP
                .byte $c5, MN_CMP, MODE_ZP
                .byte $c6, MN_DEC, MODE_ZP
                .byte $c8, MN_INY, MODE_IMPL
                .byte $c9, MN_CMP, MODE_IMM
                .byte $ca, MN_DEX, MODE_IMPL
                .byte $cc, MN_CPY, MODE_ABS
                .byte $cd, MN_CMP, MODE_ABS
                .byte $ce, MN_DEC, MODE_ABS
                .byte $d0, MN_BNE, MODE_REL
                .byte $d1, MN_CMP, MODE_IZY
                .byte $d2, MN_CMP, MODE_IZP
                .byte $d5, MN_CMP, MODE_ZPX
                .byte $d6, MN_DEC, MODE_ZPX
                .byte $d8, MN_CLD, MODE_IMPL
                .byte $d9, MN_CMP, MODE_ABY
                .byte $da, MN_PHX, MODE_IMPL
                .byte $dd, MN_CMP, MODE_ABX
                .byte $de, MN_DEC, MODE_ABX
                .byte $e0, MN_CPX, MODE_IMM
                .byte $e1, MN_SBC, MODE_IZX
                .byte $e4, MN_CPX, MODE_ZP
                .byte $e5, MN_SBC, MODE_ZP
                .byte $e6, MN_INC, MODE_ZP
                .byte $e8, MN_INX, MODE_IMPL
                .byte $e9, MN_SBC, MODE_IMM
                .byte $ea, MN_NOP, MODE_IMPL
                .byte $ec, MN_CPX, MODE_ABS
                .byte $ed, MN_SBC, MODE_ABS
                .byte $ee, MN_INC, MODE_ABS
                .byte $f0, MN_BEQ, MODE_REL
                .byte $f1, MN_SBC, MODE_IZY
                .byte $f2, MN_SBC, MODE_IZP
                .byte $f5, MN_SBC, MODE_ZPX
                .byte $f6, MN_INC, MODE_ZPX
                .byte $f8, MN_SED, MODE_IMPL
                .byte $f9, MN_SBC, MODE_ABY
                .byte $fa, MN_PLX, MODE_IMPL
                .byte $fd, MN_SBC, MODE_ABX
                .byte $fe, MN_INC, MODE_ABX
                .byte 0

mnemonics2      .byte   MN_DEX, "DEX"
                .byte   MN_DEY, "DEY"
                .byte   MN_TAX, "TAX"
                .byte   MN_TSB, "TSB"
                .byte   MN_BPL, "BPL"
                .byte   MN_BCC, "BCC"
                .byte   MN_CPX, "CPX"
                .byte   MN_EOR, "EOR"
                .byte   MN_TSX, "TSX"
                .byte   MN_DEC, "DEC"
                .byte   MN_STA, "STA"
                .byte   MN_LDA, "LDA"
                .byte   MN_BEQ, "BEQ"
                .byte   MN_ROL, "ROL"
                .byte   MN_STY, "STY"
                .byte   MN_JMP, "JMP"
                .byte   MN_BMI, "BMI"
                .byte   MN_RTI, "RTI"
                .byte   MN_TAY, "TAY"
                .byte   MN_TXA, "TXA"
                .byte   MN_RTS, "RTS"
                .byte   MN_SED, "SED"
                .byte   MN_LSR, "LSR"
                .byte   MN_BNE, "BNE"
                .byte   MN_JSR, "JSR"
                .byte   MN_LDY, "LDY"
                .byte   MN_SEC, "SEC"
                .byte   MN_BIT, "BIT"
                .byte   MN_LDX, "LDX"
                .byte   MN_TXS, "TXS"
                .byte   MN_SEI, "SEI"
                .byte   MN_ASL, "ASL"
                .byte   MN_BVS, "BVS"
                .byte   MN_CPY, "CPY"
                .byte   MN_CLI, "CLI"
                .byte   MN_CLD, "CLD"
                .byte   MN_TRB, "TRB"
                .byte   MN_CLC, "CLC"
                .byte   MN_BCS, "BCS"
                .byte   MN_ADC, "ADC"
                .byte   MN_CLV, "CLV"
                .byte   MN_STX, "STX"
                .byte   MN_ROR, "ROR"
                .byte   MN_STZ, "STZ"
                .byte   MN_AND, "AND"
                .byte   MN_PHP, "PHP"
                .byte   MN_INX, "INX"
                .byte   MN_INY, "INY"
                .byte   MN_PLP, "PLP"
                .byte   MN_PHA, "PHA"
                .byte   MN_CMP, "CMP"
                .byte   MN_TYA, "TYA"
                .byte   MN_PLY, "PLY"
                .byte   MN_PLX, "PLX"
                .byte   MN_BVC, "BVC"
                .byte   MN_SBC, "SBC"
                .byte   MN_PHY, "PHY"
                .byte   MN_PHX, "PHX"
                .byte   MN_BRK, "BRK"
                .byte   MN_PLA, "PLA"
                .byte   MN_INC, "INC"
                .byte   MN_NOP, "NOP"
                .byte   MN_BRA, "BRA"
                .byte   MN_ORA, "ORA"


; index into formats table / arg size
addressing_modes:
                .byte mode_iax_fmt - addressing_mode_formats, 2
                .byte mode_izp_fmt - addressing_mode_formats, 1
                .byte mode_zpx_fmt - addressing_mode_formats, 1
                .byte mode_zpy_fmt - addressing_mode_formats, 1
                .byte mode_izx_fmt - addressing_mode_formats, 1
                .byte mode_imm_fmt - addressing_mode_formats, 1
                .byte mode_izy_fmt - addressing_mode_formats, 1
                .byte mode_ind_fmt - addressing_mode_formats, 2
                .byte mode_abs_fmt - addressing_mode_formats, 2
                .byte mode_rel_fmt - addressing_mode_formats, 1
                .byte mode_aby_fmt - addressing_mode_formats, 2
                .byte mode_abx_fmt - addressing_mode_formats, 2
                .byte mode_zp_fmt - addressing_mode_formats, 1
                .byte mode_impl_fmt - addressing_mode_formats, 0
                .byte   0               ; end

;=========================================================================
; Formats for all the different addressing modes. These are all labelled
; because the entries are all different lengths, making it impossible to
; search through the table by the first byte of each entry. Instead, the
; addressing_modes table indexes into this table using calculated
; indexes.
; * will be replaced by the argument value
;=========================================================================
addressing_mode_formats:
mode_iax_fmt:   .byte "($*,x)",0
mode_izp_fmt:   .byte "($*)",0
mode_zpx_fmt:   .byte "$*,x",0
mode_zpy_fmt:   .byte "$*,y",0
mode_izx_fmt:   .byte "($*,x)",0
mode_imm_fmt:   .byte "#$*",0
mode_izy_fmt:   .byte "($*),y",0
mode_ind_fmt:   .byte "($*)",0
mode_abs_fmt:   .byte "$*",0
mode_rel_fmt:   .byte "$*",0
mode_aby_fmt:   .byte "$*,y",0
mode_abx_fmt:   .byte "$*,x",0
mode_zp_fmt:    .byte "$*",0
mode_impl_fmt:  .byte "",0



                .include "../../pager_os/build/pager_os/pager_os.inc"