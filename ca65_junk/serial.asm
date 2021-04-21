.export write_acia
.export ACIA_DATA
.export ACIA_STATUS
.export ACIA_COMMAND
.export ACIA_CONTROL

.segment "SERIAL"
ACIA_DATA: .res 1
ACIA_STATUS: .res 1
ACIA_COMMAND: .res 1
ACIA_CONTROL: .res 1

.define ACIA_STATUS_IRQ         1 << 7
.define ACIA_STATUS_DSR         1 << 6
.define ACIA_STATUS_DCD         1 << 5
.define ACIA_STATUS_TX_EMPTY    1 << 4
.define ACIA_STATUS_RX_FULL     1 << 3
.define ACIA_STATUS_OVERRUN     1 << 2
.define ACIA_STATUS_FRAME_ERR   1 << 1
.define ACIA_STATUS_PARITY_ERR  1 << 0

.segment "CODE"
.proc write_acia
    jsr delay
    sta $4000
    rts
delay:
    ldy #$ff
delay_not_done:
    dey
    bne delay_not_done
    rts
.endproc