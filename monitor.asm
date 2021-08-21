    .include "macros.inc"

IRQ   = $0300
START = IRQ + 8

    .org IRQ
    jsr interrupt
    rts

    .org START
    jsr keyboard_setup
    jsr screen_setup
    cli
next_char:
    jsr read_key                    ; puts an ascii char in A. If 0, then no key is pressed
    beq next_char                   ; 0 in A means no character from keyboard
    jsr echo                        ; if there's a key, echo it
.no_key
    jmp next_char

    .include "interrupts.inc"
    .include "text_screen.inc"
    .include "keyboard.inc"
