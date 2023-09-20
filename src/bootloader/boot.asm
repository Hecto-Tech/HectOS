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

; EP 2 10:10

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