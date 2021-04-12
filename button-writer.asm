VIA_PORTB   = $6000                         ; Port B input / output register
VIA_PORTA   = $6001                         ; Port A input / output register
VIA_DDRB    = $6002                         ; Port B data direction_register
VIA_DDRA    = $6003                         ; Port A data direction_register
VIA_ACR     = $600b                         ; Auxilary Control Register
VIA_PCR     = $600c                         ; Periphiral Control Register
VIA_IFR     = $600d                         ; Interrupt Flag register
VIA_IER     = $600e                         ; Interrupt enable register

; LCD display
; Read the busy flag when RS: 0 (instruction) and RW = 1 (write).  Busy flag is output to DB7
LCD_E  = %10000000                          ; Pin to start data read/write
LCD_RW = %01000000                          ; Pin to select read or write (0: read, 1: write)
LCD_RS = %00100000                          ; Register select (0: instructions, 1: data)

CHAR_POS = $0a
BUTTONS_READ = $0b
  
                                            ; start address of the ROM, as seen by the CPU
                  .org $8000                ; 1000000000000000

reset:            ldx #$ff
                  txs

                                            ; configure interrupts
                  lda #$82                  ; enable CA1
                  sta VIA_IER
                  lda #%00000001            ; set CA1 to high egde
                  sta VIA_PCR
                  lda #%00000001            ; enable latching on PA
                  sta VIA_ACR

                  lda #%11111111            ; Set all pins on port B to output, used by LCD
                  sta VIA_DDRB
                  lda #%11100000            ; Set top 3 pins on port A to output, used by LCD
                  sta VIA_DDRA

                                            ; setup LCD
                  lda #%00111000            ; Set 8-bit mode; 2-line display; 5x8 font
                  jsr lcd_instruction
                  lda #%00001110            ; Display on; cursor on; blink off
                  jsr lcd_instruction
                  lda #%00000110            ; Increment and shift cursor; don't shift display
                  jsr lcd_instruction
                  lda #$00000001            ; Clear display
                  jsr lcd_instruction

                  lda #0
                  sta CHAR_POS
                  cli                       ; enable interrupts

loop:
                  lda BUTTONS_READ
                  and #%00000111
                  beq loop                  ; do nothing if no buttons were pressed

                  lda BUTTONS_READ
                  and #%00000100            ; the button to go to the next character
                  beq select_letter
                  lda #%00010100            ; move cursor to the right to the next charachter can be picked
                  jsr lcd_instruction
                  jmp done_selecting

select_letter:
                  lda BUTTONS_READ
                  and #%00000001
                  beq button_2_pressed
                  dec CHAR_POS
                  jmp done_selecting
button_2_pressed: inc CHAR_POS
done_selecting:   ldx CHAR_POS
                  lda alphabet,x
                  jsr print_char
                  lda #%00010000            ; move cursor to the left, on top of the selecting char
                  jsr lcd_instruction
                  lda #0
                  sta BUTTONS_READ   
                  jmp loop

alphabet:         .asciiz "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

lcd_wait:         pha
                  lda #%00000000            ; Port B is input, to read the busy flag
                  sta VIA_DDRB
lcdbusy:          lda #LCD_RW               ; RW pin needs to be high to read busy flag
                  sta VIA_PORTA
                  lda #(LCD_RW | LCD_E)     ; Set enable bit high to send the instruction
                  sta VIA_PORTA
                  lda VIA_PORTB             ; Load Port B where bit 7 will have busy flag
                  and #%10000000
                  bne lcdbusy               ; if the busy flag is 0, we can continue
                  lda #LCD_RW               ; Set enable pin back to low (only leaving write mode)
                  sta VIA_PORTA
                  lda #%11111111            ; Done reading the busy flag, set Port B back output
                  sta VIA_DDRB
                  pla
                  rts

lcd_instruction:  jsr lcd_wait
                  sta VIA_PORTB             ; instruction was set in A by caller
                  lda #0                    ; Clear LCD_RS/LCD_RW/LCD_E bits
                  sta VIA_PORTA
                  lda #LCD_E                ; Set LCD_E bit to send instruction
                  sta VIA_PORTA
                  lda #0                    ; Clear LCD_RS/LCD_RW/LCD_E bits
                  sta VIA_PORTA
                  rts

print_char:       jsr lcd_wait
                  sta VIA_PORTB
                  lda #LCD_RS               ; Set RS; Clear LCD_RW/E bits
                  sta VIA_PORTA
                  lda #(LCD_RS | LCD_E)     ; Set LCD_E bit to send instruction
                  sta VIA_PORTA
                  lda #LCD_RS               ; Clear LCD_E bits
                  sta VIA_PORTA
                  rts

nmi:              rti

irq:              txa
                  pha
                  tya
                  pha
                  
                  ldx #$ff                  ; shitty delay to debounce the button
                  ldy #$90
irq_delay:        dex
                  bne irq_delay
                  dey
                  bne irq_delay
                  
                  lda VIA_PORTA             ; read the buttons from Port A
                  and #%00000111            ; only keep button info
                  sta BUTTONS_READ          ; restore registers
                  
                  pla
                  tay
                  pla
                  tax
                  rti

vectors:          .org $fffa                ; 1111111111111010
                  .word nmi                 ; fffa, fffb
                  .word reset               ; fffc, fffd
                  .word irq                 ; fffe, ffff
