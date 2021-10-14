RDKEY           =       $83CC
SER_BYTE        =       $8393
IO_PORTB        =       $6000           ; Data port B
IO_PORTA        =       $6001           ; Data port A
IO_DDRB         =       $6002           ; Data direction of port B
IO_DDRA         =       $6003           ; Data direction of port A

LED_STATE       =       $200

                .ORG    $0700

START           JSR     SCRNSETUP

NXTCHAR         JSR     SER_BYTE
                JSR     ECHO
                CMP     #ENTER
                JMP     NXTCHAR

                .include "text_screen.inc"
