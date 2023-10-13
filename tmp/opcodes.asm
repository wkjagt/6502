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
MN_INC = 60
MN_NOP = 61
MN_BRA = 62
MN_ORA = 63

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
                lda     #" "
                jsr     JMP_PUTC

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
                lda     (code_pointer)  ; load the next opcode into A
                asl     a
                tay
                bcs     .second_half
                lda     opcodes,y
                sta     mnemonic
                lda     opcodes+1,y
                sta     addr_mode
                bra     .next
.second_half:   lda     opcodes+$100,y
                sta     mnemonic
                lda     opcodes+$101,y
                sta     addr_mode
.next           jsr     print_mn
                lda     #" "
                jsr     JMP_PUTC
                jsr     print_args
                rts

print_mn:       lda     mnemonic        ; mutiply by 4 to get mnemonic index
                asl
                asl
                tay
                ldx     #3
.nextchar:      lda     mnemonics2,y
                jsr     JMP_PUTC
                iny
                dex
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

opcodes:        .byte MN_BRK, MODE_IMPL    ;$00
                .byte MN_ORA, MODE_IZX     ;$01
                .byte 0, 0                 ;$02
                .byte 0, 0                 ;$03
                .byte MN_TSB, MODE_ZP      ;$04
                .byte MN_ORA, MODE_ZP      ;$05
                .byte MN_ASL, MODE_ZP      ;$06
                .byte 0, 0                 ;$07
                .byte MN_PHP, MODE_IMPL    ;$08
                .byte MN_ORA, MODE_IMM     ;$09
                .byte MN_ASL, MODE_IMPL    ;$0a
                .byte 0, 0                 ;$0b
                .byte MN_TSB, MODE_ABS     ;$0c
                .byte MN_ORA, MODE_ABS     ;$0d
                .byte MN_ASL, MODE_ABS     ;$0e
                .byte 0, 0                 ;$0f
                .byte MN_BPL, MODE_REL     ;$10
                .byte MN_ORA, MODE_IZY     ;$11
                .byte MN_ORA, MODE_IZP     ;$12
                .byte 0, 0                 ;$13
                .byte MN_TRB, MODE_ZP      ;$14
                .byte MN_ORA, MODE_ZPX     ;$15
                .byte MN_ASL, MODE_ZPX     ;$16
                .byte 0, 0                 ;$17
                .byte MN_CLC, MODE_IMPL    ;$18
                .byte MN_ORA, MODE_ABY     ;$19
                .byte MN_INC, MODE_IMPL    ;$1a
                .byte 0, 0                 ;$1b
                .byte MN_TRB, MODE_ABS     ;$1c
                .byte MN_ORA, MODE_ABX     ;$1d
                .byte MN_ASL, MODE_ABX     ;$1e
                .byte 0, 0                 ;$1f
                .byte MN_JSR, MODE_ABS     ;$20
                .byte MN_AND, MODE_IZX     ;$21
                .byte 0, 0                 ;$22
                .byte 0, 0                 ;$23
                .byte MN_BIT, MODE_ZP      ;$24
                .byte MN_AND, MODE_ZP      ;$25
                .byte MN_ROL, MODE_ZP      ;$26
                .byte 0, 0                 ;$27
                .byte MN_PLP, MODE_IMPL    ;$28
                .byte MN_AND, MODE_IMM     ;$29
                .byte MN_ROL, MODE_IMPL    ;$2a
                .byte 0, 0                 ;$2b
                .byte MN_BIT, MODE_ABS     ;$2c
                .byte MN_AND, MODE_ABS     ;$2d
                .byte MN_ROL, MODE_ABS     ;$2e
                .byte 0, 0                 ;$2f
                .byte MN_BMI, MODE_REL     ;$30
                .byte MN_AND, MODE_IZY     ;$31
                .byte MN_AND, MODE_IZP     ;$32
                .byte 0, 0                 ;$33
                .byte MN_BIT, MODE_ZPX     ;$34
                .byte MN_AND, MODE_ZPX     ;$35
                .byte MN_ROL, MODE_ZPX     ;$36
                .byte 0, 0                 ;$37
                .byte MN_SEC, MODE_IMPL    ;$38
                .byte MN_AND, MODE_ABY     ;$39
                .byte MN_DEC, MODE_IMPL    ;$3a
                .byte 0, 0                 ;$3b
                .byte MN_BIT, MODE_ABX     ;$3c
                .byte MN_AND, MODE_ABX     ;$3d
                .byte MN_ROL, MODE_ABX     ;$3e
                .byte 0, 0                 ;$3f
                .byte MN_RTI, MODE_IMPL    ;$40
                .byte MN_EOR, MODE_IZX     ;$41
                .byte 0, 0                 ;$42
                .byte 0, 0                 ;$43
                .byte 0, 0                 ;$44
                .byte MN_EOR, MODE_ZP      ;$45
                .byte MN_LSR, MODE_ZP      ;$46
                .byte 0, 0                 ;$47
                .byte MN_PHA, MODE_IMPL    ;$48
                .byte MN_EOR, MODE_IMM     ;$49
                .byte MN_LSR, MODE_IMPL    ;$4a
                .byte 0, 0                 ;$4b
                .byte MN_JMP, MODE_ABS     ;$4c
                .byte MN_EOR, MODE_ABS     ;$4d
                .byte MN_LSR, MODE_ABS     ;$4e
                .byte 0, 0                 ;$4f
                .byte MN_BVC, MODE_REL     ;$50
                .byte MN_EOR, MODE_IZY     ;$51
                .byte MN_EOR, MODE_IZP     ;$52
                .byte 0, 0                 ;$53
                .byte 0, 0                 ;$54
                .byte MN_EOR, MODE_ZPX     ;$55
                .byte MN_LSR, MODE_ZPX     ;$56
                .byte 0, 0                 ;$57
                .byte MN_CLI, MODE_IMPL    ;$58
                .byte MN_EOR, MODE_ABY     ;$59
                .byte MN_PHY, MODE_IMPL    ;$5a
                .byte 0, 0                 ;$5b
                .byte 0, 0                 ;$5c
                .byte MN_EOR, MODE_ABX     ;$5d
                .byte MN_LSR, MODE_ABX     ;$5e
                .byte 0, 0                 ;$5f
                .byte MN_RTS, MODE_IMPL    ;$60
                .byte MN_ADC, MODE_IZX     ;$61
                .byte 0, 0                 ;$62
                .byte 0, 0                 ;$63
                .byte MN_STZ, MODE_ZP      ;$64
                .byte MN_ADC, MODE_ZP      ;$65
                .byte MN_ROR, MODE_ZP      ;$66
                .byte 0, 0                 ;$67
                .byte MN_PLA, MODE_IMPL    ;$68
                .byte MN_ADC, MODE_IMM     ;$69
                .byte MN_ROR, MODE_IMPL    ;$6a
                .byte MN_ROR, MODE_IMPL    ;$6b
                .byte MN_JMP, MODE_IND     ;$6c
                .byte MN_ADC, MODE_ABS     ;$6d
                .byte MN_ROR, MODE_ABS     ;$6e
                .byte 0, 0                 ;$6f
                .byte MN_BVS, MODE_REL     ;$70
                .byte MN_ADC, MODE_IZY     ;$71
                .byte MN_ADC, MODE_IZP     ;$72
                .byte 0, 0                 ;$73
                .byte MN_STZ, MODE_ZPX     ;$74
                .byte MN_ADC, MODE_ZPX     ;$75
                .byte MN_ROR, MODE_ZPX     ;$76
                .byte 0, 0                 ;$77
                .byte MN_SEI, MODE_IMPL    ;$78
                .byte MN_ADC, MODE_ABY     ;$79
                .byte MN_PLY, MODE_IMPL    ;$7a
                .byte 0, 0                 ;$7b
                .byte MN_JMP, MODE_IAX     ;$7c
                .byte MN_ADC, MODE_ABX     ;$7d
                .byte MN_ROR, MODE_ABX     ;$7e
                .byte 0, 0                 ;$7f
                .byte MN_BRA, MODE_REL     ;$80
                .byte MN_STA, MODE_IZX     ;$81
                .byte 0, 0                 ;$82
                .byte 0, 0                 ;$83
                .byte MN_STY, MODE_ZP      ;$84
                .byte MN_STA, MODE_ZP      ;$85
                .byte MN_STX, MODE_ZP      ;$86
                .byte 0, 0                 ;$87
                .byte MN_DEY, MODE_IMPL    ;$88
                .byte MN_BIT, MODE_IMM     ;$89
                .byte MN_TXA, MODE_IMPL    ;$8a
                .byte 0, 0                 ;$8b
                .byte MN_STY, MODE_ABS     ;$8c
                .byte MN_STA, MODE_ABS     ;$8d
                .byte MN_STX, MODE_ABS     ;$8e
                .byte 0, 0                 ;$8f
                .byte MN_BCC, MODE_REL     ;$90
                .byte MN_STA, MODE_IZY     ;$91
                .byte MN_STA, MODE_IZP     ;$92
                .byte 0, 0                 ;$93
                .byte MN_STY, MODE_ZPX     ;$94
                .byte MN_STA, MODE_ZPX     ;$95
                .byte MN_STX, MODE_ZPY     ;$96
                .byte 0, 0                 ;$97
                .byte MN_TYA, MODE_IMPL    ;$98
                .byte MN_STA, MODE_ABY     ;$99
                .byte MN_TXS, MODE_IMPL    ;$9a
                .byte 0, 0                 ;$9b
                .byte MN_STZ, MODE_ABS     ;$9c
                .byte MN_STA, MODE_ABX     ;$9d
                .byte MN_STZ, MODE_ABX     ;$9e
                .byte 0, 0                 ;$9f
                .byte MN_LDY, MODE_IMM     ;$a0
                .byte MN_LDA, MODE_IZX     ;$a1
                .byte MN_LDX, MODE_IMM     ;$a2
                .byte 0, 0                 ;$a3
                .byte MN_LDY, MODE_ZP      ;$a4
                .byte MN_LDA, MODE_ZP      ;$a5
                .byte MN_LDX, MODE_ZP      ;$a6
                .byte 0, 0                 ;$a7
                .byte MN_TAY, MODE_IMPL    ;$a8
                .byte MN_LDA, MODE_IMM     ;$a9
                .byte MN_TAX, MODE_IMPL    ;$aa
                .byte 0, 0                 ;$ab
                .byte MN_LDY, MODE_ABS     ;$ac
                .byte MN_LDA, MODE_ABS     ;$ad
                .byte MN_LDX, MODE_ABS     ;$ae
                .byte 0, 0                 ;$af
                .byte MN_BCS, MODE_REL     ;$b0
                .byte MN_LDA, MODE_IZY     ;$b1
                .byte MN_LDA, MODE_IZP     ;$b2
                .byte 0, 0                 ;$b3
                .byte MN_LDY, MODE_ZPX     ;$b4
                .byte MN_LDA, MODE_ZPX     ;$b5
                .byte MN_LDX, MODE_ZPY     ;$b6
                .byte 0, 0                 ;$b7
                .byte MN_CLV, MODE_IMPL    ;$b8
                .byte MN_LDA, MODE_ABY     ;$b9
                .byte MN_TSX, MODE_IMPL    ;$ba
                .byte 0, 0                 ;$bb
                .byte MN_LDY, MODE_ABX     ;$bc
                .byte MN_LDA, MODE_ABX     ;$bd
                .byte MN_LDX, MODE_ABY     ;$be
                .byte 0, 0                 ;$bf
                .byte MN_CPY, MODE_IMM     ;$c0
                .byte MN_CMP, MODE_IZX     ;$c1
                .byte 0, 0                 ;$c2
                .byte 0, 0                 ;$c3
                .byte MN_CPY, MODE_ZP      ;$c4
                .byte MN_CMP, MODE_ZP      ;$c5
                .byte MN_DEC, MODE_ZP      ;$c6
                .byte 0, 0                 ;$c7
                .byte MN_INY, MODE_IMPL    ;$c8
                .byte MN_CMP, MODE_IMM     ;$c9
                .byte MN_DEX, MODE_IMPL    ;$ca
                .byte 0, 0                 ;$cb
                .byte MN_CPY, MODE_ABS     ;$cc
                .byte MN_CMP, MODE_ABS     ;$cd
                .byte MN_DEC, MODE_ABS     ;$ce
                .byte 0, 0                 ;$cf
                .byte MN_BNE, MODE_REL     ;$d0
                .byte MN_CMP, MODE_IZY     ;$d1
                .byte MN_CMP, MODE_IZP     ;$d2
                .byte 0, 0                 ;$d3
                .byte 0, 0                 ;$d4
                .byte MN_CMP, MODE_ZPX     ;$d5
                .byte MN_DEC, MODE_ZPX     ;$d6
                .byte 0, 0                 ;$d7
                .byte MN_CLD, MODE_IMPL    ;$d8
                .byte MN_CMP, MODE_ABY     ;$d9
                .byte MN_PHX, MODE_IMPL    ;$da
                .byte 0, 0                 ;$db
                .byte 0, 0                 ;$dc
                .byte MN_CMP, MODE_ABX     ;$dd
                .byte MN_DEC, MODE_ABX     ;$de
                .byte 0, 0                 ;$df
                .byte MN_CPX, MODE_IMM     ;$e0
                .byte MN_SBC, MODE_IZX     ;$e1
                .byte 0, 0                 ;$e2
                .byte 0, 0                 ;$e3
                .byte MN_CPX, MODE_ZP      ;$e4
                .byte MN_SBC, MODE_ZP      ;$e5
                .byte MN_INC, MODE_ZP      ;$e6
                .byte 0, 0                 ;$e7
                .byte MN_INX, MODE_IMPL    ;$e8
                .byte MN_SBC, MODE_IMM     ;$e9
                .byte MN_NOP, MODE_IMPL    ;$ea
                .byte 0, 0                 ;$eb
                .byte MN_CPX, MODE_ABS     ;$ec
                .byte MN_SBC, MODE_ABS     ;$ed
                .byte MN_INC, MODE_ABS     ;$ee
                .byte 0, 0                 ;$ef
                .byte MN_BEQ, MODE_REL     ;$f0
                .byte MN_SBC, MODE_IZY     ;$f1
                .byte MN_SBC, MODE_IZP     ;$f2
                .byte 0, 0                 ;$f3
                .byte 0, 0                 ;$f4
                .byte MN_SBC, MODE_ZPX     ;$f5
                .byte MN_INC, MODE_ZPX     ;$f6
                .byte 0, 0                 ;$f7
                .byte MN_SED, MODE_IMPL    ;$f8
                .byte MN_SBC, MODE_ABY     ;$f9
                .byte MN_PLX, MODE_IMPL    ;$fa
                .byte 0, 0                 ;$fb
                .byte 0, 0                 ;$fc
                .byte MN_SBC, MODE_ABX     ;$fd
                .byte MN_INC, MODE_ABX     ;$fe
                .byte 0, 0                 ;$ff

