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
	jmp main


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


main:

	; setup data segments
	mov ax, 0 			; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 	    ; stack grows downwards from where we are loaded in memory

	; read something from floppy disk
	; BIOS should set DL to drive
	mov [ebr_drive_number], dl

	mov ax, 1 			; LBA=1, second sector from disk 
	mov cl, 1 			; 1 sector to read
	mov bx, 0x7E00		; data should be after the bootloader
	call read_disk
	
	; print HectOS message
	mov si, msg_hello
	call puts

	cli 				; disable interrupts
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
		
msg_hello: 			db 'HectOS', ENDL, 0
msg_read_failed: 	db 'Read from disk failed!', ENDL, 0


times 510-($-$$) db 0
db 0x55, 0xAA
