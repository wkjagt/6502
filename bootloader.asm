;==============================================================================
; Addresses for registers on the 6522 VIA
;==============================================================================
VIA_PORTB                      = $6000
VIA_PORTA                      = $6001
VIA_DDRB                       = $6002
VIA_DDRA                       = $6003
VIA_PCR                        = $600c ; peripheral control register
VIA_IFR                        = $600d ; interrupt flag register
VIA_IER                        = $600e ; interrupt enable register

;==============================================================================
; Addresses for registers on the 6551 ACIA
;==============================================================================
ACIA_START   = $4000
ACIA_DATA    = ACIA_START + 0
ACIA_STATUS  = ACIA_START + 1
ACIA_COMMAND = ACIA_START + 2
ACIA_CONTROL = ACIA_START + 3

;==============================================================================
; Constants related to the 6551 ACIA
;==============================================================================
ACIA_STATUS_RX_FULL    = 1 << 3

;==============================================================================
; Constants related to the functioning of the PS/2 keyboard
;==============================================================================
KEYB_RELEASE                   = %00000001
KEYB_SHIFT                     = %00000010
KEYB_RELEASE_CODE              = $F0
KEYB_LEFT_SHIFT_CODE           = $12
KEYB_RIGHT_SHIFT_CODE          = $59
MAX_SCANCODE                   = $7e

;==============================================================================
; RAM addresses for keyboard usage
;==============================================================================
keyb_rptr              = $30
keyb_wptr              = $31
keyb_flags             = $32
keyb_buffer            = $0200 ; one page for keyboard buffer

;==============================================================================
; RAM addresses for the 16 bit pointer for writing a program to RAM
;==============================================================================
PROGRAM_WRITE_PTR_L    = $0002
PROGRAM_WRITE_PTR_H    = $0003

;==============================================================================
; The start of the program in RAM. Used to start writing to, and
; to jump to once the program is loaded
;==============================================================================
PROGRAM_START          = $0300

  .org $c000

  .include "vdp.asm"

reset:              sei
;==============================================================================
; Initialize the 6551 ACIA for serial communication
;==============================================================================
                    lda #%11001011               ; No parity, no echo, no interrupt
                    sta ACIA_COMMAND
                    lda #%00011111               ; 1 stop bit, 8 data bits, 19200 baud
                    sta ACIA_CONTROL
;==============================================================================
; Initialize the program pointers for writing bytes to RAM
;==============================================================================
                    lda #0                       ; reset counters that count prgram length
                    sta PROGRAM_WRITE_PTR_L
                    lda #$03
                    sta PROGRAM_WRITE_PTR_H
;==============================================================================
; Initialize the TMS9918A VDP video chip
;==============================================================================
                    jsr vdp_setup
;==============================================================================
; Initialize the PS/2 keyboard interface
;==============================================================================
                    jsr KBSETUP

;==============================================================================
; The main program loop for loading a program into RAM over serial
; Once the ASCII code for the "l" character (for "load") is received,
; kick off the load_program routine.
; When control is returned from that routine, JMP to the program start
; address.
;==============================================================================
loop:               jsr read_serial_byte
                    cmp #"l"
                    bne loop
                    jsr load_program
                    jsr $0308
                    jmp loop
;==============================================================================
; The program load routine is a very much simplified implementation of
; xmodem. It leaves out all error checking, but is otherwise pretty much
; identical.
;==============================================================================
load_program:       
.header_byte:       jsr read_serial_byte         ; Read a character over serial
                    cmp #$04                     ; $04 is the End Of Transmission Character
                                                 ; and can be received after each packet
                    beq .done                    ; We're done once that's received.
                                                 ; The other byte is assumed to be a Start
                                                 ; of header byte, but we're not checking for it.
                    ldy #$80                     ; packet size: 128 bytes
.program_byte:      jsr read_serial_byte         ; This reads one byte into RAM, by using
                    sta (PROGRAM_WRITE_PTR_L)    ; the pointer we're keeping in the zero page.
                    jsr inc_prgrm_pointer
                    dey
                    beq .header_byte             ; when y == 0, end of packet
                    jmp .program_byte            ; after loading each packet, check the header byte
