.text

# Bootup code
# Since we only implement input/output with polling here and do no computations, all your code can be here.

.ktext
start:
	# TODO Implement input/output with polling

waiting_loop_display:   #keep checking until display is ready 
lw $k0 0xffff0008
andi $k0 $k0 1
beqz $k0 waiting_loop_display

	# if display is ready then check if the keyboard is ready 
waiting_loop_keyboard:   #keep checking until keyboard is ready 
lw $k0 0xffff0000
andi $k0 $k0 1
beqz $k0 waiting_loop_keyboard
	# if the keyboard is ready then take the value from it and transfer it to display
lw $k0 0xffff0004
sw $k0 0xffff000c
	
# after that we branch back to the start and keep waiting till display is ready again to take a new input
	b start