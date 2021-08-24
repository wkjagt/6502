    .include "macros.inc"
    
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

;======================= zero page addresses =======================
    .dsect
    .org $30

; keyboard
keyb_rptr:           reserve 1
keyb_wptr:           reserve 1
keyb_flags:          reserve 1

    .dend
;======================= /zero page addresses =======================

keyb_buffer                    = $0200 ; one page for keyboard buffer

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

keyboard_interrupt:
    store_registers
    lda keyb_flags                  ; read the current keyboard flags
    and #KEYB_RELEASE               ; see if the previous scan code was for a key release 
    beq .read_key                   ; if it isn't, go ahead and read the key
    lda keyb_flags                  
    eor #KEYB_RELEASE               ; the previous code was a release, so the new code
                                    ; is for the key that's being released.
    sta keyb_flags                  ; Turn off the release flag
    lda VIA_PORTA                   ; Read the key that's being released
    cmp #KEYB_LEFT_SHIFT_CODE       ; It's the shift key that was released: handle that case
    beq .shift_up
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_up
    jmp .done
.shift_up:
    lda keyb_flags                  ; turn off the shift flag
    eor #KEYB_SHIFT
    sta keyb_flags
    jmp .done
.read_key:
    ldx VIA_PORTA                   ; load ps/2 scan code
    txa
    cmp #KEYB_RELEASE_CODE          ; keyboard release code
    beq .key_release
    cmp #KEYB_LEFT_SHIFT_CODE
    beq .shift_down
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_down

    lda keyb_flags
    and #KEYB_SHIFT
    bne .shifted_key
    lda keymap, x
    jmp .push_key
.shifted_key:
    lda keymap_shifted, x
.push_key:
    ldx keyb_wptr
    sta keyb_buffer, x
    inc keyb_wptr
    jmp .done
.shift_down:
    lda keyb_flags
    ora #KEYB_SHIFT
    sta keyb_flags
    jmp .done
.key_release:
    lda keyb_flags
    ora #KEYB_RELEASE
    sta keyb_flags
    jmp .done
.done
    restore_registers
    rts

keymap: ; scancode to ascii code
  .byte "????????????? `?" ; 00-0F           ; 0d: tab
  .byte "?????q1???zsaw2?" ; 10-1F
  .byte "?cxde43?? vftr5?" ; 20-2F           ; 29: spacebar
  .byte "?nbhgy6???mju78?" ; 30-3F
  .byte "?,kio09??./l;p-?" ; 40-4F
  .byte "??'?[=????",$0a,"]?\??" ; 50-5F     ; 0a: enter / line feed
  .byte "??????",$08,"??1?47???" ; 60-6F     ; 06: backspace
  .byte "0.2568",$1b,"??+3-*9??" ; 70-7F     ; 1b: esc
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF
keymap_shifted:
  .byte "????????????? ~?" ; 00-0F
  .byte "?????Q!???ZSAW@?" ; 10-1F
  .byte "?CXDE#$?? VFTR%?" ; 20-2F
  .byte "?NBHGY^???MJU&*?" ; 30-3F
  .byte "?<KIO)(??>?L:P_?" ; 40-4F
  .byte '??"?{+?????}?|??' ; 50-5F
  .byte "?????????1?47???" ; 60-6F
  .byte "0.2568???+3-*9??" ; 70-7F
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF
