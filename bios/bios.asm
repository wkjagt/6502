;==============================================================================
; Addresses for registers on the 6522 VIA
;==============================================================================
IO_PORTB = $6000                        ; Data port B
IO_PORTA = $6001                        ; Data port A
IO_DDRB  = $6002                        ; Data direction of port B
IO_DDRA  = $6003                        ; Data direction of port A
IO_PCR   = $600c                        ; Peripheral control register
IO_IFR   = $600d                        ; Interrupt flag register
IO_IER   = $600e                        ; Interrupt enable register

;==============================================================================
; Addresses for registers on the 6551 ACIA
;==============================================================================
SER_DATA = $4000                        ; Data regiter
SER_ST   = $4001                        ; Status register
SER_CMD  = $4002                        ; Command register
SER_CTL  = $4003                        ; Control register

;==============================================================================
; Constants related to the 6551 ACIA
;==============================================================================
SER_RXFL    = 1 << 3 ; Serial Receive full bit

;==============================================================================
; Constants related to the functioning of the PS/2 keyboard
;==============================================================================
KB_RLS   = %00000001                    ; Release flag
KB_SHFT  = %00000010                    ; Shift flag
KB_RLSCD = $F0                          ; Release scan code
KB_LSHFT = $12                          ; Left shift scan code
KB_RSHFT = $59                          ; Right shift scan code
KB_MXSNC = $7e                          ; Ignore scan codes above

;==============================================================================
; RAM addresses for keyboard usage
;==============================================================================
KB_RPTR  = $30                          ; 8 bit read pointer into buffer
KB_WPTR  = $31                          ; 8 bit write pointer into buffer
KB_FLAGS = $32                          ; Keyboard flags (for release, shift, ...)
KB_BFR   = $0200                        ; one page for keyboard buffer

;==============================================================================
; RAM addresses for the 16 bit pointer for writing a program to RAM
;==============================================================================
PRG_WPTR  = $0002                       ; The LSB of the program write pointer

;==============================================================================
; The start of the program in RAM. Used to start writing to, and
; to jump to once the program is loaded
;==============================================================================
PRG_STRT  = $0700

  .org $c000

  .include "vdp.asm"

RESET:          sei
;==============================================================================
; Initialize the 6551 ACIA for serial communication
;==============================================================================
                lda     #%11001011      ; No parity, no echo, no interrupt
                sta     SER_CMD
                lda     #%00011111      ; 1 stop bit, 8 data bits, 19200 baud
                sta     SER_CTL
;==============================================================================
; Initialize the program pointers for writing bytes to RAM
;==============================================================================
                lda     #<PRG_STRT
                sta     PRG_WPTR
                lda     #>PRG_STRT
                sta     PRG_WPTR + 1
;==============================================================================
; Initialize the TMS9918A VDP video chip
;==============================================================================
                jsr     vdp_setup
;==============================================================================
; Initialize the PS/2 keyboard interface
;==============================================================================
                jsr     KBSETUP

;==============================================================================
; The main program loop for loading a program into RAM over serial
; Once the ASCII code for the "l" character (for "load") is received,
; kick off the LOAD_PRG routine.
; When control is returned from that routine, JMP to the program start
; address.
;==============================================================================
LOOP:           jsr     RD_SRL_B
                cmp     #"l"
                bne     LOOP
                jsr     LOAD_PRG
                jsr     PRG_STRT
                jmp     LOOP
;==============================================================================
; The program load routine is a very much simplified implementation of
; xmodem. It leaves out all error checking, but is otherwise pretty much
; identical.
;==============================================================================
LOAD_PRG:       
.HEADER:        jsr     RD_SRL_B         ; Read a character over serial
                cmp     #$04                     ; $04 is the End Of Transmission Character
                                              ; and can be received after each packet
                beq     .DONE                    ; We're done once that's received.
                                              ; The other byte is assumed to be a Start
                                              ; of header byte, but we're not checking for it.
                ldy     #$80                     ; packet size: 128 bytes
