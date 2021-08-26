RDKEY           =       $C0C2

                .ORG    $0300           ; Bootloader calls this on IRQ
                .ORG    $0308           ; Bootloader calls this on reset

RESET           JSR     SCRNSETUP
                CLI

NXTCHAR         JSR     RDKEY           ; puts an ascii char in A. If 0, then no key is pressed
                BEQ     NXTCHAR         ; 0 in A means no character from keyboard
                JSR     ECHO            ; if there's a key, echo it
                JMP     NXTCHAR

                .include "text_screen.inc"
