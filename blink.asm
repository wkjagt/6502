LED_STATUS = $00

VIA_START = $6000
PORTA = VIA_START + 1
PORTB = VIA_START + 0
DDRA  = VIA_START + 3
DDRB  = VIA_START + 2

VDP_VRAM = $8000
VDP_REG  = $8001

VDP_REG_0 = $80 + 0
VDP_REG_1 = $80 + 1
VDP_REG_2 = $80 + 2
VDP_REG_3 = $80 + 3
VDP_REG_4 = $80 + 4
VDP_REG_5 = $80 + 5
VDP_REG_6 = $80 + 6
VDP_REG_7 = $80 + 7


  .org $0300

.include "vdp.asm"

; vdp_write_register: .macro register, data
;   lda #\data
;   sta VDP_REG

;   lda #\register        ; register select
;   sta VDP_REG     ; register 7
; .endm

  vdp_write_register VDP_REG_7, $0B




;     lda #0
;     sta LED_STATUS

; loop:
;     ldx #$ff
;     ldy #$ff
; delay:
;     dex
;     bne delay
;     dey
;     bne delay     

;     lda LED_STATUS
;     beq led_on ; if the led is on, turn if off 
; led_off:
;     lda #0
;     sta LED_STATUS
;     sta PORTA
;     jmp loop
; led_on:
;     lda #$ff
;     sta LED_STATUS
;     sta PORTA
;     jmp loop
