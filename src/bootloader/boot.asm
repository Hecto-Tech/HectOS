org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


;
; FAT12 Header
;
jmp short start
nop

bdb_oem: 					db 'MSWIN4.1' ; 8 Bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0x0E0
bdb_total_sectors:			dw 2880
bdb_media_descriptor_type:	db 0x0F0
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0


ebr_drive_number:			db 0
							db 0
ebr_signature:				db 0x29
ebr_volume_id:				db 0x12, 0x34, 0x56, 0x78
ebr_volume_laberl:			db 'HectOS     '
ebr_system_id:				db 'FAT12   '

;
; Code
;


start:
	; setup data segments
	mov ax, 0 			; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 	    ; stack grows downwards from where we are loaded in memory

	; some BIOSes might start the OS at 07C00:0000 instead of 0000:7C00, making sure
	; we're in the expected location
	push es
	push word .after
	retf

.after:

	; read something from floppy disk
	; BIOS should set DL to drive
	mov [ebr_drive_number], dl
	
	; print loading message
	mov si, msg_loading
	call puts

	; read drive params (sectors per track and head count),
	; instead of relying on data on formatted disk
	push es
	mov ah, 0x08
	int 0x13
	jc floppy_error
	pop ebr_signature

	and cl, 0x3F						; remove top 2 bits
	xor ch, ch
	mov [bdb_sectors_per_track], cx 	; sector count

	int 0xD
	mov [bdb_heads], 0xD				; head count

	; compute LBA of root dir = reserved + fats * sectors_per_fat
	; note: this section can be hardcoded (i dunno what this means)
	mov ax, [bdb_sectors_per_fat] 		; compute LBA or root dir = reserved + fats * sectors_per_fat
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx								; dx:ax = (fats * sectors_per_fat)
	add ax, [bdb_reserved_sectors]		; ax = LBA of root dir
	push ax

	; comptue size of root dir = (32 * number_of_entries) / bytes_per_sector
	mov ax, [bdb_dir_entries_count]
	shl ax, 5							; ax *= 32
	xor dx, dx							; dx, 0
	div word [bdb_bytes_per_sector]		; num of sectors we need to read

	test dx, dx							; if dx != 0, add 1
	jz root_dir_after
	inc ax								; division remainder != 0, add 1
										; this means we have a sector only partially filled with entries

.root_dir_after:

	; read root dir (fr)
	mov cl, al							; num of sectors to read = size of root dir
	pop ax								; LBA of root dir

	cli 								; disable interrupts
	hlt

;
; Error handlers
;
floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 0x16
	jmp 0FFFFh:0

.halt:
	cli					; disable interrupts, this way CPU can't get out of "halt" state
	hlt


;
;	prints a string to the screen
;	params:
;	- ds:si points to string
;
puts:
	; save registers we will modify
	push si
	push ax

.loop: ; used in puts
	lodsb 				; loads next character in al
	or al, al			; verify if next character is null?
	jz .done

	mov ah, 0x0E 		; call bios interrupt
	mov bh, 0
	int 0x10

	jmp .loop
	
.done: ; used in puts
	pop ax
	pop si
	ret


;
; Disk routines
;

;
; Converts an LAB address to a CHS address
; Parameters:	
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder
;	-dh: head

lba_to_chs:

	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack
	inc dx								; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl							; dl = head
	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in CL register

	pop ax
	mov dl, al							; restore DL
	pop ax
	ret

;
; Reads sectors from a disk
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- es:bx: memory location where to store read data 
read_disk:

	push ax								; save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx								; temporarily save CL (number of sectors to read)
	call lba_to_chs						; compute CHS
	pop ax								; AL = number pf sectors to read

	mov ah, 0x02
	mov di, 3							; retry count

.retry:
	pusha 								; save all registers, we don't know what BIOS will do to them
	stc									; set carry flag, some BIOS'es don't set it
	int 0x13							; carry flag cleared ) success
	jnc .done							; jump if carry not set
	

	; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; after all attemps failed
	jmp floppy_error
		
.done:
	popa
	
	pop di
	pop dx
	pop cx
	pop bx
	pop ax								; restore registers we modified
	ret

;
; Reset disk controller
; Parameters:
;	- dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 0x13
	jc floppy_error
	popa
	ret
		
msg_loading: 			db 'Loading...', ENDL, 0
msg_read_failed: 		db 'Read from disk failed!', ENDL, 0


times 510-($-$$) db 0
db 0x55, 0xAA
