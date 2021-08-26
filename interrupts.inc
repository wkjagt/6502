VIA_IFR     = $600d ; interrupt flag register
KB_IRQ      = $C0E1

    .include "macros.inc"

IRQ:
    store_registers
.io_irq:
    lda VIA_IFR
    asl a                         ; Gneral IRQ flag. This is set if any of the specific flags are set
    bcc .done                     ; False: no interrupts on the 6522
    asl a       ; timer 1
    asl a       ; timer 2
    asl a       ; cb1
    asl a       ; cb2
    asl a       ; shift reg
    asl a       ; ca1
    bcc .done
    jsr KB_IRQ
.done
    restore_registers
    rts
