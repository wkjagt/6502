; 6522 
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

; interrupt registers
ACR = $600b
PCR = $600c
IFR = $600d
IER = $600e

E  = %10000000
RW = %01000000
RS = %00100000

CHAR_POS = $0a
BUTTONS_READ = $0b

  .org $8000      ; 1000000000000000

reset:
  ldx #$ff
  txs

  ; setup 6522 --------------
  ; configure interrupts
  lda #$82 ; enable CA1
  sta IER
  lda #%00000001   ; set CA1 to high egde
  sta PCR
  lda #%00000001   ; enable latching on PA
  sta ACR

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

  lda #0
  sta CHAR_POS

  cli           ; enable interrupts

loop:
  lda BUTTONS_READ
  and #%00000111
  beq loop               ; do nothing if no buttons were pressed

  lda BUTTONS_READ
  and #%00000100         ; the button to go to the next character
  beq select_letter
  lda #%00010100         ; move cursor to the right to the next charachter can be picked
  jsr lcd_instruction
  jmp done_selecting

select_letter:
  lda BUTTONS_READ
  and #%00000001
  beq button_2_pressed
  dec CHAR_POS
  jmp done_selecting
button_2_pressed:
  inc CHAR_POS
  
done_selecting:
  ldx CHAR_POS
  lda alphabet,x
  jsr print_char
  lda #%00010000         ; move cursor to the left, on top of the selecting char
  jsr lcd_instruction

  lda #0
  sta BUTTONS_READ   
  jmp loop

; end of main loop

alphabet: .asciiz "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

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
  rti
irq:
; store the registers to the stack
  sei
  txa
  pha
  tya
  pha

; shitty delay to debounce the button
  ldx #$ff
  ldy #$90
irq_delay:
  dex
  bne irq_delay
  dey
  bne irq_delay

  ; read the buttons from Port A
  lda PORTA      ; this removes the interrupt request
  and #%00000111 ; only keep button info
  sta BUTTONS_READ

; restore registers
  pla
  tay
  pla
  tax
  rti

; setup the vectors (interrupt and reset)
  .org $fffa      ; 1111111111111010
  .word nmi       ; fffa, fffb
  .word reset     ; fffc, fffd
  .word irq       ; fffe, ffff
