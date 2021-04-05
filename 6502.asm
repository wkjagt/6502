  .org $8000

reset:

loop:
  lda #$55
  sta $0200
  lda $0200
  jmp loop

lcd_instruction:

  .org $fffc
  .word reset
  .word $0000