.done:              rts

inc_prgrm_pointer:  inc PROGRAM_WRITE_PTR_L
                    bne .done
                    inc PROGRAM_WRITE_PTR_H
.done:              rts

;==============================================================================
; Read one byte from the serial connection provided by the 6551 ACIA
;==============================================================================
read_serial_byte:   lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq read_serial_byte
                    lda ACIA_DATA
                    rts

;==============================================================================
; Interrupt handlers
;==============================================================================
nmi:                rti
irq:                pha
                    phy
                    phx

                    lda VIA_IFR
                    bit #%10000000      ; Gneral IRQ flag. This is set if any of the specific flags are set
                    beq .done           ; False: no interrupts on the 6522
                    bit #%00000010      ; CA2 flag
                    beq .done
                    jsr KB_IRQ
.done
                    plx
                    ply
                    pla
                    rti

;==============================================================================
; Initialize the PS/2 keyboard interface that uses the 6522 VIA for
; interrupt handling and data reading. 
; The PS/2 hardware triggers the CA1 with a positive edge when data is
; available on port A.
;==============================================================================
KBSETUP:
    lda #0                         ; set port A as input (for keyboard)
    sta VIA_DDRA
    lda #%10000010                 ; enable interrupt on CA1
    sta VIA_IER
    lda #%00000001                 ; set CA1 as positive active edge
    sta VIA_PCR
    lda #0
    sta keyb_rptr
    sta keyb_wptr
    sta keyb_flags
    rts

;==============================================================================
; Read one key from the keyboard buffer into the A register. A is loaded with
; 0 when no new key is pressed. When a key is pressed, the read pointer is
; incremented.
;==============================================================================
RDKEY:
    lda keyb_rptr
    cmp keyb_wptr
    beq .no_key
    ldx keyb_rptr
    inc keyb_rptr
    lda keyb_buffer, x
    rts
.no_key:
    lda #0
    rts

;==============================================================================
; The keyboard key press handler that is triggered by an IRQ
;==============================================================================
KB_IRQ:
    pha
    phy
    phx
;==============================================================================
; Check the keyboard flags for the key release flag. If it is set, this means
; that the previous scan code was for a key release, and the current interrupt
; signals the scan code for the actual key that was released. If the flag
; isn't set, go ahead and read the key as usual. If the flag is set, reset it
; and handle the scan code as a key release.
;==============================================================================
    lda keyb_flags                  ; read the current keyboard flags
    and #KEYB_RELEASE               ; see if the previous scan code was for a key release 
    beq .read_key                   ; if it isn't, go ahead and read the key
    lda keyb_flags                  
    eor #KEYB_RELEASE               ; the previous code was a release, so the new code
                                    ; is for the key that's being released.
    sta keyb_flags                  ; Turn off the release flag
;==============================================================================
; Read the scan code for the key that was released. If it is for one of the
; shift keys, it means that shift is no longer being pressed, and we need to
; handle that. If a different key was released, we ignore it, as we don't
; (yet) handle any other key combinations.
;==============================================================================
    lda VIA_PORTA                   ; Read the key that's being released
    cmp #KEYB_LEFT_SHIFT_CODE       ; It's the shift key that was released: handle that case
    beq .shift_up
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_up
    jmp .done
;==============================================================================
; When shift is released, we need to reset the shift flag
;==============================================================================
.shift_up:
    lda keyb_flags                  ; turn off the shift flag
    eor #KEYB_SHIFT
    sta keyb_flags
    jmp .done
;==============================================================================
; Interpet a scan code other than the code of a released key is received. This
; block interprets that scan code.
;==============================================================================
.read_key:
    ldx VIA_PORTA                   ; load ps/2 scan code
    txa
