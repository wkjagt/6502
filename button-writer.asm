; 6522 
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

; interrupt registers
PCR = $600c
IFR = $600d
IER = $600e


E  = %10000000
RW = %01000000
RS = %00100000

DISPLAY_CHAR = $09

  .org $8000      ; 1000000000000000

reset:
  ldx #$ff
  txs
  cli           ; enable interrupts

  ; setup 6522 --------------
  ; configire interrupts
  lda #$82 ; enable CA1
  sta IER
  lda #0   ; set CA1 to low egde
  sta PCR

  lda #%11111111 ; Set all pins on port B to output, used by LCD
  sta DDRB
  lda #%11100000 ; Set top 3 pins on port A to output, used by LCD
  sta DDRA

  ; setup LCD ---------------
  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #$00000001 ; Clear display
  jsr lcd_instruction

  lda #">"
  jsr print_char

  lda #0
  sta DISPLAY_CHAR

loop:
  lda #0
  cmp DISPLAY_CHAR
  beq loop

  lda DISPLAY_CHAR
  jsr print_char
  lda #0
  sta DISPLAY_CHAR

  jmp loop

lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  lda #E         ; Set E bit to send instruction
  sta PORTA
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS         ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta PORTA
  lda #RS         ; Clear E bits
  sta PORTA
  rts

nmi:
irq:
  ; store the registers to the stack
  pha
  txa
  pha
  tya
  pha

  ldx #$ff
  ldy #$20
irq_delay:
  dex
  bne irq_delay
  dey
  bne irq_delay

  lda #"!"
  sta DISPLAY_CHAR

  bit PORTA       ; just reading PORTA so the 6522 knows we've handled the interrupt

  ; restore registers
  pla
  tay
  pla
  tax
  pla
  
  rti



  .org $fffa      ; 1111111111111010
  .word nmi       ; fffa, fffb
  .word reset     ; fffc, fffd
  .word irq       ; fffe, ffff
