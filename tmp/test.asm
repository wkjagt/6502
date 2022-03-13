JUMP_TABLE_ADDR         = $300
RCV                     = JUMP_TABLE_ADDR + 0
INIT_SCREEN             = JUMP_TABLE_ADDR + 3
RUN                     = JUMP_TABLE_ADDR + 6
RESET                   = JUMP_TABLE_ADDR + 9
PUTC                    = JUMP_TABLE_ADDR + 12
PRINT_HEX               = JUMP_TABLE_ADDR + 15
XMODEM_RCV              = JUMP_TABLE_ADDR + 18
GETC                    = JUMP_TABLE_ADDR + 21
INIT_KB                 = JUMP_TABLE_ADDR + 24
LINE_INPUT              = JUMP_TABLE_ADDR + 27
IRQ_HANDLER             = JUMP_TABLE_ADDR + 30
NMI_HANDLER             = JUMP_TABLE_ADDR + 33
INIT_SERIAL             = JUMP_TABLE_ADDR + 36
CURSOR_ON               = JUMP_TABLE_ADDR + 39
CURSOR_OFF              = JUMP_TABLE_ADDR + 42
DRAW_PIXEL              = JUMP_TABLE_ADDR + 45
RMV_PIXEL               = JUMP_TABLE_ADDR + 48
INIT_STORAGE            = JUMP_TABLE_ADDR + 51
STOR_READ               = JUMP_TABLE_ADDR + 54
STOR_WRITE              = JUMP_TABLE_ADDR + 57
READ_PAGE               = JUMP_TABLE_ADDR + 60
WRITE_PAGE              = JUMP_TABLE_ADDR + 63
GET_INPUT               = JUMP_TABLE_ADDR + 66
CLR_INPUT               = JUMP_TABLE_ADDR + 69

LOAD_FAT                = JUMP_TABLE_ADDR + 72
CLEAR_FAT               = JUMP_TABLE_ADDR + 75
FIND_EMPTY_PAGE         = JUMP_TABLE_ADDR + 78
CLEAR_DIR               = JUMP_TABLE_ADDR + 81
LOAD_DIR                = JUMP_TABLE_ADDR + 84
SAVE_DIR                = JUMP_TABLE_ADDR + 87
SHOW_DIR                = JUMP_TABLE_ADDR + 90
FORMAT_DIVE             = JUMP_TABLE_ADDR + 93
PRINT_STRING            = JUMP_TABLE_ADDR + 96
ADD_TO_DIR              = JUMP_TABLE_ADDR + 99
FIND_EMPTY_DIR          = JUMP_TABLE_ADDR + 102
DELETE_DIR              = JUMP_TABLE_ADDR + 105
DELETE_FILE             = JUMP_TABLE_ADDR + 108
SAVE_FAT                = JUMP_TABLE_ADDR + 111
FIND_FILE               = JUMP_TABLE_ADDR + 114

drive_page              = $12
ram_page                = $14
next_empty_page         = $1b           ; reserve
load_size               = $00           ; for realsies
load_page               = $01           ; for realsies
error_code              = $43
dir_page                = $1a           ; the current dir page read from drive
                                        ; values: 1-4

LAST_PAGE               = $FF
FAT_BUFFER              = $0400
DIR_BUFFER              = $0500
MAX_FILE_NAME_LEN       = 8

LF                      = $0A
CR                      = $0D

ERR_DIR_FULL            = 1
ERR_DRIVE_FULL          = 2
ERR_FILE_NOT_FOUND      = 3
ERR_FILE_EXISTS         = 4

__INPUTBFR_START__      = $B0

                .org $600


                jsr     PRINT_STRING
                .byte   "Hello world!", 0
                rts