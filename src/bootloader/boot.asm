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

	; print Hello World
	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt

msg_hello: db 'Hello, World!', ENDL, 0

times 510-($-$$) db 0
db 0x55, 0xAA
