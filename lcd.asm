; MATRIX Constants
LCD_RS  = %00000001
LCD_RW  = %00000010
LCD_E   = %00000100
LCD_RST = %00001000


; Matrix Initialisation
; Overrides A
lcd_init:
    ; Set direction of DDRB to (DDRB | 00001111)
    lda DDRB
    ora #(LCD_RS | LCD_RW | LCD_E | LCD_RST)
    sta DDRB

    ; Set Port A (Data) to Output
    lda #0b11111111
    sta DDRA

    ; Disable E, RS, RST & RW
    lda PORTB
    and #~(LCD_E | LCD_RS | LCD_RW | LCD_RST)
    sta PORTB

    ; Enable RST
    lda PORTB
    ora #LCD_RST
    sta PORTB

    ; Initialise function setup
    ; Runs twice to ensure both 8 bit and extended = 0 are set
    ; As only one can change per call
    jsr lcd_function_set
    jsr lcd_function_set

    ; Clear screen
    jsr lcd_clear

    lda #0b00000110 ; Entry mode set - Move right, Shift off
    jsr lcd_command

    lda #0b00000010 ; Home
    jsr lcd_command

    jsr lcd_clear
    jsr lcd_function_set_extended
    jsr lcd_function_set_extended_graphics
    jsr draw_blank_screen

    rts


; Wait for Matrix to complete current command
; Overrides Nothing
lcd_wait:
    ; Store A
    pha
    ; Set Port A (Data) to input
    lda #0b00000000
    sta DDRA
_lcd_busy:
    ; Set E, RW and RS to 0
    lda PORTB
    and #~(LCD_E| LCD_RS | LCD_RW)
    sta PORTB
    ; Set E and RW to 1
    lda PORTB
    ora #LCD_RW
    sta PORTB
    ora #LCD_E
    sta PORTB
    ; Read data from Port A (Data) and loop if BF flag is 1
    lda PORTA
    and #0b10000000
    bne _lcd_busy

    ; Otherwise disable E, RW and RS
    lda PORTB
    and #~(LCD_E | LCD_RS | LCD_RW)
    sta PORTB
    ; Return Port A (Data) to output
    lda #0b11111111
    sta DDRA
    ; Restore A
    pla

    rts


; Run MATRIX Commands (e.g. Function Set, Display On)
; A = Command to run (Bytes to send)
lcd_command:
    jsr lcd_wait
    ; Put command on Port A (Data)
    sta PORTA
    ; Enable E
    lda PORTB
    ora #LCD_E
    sta PORTB
    ; Disable E
    lda PORTB
    and #~LCD_E
    sta PORTB
    
    rts


; Set Matrix to 8 bit, Basic Instructions
; Overrides A
lcd_function_set:
    lda #0b00110000
    jsr lcd_command

    rts


; Set Matrix to 8 bit, Extended Instructions
; Overrides A
lcd_function_set_extended:
    lda #0b00110100
    jsr lcd_command

    rts

; Set Matrix to 8 bit, Extended Instructions with Graphics Enabled
; Overrides A 
lcd_function_set_extended_graphics:
    lda #0b00110110
    jsr lcd_command

    rts

; Clear MATRIX Screen & return home
; Overrides A
lcd_clear:
    lda #0b00000001
    jsr lcd_command
    
    rts


; Set GDRAM/DDRAM address
; A = Coord
; Note: Write twice to complete vertical & horizontal pair (in that order)
; Vertical range =   0 - 31
; Horizontal range = 0 - 15
;
; Top screen is range (X = 0-7, Y = 0-31)
; Bottom screen is range (X = 8-15, Y = 0-31)
lcd_set_gdram_address:
    ora #0b10000000
    jsr lcd_command

    rts


; Write data to Matrix RAM
; A = Data to write
lcd_write:
    sta PORTA
    ; Enable RS
    lda PORTB
    ora #LCD_RS
    sta PORTB
    ; Enable E
    ora #LCD_E
    sta PORTB
    ; Reset E & RS
    and #~(LCD_E | LCD_RS)
    sta PORTB

    rts


; Read data from Matrix RAM
; Returns A = Data
lcd_read:
    ; Set PORTA (Data) to input
    lda #0
    sta DDRA
    ; Enable RS & RW
    lda PORTB
    ora #(LCD_RS | LCD_RW)
    sta PORTB

    ; Read
    ora #LCD_E
    sta PORTB
    lda PORTA
    pha

    ; Reset E, RS & RW
    lda PORTB
    and #~(LCD_E | LCD_RS | LCD_RW)
    sta PORTB

    ; Restore PORTA (Data) to output
    lda #0b11111111
    sta DDRA

    pla
    rts


; Draw 0x00 to screen to empty ram
; Overrides A, X and Y
draw_blank_screen:
    ldx #0
    ldy #0
_draw_blank_screen_loop_y:
_draw_blank_screen_loop_x:
    tya
    jsr lcd_set_gdram_address
    txa
    jsr lcd_set_gdram_address
    lda #0
    jsr lcd_write
    lda #0
    jsr lcd_write

    inx
    cpx #32
    bne _draw_blank_screen_loop_x

    ldx #0
    
    iny
    cpy #32
    bne _draw_blank_screen_loop_y

    rts