mnemonics2      .byte  "DEX", 0         ; 0
                .byte  "DEY", 0         ; 4
                .byte  "TAX", 0         ; 8
                .byte  "TSB", 0         ; 12
                .byte  "BPL", 0         ; 16
                .byte  "BCC", 0         ; 20
                .byte  "CPX", 0         ; 24
                .byte  "EOR", 0         ; 28
                .byte  "TSX", 0         ; 32
                .byte  "DEC", 0         ; 36
                .byte  "STA", 0         ; 40
                .byte  "LDA", 0         ; 44
                .byte  "BEQ", 0         ; 
                .byte  "ROL", 0         ; 
                .byte  "STY", 0
                .byte  "JMP", 0
                .byte  "BMI", 0
                .byte  "RTI", 0
                .byte  "TAY", 0
                .byte  "TXA", 0
                .byte  "RTS", 0
                .byte  "SED", 0
                .byte  "LSR", 0
                .byte  "BNE", 0
                .byte  "JSR", 0
                .byte  "LDY", 0
                .byte  "SEC", 0
                .byte  "BIT", 0
                .byte  "LDX", 0
                .byte  "TXS", 0
                .byte  "SEI", 0
                .byte  "ASL", 0
                .byte  "BVS", 0
                .byte  "CPY", 0
                .byte  "CLI", 0
                .byte  "CLD", 0
                .byte  "TRB", 0
                .byte  "CLC", 0
                .byte  "BCS", 0
                .byte  "ADC", 0
                .byte  "CLV", 0
                .byte  "STX", 0
                .byte  "ROR", 0
                .byte  "STZ", 0
                .byte  "AND", 0
                .byte  "PHP", 0
                .byte  "INX", 0
                .byte  "INY", 0
                .byte  "PLP", 0
                .byte  "PHA", 0
                .byte  "CMP", 0
                .byte  "TYA", 0
                .byte  "PLY", 0
                .byte  "PLX", 0
                .byte  "BVC", 0
                .byte  "SBC", 0
                .byte  "PHY", 0
                .byte  "PHX", 0
                .byte  "BRK", 0
                .byte  "PLA", 0
                .byte  "INC", 0
                .byte  "NOP", 0
                .byte  "BRA", 0
                .byte  "ORA", 0


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