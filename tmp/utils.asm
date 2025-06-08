;------------------------------------------------------------------------------
Delay_ms:
;------------------------------------------------------------------------------
; Number of milliseconds to delay in Y
; If Y = 0; then minimum time is 17 cycles 
;------------------------------------------------------------------------------
MSCNT = 198
    cpy #0      
    beq .exit
    nop
    cpy #1
    bne .delay_a
    jmp .last_1
.delay_a:
    dey
.delay_0:
    ldx #MSCNT
.delay_1:
    dex
    bne .delay_1
    nop
    nop
    dey
    bne .delay_0
.last_1:
    ldx #MSCNT - 3
.delay_2:
    dex
    bne .delay_2
.exit:
    rts