.import io_a
.import io_b
.import io_ddrb

.define E     %10000000
.define RW    %01000000
.define RS    %00100000

.segment "CODE"

.proc setup_lcd          
  lda #%00111000          ; Set 8-bit mode; 2-line display; 5x8 font
  jsr send_lcd_command
  lda #%00001110          ; Display on; cursor on; blink off
  jsr send_lcd_command
  lda #%00000110          ; Increment and shift cursor; don't shift display
  jsr send_lcd_command
  lda #$00000001          ; Clear display
  jsr send_lcd_command
  rts
.endproc

.proc lcd_wait           
  pha
  lda #%00000000          ; Port B is input to read busy LCD busy flag
  sta io_ddrb
lcdbusy:            
  lda #RW
  sta io_a
  lda #(RW | E)
  sta io_a
  lda io_b
  and #%10000000
  bne lcdbusy

  lda #RW
  sta io_a
  lda #%11111111          ; Port B is output
  sta io_ddrb
  pla
  rts
.endproc

.proc send_lcd_command
  jsr lcd_wait
  sta io_b
  lda #0                  ; Clear RS/RW/E bits
  sta io_a
  lda #E                  ; Set E bit to send instruction
  sta io_a
  lda #0                  ; Clear RS/RW/E bits
  sta io_a
  nop
  rts
.endproc

.proc write_lcd          
  jsr lcd_wait
  sta io_b
  ldy #RS                 ; Set RS; Clear RW/E bits
  sty io_a
  ldy #(RS|E)             ; Set E bit to send instruction
  sty io_a
  ldy #RS                 ; Clear E bits
  sty io_a
  nop
  rts
.endproc