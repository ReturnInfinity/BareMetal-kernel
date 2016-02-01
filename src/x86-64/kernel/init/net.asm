; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2016 Return Infinity -- see LICENSE.TXT
;
; INIT_NET
; =============================================================================


; -----------------------------------------------------------------------------
init_net:
	; Search for a supported NIC
	xor ebx, ebx			; Clear the Bus number
	xor ecx, ecx			; Clear the Device/Slot number
	mov edx, 2			; Register 2 for Class code/Subclass

init_net_probe_next:
	call os_pci_read_reg
	shr eax, 16			; Move the Class/Subclass code to AX
	cmp eax, 0x0200			; Network Controller (02) / Ethernet (00)
	je init_net_probe_find_driver	; Found a Network Controller... now search for a driver
	add ecx, 1
	cmp ecx, 256			; Maximum 256 devices/functions per bus
	jne init_net_probe_next

init_net_probe_next_bus:
	xor ecx, ecx
	add ebx, 1
	cmp ebx, 256			; Maximum 256 buses
	je init_net_probe_not_found
	jmp init_net_probe_next

init_net_probe_find_driver:
	xor edx, edx				; Register 0 for Device/Vendor ID
	call os_pci_read_reg			; Read the Device/Vendor ID from the PCI device
	mov r8d, eax				; Save the Device/Vendor ID in R8D
	mov esi, NIC_DeviceVendor_ID
	lodsd					; Load a driver ID - Low half must be 0xFFFF
init_net_probe_find_next_driver:
	mov edx, eax				; Save the driver ID
init_net_probe_find_next_device:
	lodsd					; Load a device and vendor ID from our list of supported NICs
	test eax, eax				; 0x00000000 means we have reached the end of the list
	jz init_net_probe_not_found		; No supported NIC found
	movzx ebx, ax
	cmp ebx, 0xFFFF				; New driver ID?
	je init_net_probe_find_next_driver	; We found the next driver type
	cmp eax, r8d
						; If Carry is clear then we found a supported NIC
	jne init_net_probe_find_next_device	; Else, check the next device

init_net_probe_found:
	cmp edx, 0x8169FFFF
	je init_net_probe_found_rtl8169
	cmp edx, 0x8254FFFF
	je init_net_probe_found_i8254x
	cmp edx, 0x1AF4FFFF
	je init_net_probe_found_virtio
	jmp init_net_probe_not_found

init_net_probe_found_rtl8169:
	call net_rtl8169_init
	mov rdi, os_net_transmit
	mov rax, net_rtl8169_transmit
	stosq
	mov rax, net_rtl8169_poll
	stosq
	mov rax, net_rtl8169_ack_int
	stosq
	jmp init_net_probe_found_finish

init_net_probe_found_i8254x:
	call net_i8254x_init
	mov rdi, os_net_transmit
	mov rax, net_i8254x_transmit
	stosq
	mov rax, net_i8254x_poll
	stosq
	mov rax, net_i8254x_ack_int
	stosq
	jmp init_net_probe_found_finish

init_net_probe_found_virtio:
	call net_virtio_init
	mov rdi, os_net_transmit
	mov rax, net_virtio_transmit
	stosq
	mov rax, net_virtio_poll
	stosq
	mov rax, net_virtio_ack_int
	stosq
	jmp init_net_probe_found_finish

init_net_probe_found_finish:
	movzx eax, byte [os_NetIRQ]

	lea edi, [rax+0x20]
	mov rax, network
	call create_gate

	; Enable the Network IRQ
	movzx eax, byte [os_NetIRQ]
	call os_pic_mask_clear

	mov byte [os_NetEnabled], 1	; A supported NIC was found. Signal to the OS that networking is enabled
	call b_net_ack_int		; Call the driver function to acknowledge the interrupt internally

init_net_probe_not_found:

	ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