.PRG_BYTE:      jsr     RD_SRL_B         ; This reads one byte into RAM, by using
                sta     (PRG_WPTR)    ; the pointer we're keeping in the zero page.
                jsr     INC_PRG_PT
                dey
                beq     .HEADER             ; when y == 0, end of packet
                jmp     .PRG_BYTE            ; after loading each packet, check the header byte
.DONE:          rts

INC_PRG_PT:     inc     PRG_WPTR
                bne     .DONE
                inc     PRG_WPTR + 1
.DONE:          rts

;==============================================================================
; Read one byte from the serial connection provided by the 6551 ACIA
;==============================================================================
RD_SRL_B:       lda     SER_ST
                and     #SER_RXFL
                beq     RD_SRL_B
                lda     SER_DATA
                rts

;==============================================================================
; Interrupt handlers
;==============================================================================
NMI:            rti
IRQ:            pha
                phy
                phx
                lda     IO_IFR
                bit     #%10000000      ; Gneral IRQ flag. This is set if any of the specific flags are set
                beq     .DONE           ; False: no interrupts on the 6522
                bit     #%00000010      ; CA2 flag
                beq     .DONE
                jsr     KB_IRQ
.DONE           plx
                ply
                pla
                rti

;==============================================================================
; Initialize the PS/2 keyboard interface that uses the 6522 VIA for
; interrupt handling and data reading. 
; The PS/2 hardware triggers the CA1 with a positive edge when data is
; available on port A.
;==============================================================================
KBSETUP:        lda     #0              ; set port A as input (for keyboard)
                sta     IO_DDRA
                lda     #%10000010      ; enable interrupt on CA1
                sta     IO_IER
                lda     #%00000001      ; set CA1 as positive active edge
                sta     IO_PCR
                lda     #0
                sta     KB_RPTR
                sta     KB_WPTR
                sta     KB_FLAGS
                rts

;==============================================================================
; Read one key from the keyboard buffer into the A register. A is loaded with
; 0 when no new key is pressed. When a key is pressed, the read pointer is
; incremented.
;==============================================================================
RDKEY:          lda     KB_RPTR
                cmp     KB_WPTR
                beq     .NO_KEY
                ldx     KB_RPTR
                inc     KB_RPTR
                lda     KB_BFR, x
                rts
.NO_KEY:        lda     #0
                rts

;==============================================================================
; The keyboard key press handler that is triggered by an IRQ
;==============================================================================
KB_IRQ:         pha
                phy
                phx
;==============================================================================
; Check the keyboard flags for the key release flag. If it is set, this means
; that the previous scan code was for a key release, and the current interrupt
; signals the scan code for the actual key that was released. If the flag
; isn't set, go ahead and read the key as usual. If the flag is set, reset it
; and handle the scan code as a key release.
;==============================================================================
                lda     KB_FLAGS        ; read the current keyboard flags
                and     #KB_RLS         ; see if the previous scan code was for a key release 
                beq     .READ_KEY       ; if it isn't, go ahead and read the key
                lda     KB_FLAGS                  
                eor     #KB_RLS         ; the previous code was a release, so the new code
                                        ; is for the key that's being released.
                sta     KB_FLAGS        ; Turn off the release flag
;==============================================================================
; Read the scan code for the key that was released. If it is for one of the
; shift keys, it means that shift is no longer being pressed, and we need to
; handle that. If a different key was released, we ignore it, as we don't
; (yet) handle any other key combinations.
;==============================================================================
                lda     IO_PORTA        ; Read the key that's being released
                cmp     #KB_LSHFT       ; It's the shift key that was released: handle that case
                beq     .SHIFT_UP
                cmp     #KB_RSHFT
                beq     .SHIFT_UP
                jmp     .DONE
;==============================================================================
; When shift is released, we need to reset the shift flag
;==============================================================================
.SHIFT_UP:      lda KB_FLAGS            ; turn off the shift flag
                eor #KB_SHFT
                sta KB_FLAGS
                jmp .DONE
;==============================================================================
; Interpet a scan code other than the code of a released key is received. This
; block interprets that scan code.
;==============================================================================
.READ_KEY:      ldx IO_PORTA            ; load ps/2 scan code
                txa
