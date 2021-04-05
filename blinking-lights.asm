PORTB = $6000
DDRB = $6002

  .org $8000

reset:
  lda #%11111111 ; Set all pins on port B to output
  sta DDRB

loop:
  lda #%10101010
  sta $b1
  lda $b1
  sta PORTB

  lda #%01010101
  sta $b0
  lda $b0

  sta PORTB

  jmp loop

  .org $fffc
  .word reset
  .word $0000
