    .include "macros.inc"
    
VIA_PORTA                      = $6001

KEYB_RELEASE                   = %00000001
KEYB_SHIFT                     = %00000010
KEYB_RELEASE_CODE              = $F0
KEYB_LEFT_SHIFT_CODE           = $12
KEYB_RIGHT_SHIFT_CODE          = $59
MAX_SCANCODE                   = $7e

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
    beq .done                       ; ignore 0 values
    cmp #KEYB_RELEASE_CODE          ; keyboard release code
    beq .key_release
    cmp #KEYB_LEFT_SHIFT_CODE
    beq .shift_down
    cmp #KEYB_RIGHT_SHIFT_CODE
    beq .shift_down
    cmp #MAX_SCANCODE               ; highest interpreted value
    bcs .done                       ; carry set: >=

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