;==============================================================================
; Handle special cases that aren't characters (release codes and shift keys)
;==============================================================================
    cmp #KEYB_RELEASE_CODE          ; keyboard release code
    beq .key_release
    cmp #KEYB_LEFT_SHIFT_CODE
    beq .shift_down
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_down
;==============================================================================
; Ignore scan codes above MAX_SCANCODE because there's nothing there we
; want to use for now.
;==============================================================================
    cmp #MAX_SCANCODE               ; highest interpreted value
    bcs .done                       ; carry set: >=
;==============================================================================
; The scan code is for a character. First load the keyboard flags to check
; the SHIFT flag. If the flag is set, we look up the ASCII code for the
; character in the shifted map. Otherwise, use the unshifted map.
;==============================================================================
    lda keyb_flags
    and #KEYB_SHIFT
    bne .shifted_key
    lda keymap, x
    jmp .push_key
.shifted_key:
    lda keymap_shifted, x
;==============================================================================
; Write the received character to the keyboard buffer, and advance the write
; pointer. This causes the write pointer to be ahead of the read pointer
; which will be detected by the routine that checks for new characters that
; haven't been used yet.
;==============================================================================
.push_key:
    beq .done           ; don't put anything in the buffer if a 0 is found in the keymap
    ldx keyb_wptr
    sta keyb_buffer, x
    inc keyb_wptr
    jmp .done
; ==============================================================================
; Handle the case of the shift key being pressed by setting the shift flag
; in the keyboard flags.
; ==============================================================================
.shift_down:
    lda keyb_flags
    ora #KEYB_SHIFT
    sta keyb_flags
    jmp .done
; ==============================================================================
; Handle the case of the release scan code being received because this means
; that the next scan code identies which key was released.
; ==============================================================================
.key_release:
    lda keyb_flags
    ora #KEYB_RELEASE
    sta keyb_flags
    jmp .done
.done
    plx
    ply
    pla
    rts

;========================================================================
; These two maps map PS/2 scan codes to their respective ASCII codes.
; Any bytes higher than $7e are ignored for now because there isn't
; anything I want to use in there for now. All values below $7e that I want
; to ignore are filled with zeros and are skipped in the keyboard
; handling routine.
; The second map is used when the shift key is held on the keyboard. All
; other control keys (als, control etc etc) are also ignored for now.
;========================================================================
keymap: ; scancode to ascii code
  .byte 0,0,0,0,0,0,0,0,0,0,0,0,0," `",0        ; 00-0F     0d: tab
  .byte 0,0,0,0,0,"q1",0,0,0,"zsaw2",0          ; 10-1F
  .byte 0,"cxde43",0,0," vftr5",0               ; 20-2F     29: spacebar
  .byte 0,"nbhgy6",0,0,0,"mju78",0              ; 30-3F
  .byte 0,",kio09",0,0,"./l;p-",0               ; 40-4F
  .byte 0,0,"'",0,"[=",0,0,0,0,$0a,"]",0,"\\",0 ; 50-5F     0a: enter / line feed
  .byte 0,0,0,0,0,0,$08,0,0,"1",0,"47",0,0,0    ; 60-6F     08: backspace
  .byte "0.2568",$1b,0,0,"+3-*9"                ; 70-7F     1b: esc
keymap_shifted:
  .byte 0,0,0,0,0,0,0,0,0,0,0,0,0," ~",0        ; 00-0F
  .byte 0,0,0,0,0,"Q!",0,0,0,"ZSAW@",0          ; 10-1F
  .byte 0,"CXDE#$",0,0," VFTR%",0               ; 20-2F
  .byte 0,"NBHGY^",0,0,0,"MJU&*",0              ; 30-3F
  .byte 0,"<KIO)(",0,0,">?L:P_",0               ; 40-4F
  .byte 0,0,'"',0,'{+',0,0,0,0,0,'}',0,'|?',0   ; 50-5F
  .byte 0,0,0,0,0,0,0,0,0,"1",0,"47",0,0,0      ; 60-6F
  .byte "0.2568",0,0,0,"+3-*9",0,0              ; 70-7F

                    .org $FFFA
                    .word nmi
                    .word reset
                    .word irq
