interrupt:
    store_registers
.io_irq:
    lda VIA_IFR
    asl a                         ; IRQ
    bcc .done                     ; no interrupt on the 6522
.timer1
    asl a
.timer2:
    asl a
.cb1:
    asl a
    bcc .cb2
    jsr cursor_interrupt
.cb2:
    asl a
.shift_reg:
    asl a
.ca1:
    asl a
    bcc .ca2
    jsr keyboard_interrupt
.ca2:
    asl a
.done
    restore_registers
    rts