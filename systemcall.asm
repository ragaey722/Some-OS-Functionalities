	.text
# user program
task:
	li	$a0, 0xfffffb2e
	li	$v0, 1
	syscall
	li	$a0, 'D'
	li 	$v0, 11
loop:	syscall
	li	$a0, 'E'
	b	loop

# Bootup code
	.ktext
# TODO implement the bootup code

# Set the starting address of our task in the EPC
la $k0 task
mtc0 $k0 $14

# Set the IE to 1 to enable exceptions, EXL to 1 and the KSU to 10 to be in user mode
li $k0 0x13 #00010011
mtc0 $k0 $12

# The final exception return (eret) should jump to the beginning of the user program
eret

# Exception handler
# Here, you may use $k0 and $k1
# Other registers must be saved first
.ktext 0x80000180
	# Save all registers that we will use in the exception handler
	move $k1, $at
	sw $v0 exc_v0
	sw $a0 exc_a0
	
	
	mfc0 $k0 $13		# Cause register

# The following case can serve you as an example for detecting a specific exception:
# test if our PC is mis-aligned; in this case the machine hangs
	bne $k0 0x18 okpc	# Bad PC exception
	mfc0 $a0 $14		# EPC
	andi $a0 $a0 0x3	# Is EPC word aligned?
	beq $a0 0 okpc
fail:	j fail			# PC is not aligned -> processor hangs

# The PC is ok, test for further exceptions/interrupts
okpc:
	andi $a0 $k0 0x7c
	beq $a0 0 interrupt	# 0 means interrupt

# Exception code
# TODO Detect and implement system calls here.
# Remember that an adjustment of the epc may be necessary.

# We need to increment the EPC by four in all cases(syscall or any other exception that will do nothing(based on what a tutor indicated on the forum))
mfc0  $a0 $14
addiu $a0 $a0 4
mtc0  $a0 $14	

	# if exception is not a syscall then return
	andi $a0 $k0 0x7c
	bne $a0 0x20 ret #00100000

	# exception is a syscall
# Print a number
	li $a0 0x1
	beq $v0 $a0 print_num

# Print a char 
 	li $a0 0xb
	beq $v0 $a0 print_char

# Otherwise any other value will do nothing and just return
	j ret


print_num:
lw $a0 exc_a0				#load the argument 
andi $v0 $a0 0x80000000  	#check if it's negative
bne $v0 $0 is_negative		# apply the negative case

# I will use a value that is a multiple of 10 and then get the required digit to print by dividng over this value and then applying the mod and so on
get_divisor:
li $k1 1000000000
blt	$a0 $k1 reduce_divisor	# keep reducing the vlaue of k1 untill it's smaller than a0 to avoid leading zeros

print_digits:
blt $k1 10 last_digit #if my divisor is less than 10 then print the last element on the argument

waiting_loop_digit:   #keep checking until display is ready 
lw $k0 0xffff0008
andi $k0 $k0 1
beqz $k0 waiting_loop_digit
divu $k0 $a0 $k1	#get the required digit by dividing a0 over k1(the ten multiple)
addiu $k0 $k0 48	#adjust the ascii code of my digit by adding 48
sw $k0 0xffff000c	#transfer the value to the display data port 
remu $a0 $a0 $k1    # reduce my current argument to a0 % k1 
divu $k1 $k1 10		# reduce my current ten multiple
b print_digits

last_digit:

waiting_loop_Ldigit: #keep checking until display is ready
lw $k0 0xffff0008
andi $k0 $k0 1
beqz $k0 waiting_loop_Ldigit

addiu $a0 $a0 48
sw $a0 0xffff000c	#transfer the value to the display data port

j ret


is_negative:
# keep checking until display bit is ready to print the '-'
waiting_loop_minus:
lw $k0 0xffff0008
andi $k0 $k0 1
beqz $k0 waiting_loop_minus
# If display is ready transfer the '-' value to it
li $v0 '-'
sw $v0 0xffff000c
# Now get the postive complement of the argument value by subtracting from the highest bit the remaining bits 
andi $v0 $a0 0x80000000  #get highest bit
andi $k0 $a0 0x7fffffff	 #get the remaining bits 
subu	 $a0, $v0, $k0
j get_divisor


# keep reducing my divisor untill it is the first multiple of 10 that is smaller than my argument
reduce_divisor:
divu $k1 $k1 10
blt $a0 $k1 reduce_divisor
j print_digits

print_char:
# keep checking until display bit is ready to print the char
waiting_loop_char:
lw $a0 0xffff0008
andi $a0 $a0 1
beqz $a0 waiting_loop_char

# If display is ready transfer the argument value to it
lw $a0 exc_a0
sw $a0 0xffff000c	# any single char will always occupy the first byte of the word which is relevant for display

j ret


# Interrupt-specific code (nothing to do here for this exercise)
interrupt:
	j ret
ret:
# Restore used registers
	lw $v0 exc_v0
	lw $a0 exc_a0
	move $at, $k1
# Return to the EPC
	eret

# Internal kernel data
	.kdata
exc_v0:	.word 0
exc_a0:	.word 0
# TODO Additional space for registers you want to save temporarily in the exception handler
