command_table:
	db "GET", 0
	dw get_command
	db "SET", 0
	dw set_command
	db "PING", 0
	dw ping_command
	db "CONFIG", 0
	dw config_command
	db 0	; end byte
command_table_end:
