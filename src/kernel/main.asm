ORG 0x7C00
BITS 16

main:
    MOV ax, 0
    MOV ds, ax ;keeps track of the data segment
    MOV es, ax ;extra segment
    MOV ss,ax ;stack

    MOV sp,0x7C00
    MOV si, os_boot_msg
    CALL print
    HLT

halt:
    JMP halt

print:
    PUSH si
    PUSH ax
    PUSH bx

print_loop:
    LODSB ;loads a byte to al
    OR al, al
    JZ done_print

    MOV ah, 0x0E
    MOV bh, 0
    INT 0x10

    JMP print_loop

done_print:
    POP bx
    POP ax
    POP si
    RET

os_boot_msg: DB 'OS has booted', 0x0D, 0x0A, 0

TIMES 510-($-$$) DB 0
DW 0AA55h