;==============================================================================
; Handle special cases that aren't characters (release codes and shift keys)
;==============================================================================
                cmp #KB_RLSCD           ; keyboard release code
                beq .RELEASE
                cmp #KB_LSHFT
                beq .SHFT_DWN
                cmp #KB_RSHFT
                beq .SHFT_DWN
;==============================================================================
; Ignore scan codes above KB_MXSNC because there's nothing there we
; want to use for now.
;==============================================================================
                cmp #KB_MXSNC           ; highest interpreted value
                bcs .DONE               ; carry set: >=
;==============================================================================
; The scan code is for a character. First load the keyboard flags to check
; the SHIFT flag. If the flag is set, we look up the ASCII code for the
; character in the shifted map. Otherwise, use the unshifted map.
;==============================================================================
                lda KB_FLAGS
                and #KB_SHFT
                bne .SHIFTED
                lda KEYS, x
                jmp .TO_BFR
.SHIFTED:       lda KEYS_SHFT, x
;==============================================================================
; Write the received character to the keyboard buffer, and advance the write
; pointer. This causes the write pointer to be ahead of the read pointer
; which will be detected by the routine that checks for new characters that
; haven't been used yet.
;==============================================================================
.TO_BFR:        beq .DONE           ; don't put anything in the buffer if a 0 is found in the KEYS
                ldx KB_WPTR
                sta KB_BFR, x
                inc KB_WPTR
                jmp .DONE
; ==============================================================================
; Handle the case of the shift key being pressed by setting the shift flag
; in the keyboard flags.
; ==============================================================================
.SHFT_DWN:      lda KB_FLAGS
                ora #KB_SHFT
                sta KB_FLAGS
                jmp .DONE
; ==============================================================================
; Handle the case of the release scan code being received because this means
; that the next scan code identies which key was released.
; ==============================================================================
.RELEASE:       lda KB_FLAGS
                ora #KB_RLS
                sta KB_FLAGS
                jmp .DONE
.DONE           plx
                ply
                pla
                rts


