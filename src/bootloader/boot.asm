ORG 0x7C00
BITS 16

JMP SHORT main
NOP

bdb_oem: DB 'MSWIN4.1'
bdb_bytes_per_sector: DW 512
bdb_sectors_per_cluster: DB 1
bdb_reserved_sectors: DW 1
bdb_fat_count: DB 2
bdb_dir_entries_count: DW 0E0h
bdb_total_sector: DW 2880
bdb_media_descriptor_type: DB 0F0h
bdb_sectors_per_fat: DW 9
bdb_sectors_per_track: DW 18
bdb_heads: DW 2
bdb_hidden_sectors: DD 0
bdb_large_sector_count: DD 0

ebr_drive_number: DB 0
                  DB 0
ebr_signature: DB 29h
ebr_volume_id: DB 12h,34h,56h,78h ;explore
ebr_volume_label: DB 'EMERALD OS '
ebr_system_id: DB 'FAT12   '


main:
    MOV ax, 0
    MOV ds, ax ;keeps track of the data segment
    MOV es, ax ;extra segment
    MOV ss,ax ;stack

    MOV sp,0x7C00

    MOV [ebr_drive_number], dl
    MOV ax, 1
    MOV cl, 1
    MOV bx, 0x7E00
    call disk_read

    MOV si, os_boot_msg
    CALL print
    

    ;4 segments
    ;reserved segment: 1 sector
    ;FAT: 9*2 = 18 sectors
    ;Root directory: 19th sector
    ;Data

    MOV ax, [bdb_sectors_per_fat]
    MOV bl, [bdb_fat_count]
    XOR bh,bh
    MUL bx
    ADD ax, [bdb_reserved_sectors] ; LBA of the root directory
    PUSH ax

    MOV ax, [bdb_dir_entries_count]
    SHL ax,5; ax *= 32
    XOR dx,dx
    DIV word [bdb_bytes_per_sector]; (32*num of entries)/bytes per sector

    TEST dx,dx
    JZ rootDifAfter
    INC ax

rootDifAfter:
    MOV cl,al
    POP ax
    MOV dl, [ebr_drive_number]
    MOV bx, buffer
    CALL disk_read

    XOR bx,bx
    MOV di, buffer

searchKernel:
    MOV si, file_kernel_bin
    MOV cx,11
    PUSH di
    REPE CMPSB
    POP di
    JE foundKernel

    ADD di,32
    INC bx
    CMP bx, [bdb_dir_entries_count]
    JL searchKernel

    KMP kernelNotFound

kernelNotFound:
    MOV si, msg_kenerl_not_found
    CALL print

    HLT
    JMP halt

foundKernel:
    MOV ax, [di+26]
    MOV [kernel_cluster], ax

    MOV ax, [bdb_reserved_sectors]
    MOV bx, buffer
    MOV cl, [bdb_sectors_per_cfat]
    MOV dl, [ebr_drive_number]

    CALL disk_read

    MOV bx, kernel_load_segment
    MOV es,bx
    MOV bx, kernel_load_offset

loadKernelLoop:
    MOV ax, [kernel_cluster]
    ADD ax, 31
    MOV cl, 1
    MOV dl, [ebr_drive_number]

    CALL disk_read

    ADD bx, [bdb_bytes_per_sector]

    MOV ax, [kernel_cluster] ;(kernel_cluster*3)/2
    MOV cx, 3
    MUL cx
    MOV cx, 2
    DIV cx

    MOV si, buffer
    ADD si, ax
    MOV ax, [ds:si]

    OR dx,dx
    JZ even

odd:
    SHR ax, 4
    JMP nextClusterAfter

even:
    AND ax, 0x0FF

nextClusterAfter:
    CMP ax, 0x0FF8
    JAE readFinish

    MOV [kernel_cluster], ax
    JMP loadKernelLoop

readFinish:
    MOV dl, [ebr_drive_number]
    MOV ax, kernel_load_segment
    MOV ds, ax
    MOV es, ax

    JMP kernel_load_segment:kernel_load_offset

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

; input: LBA index in ax
;cx [bits 0-5]: sector number
;cx [bits 6-15]: cylinder
;dh: head
lba_to_chs:
    PUSH ax
    PUSH dx

    XOR dx,dx
    DIV word [bdb_sectors_per_track] ;(LBA % sectors per track) + 1<- sector
    INC dx
    MOV cx, dx

    XOR dx, dx
    DIV word [bdb_heads]

    ;head: (LBA/sectors per track) % number of heads
    ;cylinder: (LBA / sectors per track) / number of heads

    MOV dh, dl ;head
    MOV ch,al
    SHL ah, 6
    OR CL, AH ;cylinder

    POP ax
    MOV dl, al
    POP ax

    RET

disk_read:
    PUSH ax
    PUSH bx
    PUSH cx
    PUSH dx
    PUSH di

    call lba_to_chs

    MOV ah, 02h
    MOV di, 3 ; counter

retry:
    STC ;set the carry
    INT 13h
    jnc doneRead

    call diskReset

    DEC di
    TEST di,di
    JNZ retry

failDiskRead:
    MOV si, read_failure
    CALL print
    HLT
    JMP halt

diskReset:
    PUSHA
    MOV ah,0
    STC
    INT 13h
    JC failDiskRead
    POPA

doneRead:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret



os_boot_msg: DB 'OS has booted', 0x0D, 0x0A, 0
read_failure: DB 'Failed to read disk!',0x0D, 0x0A, 0

file_kernel_bin: DB 'KERNEL  BIN';has to be 11 characters
msg_kenerl_not_found: DB 'KERNEL.bin not found'
kernel_cluster: DW 0

kernel_load_segment: EQU 0x2000
kernel_load_offset: EQU 0

TIMES 510-($-$$) DB 0
DW 0AA55h

buffer: 