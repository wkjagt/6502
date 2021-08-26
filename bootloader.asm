; 6522 VIA
VIA_PORTB                      = $6000
VIA_PORTA                      = $6001
VIA_DDRB                       = $6002
VIA_DDRA                       = $6003
VIA_PCR                        = $600c ; peripheral control register
VIA_IFR                        = $600d ; interrupt flag register
VIA_IER                        = $600e ; interrupt enable register

KEYB_RELEASE                   = %00000001
KEYB_SHIFT                     = %00000010
KEYB_RELEASE_CODE              = $F0
KEYB_LEFT_SHIFT_CODE           = $12
KEYB_RIGHT_SHIFT_CODE          = $59
MAX_SCANCODE                   = $7e

; 6551 ACIA
ACIA_START   = $4000
ACIA_DATA    = ACIA_START + 0
ACIA_STATUS  = ACIA_START + 1
ACIA_COMMAND = ACIA_START + 2
ACIA_CONTROL = ACIA_START + 3

ACIA_STATUS_RX_FULL    = 1 << 3

PROGRAM_WRITE_PTR_L    = $0002
PROGRAM_WRITE_PTR_H    = $0003
keyb_rptr              = $30
keyb_wptr              = $31
keyb_flags             = $32
keyb_buffer                    = $0200 ; one page for keyboard buffer




PROGRAM_START          = $0300

  .org $c000

  .include "vdp.asm"

  .macro vdp_write_vram
  lda #<(\1)
  sta VDP_REG
  lda #(VDP_WRITE_VRAM_BIT | >\1) ; see second register write pattern
  sta VDP_REG
  .endm

reset: 
setup:              
                    sei                          ; disable interrupts
setup_via:          lda #%11111111
                    sta VIA_DDRA
                    sta VIA_DDRB
                    lda #$00
                    sta VIA_PORTA
                    sta VIA_PORTB

setup_acia:         lda #%11001011               ; No parity, no echo, no interrupt
                    sta ACIA_COMMAND
                    lda #%00011111               ; 1 stop bit, 8 data bits, 19200 baud
                    sta ACIA_CONTROL
setup_program_ptrs: lda #0                       ; reset counters that count prgram length
                    sta PROGRAM_WRITE_PTR_L
                    lda #$03
                    sta PROGRAM_WRITE_PTR_H
setup_vdp:          jsr vdp_setup

                    lda #$ff                     ; ready light on
                    sta VIA_PORTB
                    jsr KBSETUP

loop:               jsr read_serial_byte
                    cmp #"l"
                    bne loop
                    lda #$00                     ; ready light off
                    sta VIA_PORTB                    
                    jsr load_program
                    lda #$ff                     ; ready light on
                    sta VIA_PORTB

                    jsr $0308                    ; jump over header
                    jmp loop

load_program:       
.header_byte:       jsr read_serial_byte         ; read byte
                    cmp #$04                     ; EOT
                    beq .done
                    ldy #$80                     ; packet size: 128 
.program_byte:      jsr read_serial_byte
                    sta (PROGRAM_WRITE_PTR_L)
                    jsr inc_prgrm_pointer
                    dey
                    beq .header_byte             ; when y == 0, end of packet
                    jmp .program_byte
.done:              rts

inc_prgrm_pointer:  inc PROGRAM_WRITE_PTR_L
                    bne .done
                    inc PROGRAM_WRITE_PTR_H
.done:              rts

read_serial_byte:   lda ACIA_STATUS
                    and #ACIA_STATUS_RX_FULL
                    beq read_serial_byte
                    lda ACIA_DATA
                    rts

nmi:                rti
irq:                jsr PROGRAM_START           ; interrupt handler needs to be at the start of the program
                    rti
KBSETUP:
    lda #0                         ; set port A as input (for keyboard)
    sta VIA_DDRA
    lda #%10010010                 ; enable interrupt on CA1 and CB1
    sta VIA_IER
    lda #%00000001                 ; set CA1 as positive active edge
    sta VIA_PCR

    lda #0
    sta keyb_rptr
    sta keyb_wptr
    sta keyb_flags
    rts

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

                    .org $FFFA
                    .word nmi
                    .word reset
                    .word irq