vdp_patterns:
  ; characters follow ASCII order but leave out all non printing characters
  ; before the space character
  .byte $00,$00,$00,$00,$00,$00,$00,$00 ; ' '
  .byte $20,$20,$20,$00,$20,$20,$00,$00 ; !
  .byte $50,$50,$50,$00,$00,$00,$00,$00 ; "
  .byte $50,$50,$F8,$50,$F8,$50,$50,$00 ; #
  .byte $20,$78,$A0,$70,$28,$F0,$20,$00 ; $
  .byte $C0,$C8,$10,$20,$40,$98,$18,$00 ; %
  .byte $40,$A0,$A0,$40,$A8,$90,$68,$00 ; &
  .byte $20,$20,$40,$00,$00,$00,$00,$00 ; '
  .byte $20,$40,$80,$80,$80,$40,$20,$00 ; (
  .byte $20,$10,$08,$08,$08,$10,$20,$00 ; )
  .byte $20,$A8,$70,$20,$70,$A8,$20,$00 ; *
  .byte $00,$20,$20,$F8,$20,$20,$00,$00 ; +
  .byte $00,$00,$00,$00,$20,$20,$40,$00 ; ,
  .byte $00,$00,$00,$F8,$00,$00,$00,$00 ; -
  .byte $00,$00,$00,$00,$20,$20,$00,$00 ; .
  .byte $00,$08,$10,$20,$40,$80,$00,$00 ; /
  .byte $70,$88,$98,$A8,$C8,$88,$70,$00 ; 0
  .byte $20,$60,$20,$20,$20,$20,$70,$00 ; 1
  .byte $70,$88,$08,$30,$40,$80,$F8,$00 ; 2
  .byte $F8,$08,$10,$30,$08,$88,$70,$00 ; 3
  .byte $10,$30,$50,$90,$F8,$10,$10,$00 ; 4
  .byte $F8,$80,$F0,$08,$08,$88,$70,$00 ; 5
  .byte $38,$40,$80,$F0,$88,$88,$70,$00 ; 6
  .byte $F8,$08,$10,$20,$40,$40,$40,$00 ; 7
  .byte $70,$88,$88,$70,$88,$88,$70,$00 ; 8
  .byte $70,$88,$88,$78,$08,$10,$E0,$00 ; 9
  .byte $00,$00,$20,$00,$20,$00,$00,$00 ; :
  .byte $00,$00,$20,$00,$20,$20,$40,$00 ; ;
  .byte $10,$20,$40,$80,$40,$20,$10,$00 ; <
  .byte $00,$00,$F8,$00,$F8,$00,$00,$00 ; =
  .byte $40,$20,$10,$08,$10,$20,$40,$00 ; >
  .byte $70,$88,$10,$20,$20,$00,$20,$00 ; ?
  .byte $70,$88,$A8,$B8,$B0,$80,$78,$00 ; @
  .byte $20,$50,$88,$88,$F8,$88,$88,$00 ; A
  .byte $F0,$88,$88,$F0,$88,$88,$F0,$00 ; B
  .byte $70,$88,$80,$80,$80,$88,$70,$00 ; C
  .byte $F0,$88,$88,$88,$88,$88,$F0,$00 ; D
  .byte $F8,$80,$80,$F0,$80,$80,$F8,$00 ; E
  .byte $F8,$80,$80,$F0,$80,$80,$80,$00 ; F
  .byte $78,$80,$80,$80,$98,$88,$78,$00 ; G
  .byte $88,$88,$88,$F8,$88,$88,$88,$00 ; H
  .byte $70,$20,$20,$20,$20,$20,$70,$00 ; I
  .byte $08,$08,$08,$08,$08,$88,$70,$00 ; J
  .byte $88,$90,$A0,$C0,$A0,$90,$88,$00 ; K
  .byte $80,$80,$80,$80,$80,$80,$F8,$00 ; L
  .byte $88,$D8,$A8,$A8,$88,$88,$88,$00 ; M
  .byte $88,$88,$C8,$A8,$98,$88,$88,$00 ; N
  .byte $70,$88,$88,$88,$88,$88,$70,$00 ; O
  .byte $F0,$88,$88,$F0,$80,$80,$80,$00 ; P
  .byte $70,$88,$88,$88,$A8,$90,$68,$00 ; Q
  .byte $F0,$88,$88,$F0,$A0,$90,$88,$00 ; R
  .byte $70,$88,$80,$70,$08,$88,$70,$00 ; S
  .byte $F8,$20,$20,$20,$20,$20,$20,$00 ; T
  .byte $88,$88,$88,$88,$88,$88,$70,$00 ; U
  .byte $88,$88,$88,$88,$50,$50,$20,$00 ; V
  .byte $88,$88,$88,$A8,$A8,$D8,$88,$00 ; W
  .byte $88,$88,$50,$20,$50,$88,$88,$00 ; X
  .byte $88,$88,$50,$20,$20,$20,$20,$00 ; Y
  .byte $F8,$08,$10,$20,$40,$80,$F8,$00 ; Z
  .byte $F8,$C0,$C0,$C0,$C0,$C0,$F8,$00 ; [
  .byte $00,$80,$40,$20,$10,$08,$00,$00 ; \
  .byte $F8,$18,$18,$18,$18,$18,$F8,$00 ; ]
  .byte $00,$00,$20,$50,$88,$00,$00,$00 ; ^
  .byte $00,$00,$00,$00,$00,$00,$F8,$00 ; _
  .byte $40,$20,$10,$00,$00,$00,$00,$00 ; `
  .byte $00,$00,$70,$88,$88,$98,$68,$00 ; a
  .byte $80,$80,$F0,$88,$88,$88,$F0,$00 ; b
  .byte $00,$00,$78,$80,$80,$80,$78,$00 ; c
  .byte $08,$08,$78,$88,$88,$88,$78,$00 ; d
  .byte $00,$00,$70,$88,$F8,$80,$78,$00 ; e
  .byte $30,$40,$E0,$40,$40,$40,$40,$00 ; f
  .byte $00,$00,$70,$88,$F8,$08,$F0,$00 ; g
  .byte $80,$80,$F0,$88,$88,$88,$88,$00 ; h
  .byte $00,$40,$00,$40,$40,$40,$40,$00 ; i
  .byte $00,$20,$00,$20,$20,$A0,$60,$00 ; j
  .byte $00,$80,$80,$A0,$C0,$A0,$90,$00 ; k
  .byte $C0,$40,$40,$40,$40,$40,$60,$00 ; l
  .byte $00,$00,$D8,$A8,$A8,$A8,$A8,$00 ; m
  .byte $00,$00,$F0,$88,$88,$88,$88,$00 ; n
  .byte $00,$00,$70,$88,$88,$88,$70,$00 ; o
  .byte $00,$00,$70,$88,$F0,$80,$80,$00 ; p
  .byte $00,$00,$F0,$88,$78,$08,$08,$00 ; q
  .byte $00,$00,$70,$88,$80,$80,$80,$00 ; r
  .byte $00,$00,$78,$80,$70,$08,$F0,$00 ; s
  .byte $40,$40,$F0,$40,$40,$40,$30,$00 ; t
  .byte $00,$00,$88,$88,$88,$88,$78,$00 ; u
  .byte $00,$00,$88,$88,$90,$A0,$40,$00 ; v
  .byte $00,$00,$88,$88,$88,$A8,$D8,$00 ; w
  .byte $00,$00,$88,$50,$20,$50,$88,$00 ; x
  .byte $00,$00,$88,$88,$78,$08,$F0,$00 ; y
  .byte $00,$00,$F8,$10,$20,$40,$F8,$00 ; z
  .byte $38,$40,$20,$C0,$20,$40,$38,$00 ; {
  .byte $40,$40,$40,$00,$40,$40,$40,$00 ; |
  .byte $E0,$10,$20,$18,$20,$10,$E0,$00 ; }
  .byte $40,$A8,$10,$00,$00,$00,$00,$00 ; ~
; non ascii
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00 ; cursor
vdp_end_patterns:

;========================================================================
; These two maps map PS/2 scan codes to their respective ASCII codes.
; Any bytes higher than $7e are ignored for now because there isn't
; anything I want to use in there for now. All values below $7e that I want
; to ignore are filled with zeros and are skipped in the keyboard
; handling routine.
; The second map is used when the shift key is held on the keyboard. All
; other control keys (als, control etc etc) are also ignored for now.
;========================================================================
KEYS:           .byte 0,0,0,0,0,0,0,0,0,0,0,0,0," `",0        ; 00-0F     0d: tab
                .byte 0,0,0,0,0,"q1",0,0,0,"zsaw2",0          ; 10-1F
                .byte 0,"cxde43",0,0," vftr5",0               ; 20-2F     29: spacebar
                .byte 0,"nbhgy6",0,0,0,"mju78",0              ; 30-3F
                .byte 0,",kio09",0,0,"./l;p-",0               ; 40-4F
                .byte 0,0,"'",0,"[=",0,0,0,0,$0a,"]",0,"\\",0 ; 50-5F     0a: enter / line feed
                .byte 0,0,0,0,0,0,$08,0,0,"1",0,"47",0,0,0    ; 60-6F     08: backspace
                .byte "0.2568",$1b,0,0,"+3-*9"                ; 70-7F     1b: esc

KEYS_SHFT:      .byte 0,0,0,0,0,0,0,0,0,0,0,0,0," ~",0        ; 00-0F
                .byte 0,0,0,0,0,"Q!",0,0,0,"ZSAW@",0          ; 10-1F
                .byte 0,"CXDE#$",0,0," VFTR%",0               ; 20-2F
                .byte 0,"NBHGY^",0,0,0,"MJU&*",0              ; 30-3F
                .byte 0,"<KIO)(",0,0,">?L:P_",0               ; 40-4F
                .byte 0,0,'"',0,'{+',0,0,0,0,0,'}',0,'|?',0   ; 50-5F
                .byte 0,0,0,0,0,0,0,0,0,"1",0,"47",0,0,0      ; 60-6F
                .byte "0.2568",0,0,0,"+3-*9",0,0              ; 70-7F

                .org $FFFA
                .word NMI
                .word RESET
                .word IRQ
