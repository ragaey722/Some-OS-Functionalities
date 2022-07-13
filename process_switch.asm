	.text
# User program 1: Output numbers
task1:	li	$a0, 1
	li 	$t0, 2
	li 	$v0, 1
loop1:	syscall
	addiu	$t0, $t0, 1
	multu 	$a0, $t0
	mflo 	$a0
	b	loop1

# User program 2: Output G
task2:	li	$a0, 'G'
	li	$v0, 11
loop2:  syscall
	b	loop2

# Bootup code
	.ktext
# TODO Implement the bootup code

# Set the starting address of task1 in the EPC
la $k0 task1
mtc0 $k0 $14

# set that task1 is now running in the control block
li $k0 1
sw $k0 pcb_task1+4 

# Set the IE to 1 to enable exceptions, EXL to 1 , ip[7] to 1 and the KSU to 10 to be in user mode
li $k0 0x8013 #1000000000010011
mtc0 $k0 $12

# Initialize all required data structures

# Get the value of the count reg and then add a hundred to it and then store this value in the compare reg
mfc0 $k0 $9
addiu $k0 $k0 100
mtc0 $k0 $11


# The final exception return (eret) shall jump to the beginning of program 1
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
# TODO Detect and implement system calls here. Here, you can reuse parts from problem 2.1
# Remember that an adjustment of the epc may be necessary.

# We need to increment the EPC by four in all cases(syscall or any other exception that will do nothing)
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



# Interrupt-specific code

interrupt:
# TODO For timer interrupts, call timint
mfc0 $k0 $13		# Cause register
andi $a0 $k0 0x8000		# get ip[7]
beq $a0 0x8000 timint	# if ip[7] is 1 then jump to timer interrupt otherwise return

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

	.ktext
# Helper functions
timint:
# TODO Process the timer interrupt here, and call this function from the exception handler

#check which task is running now by checking the 2nd pos in the control block 
lw $k0 pcb_task1+4 
beq $k0 1 task1_running  
b task2_running

task1_running:
mfc0 $k0 $14	#get the current EPC
lw $a0 exc_a0	#get the original current value of a0 for task1
lw $v0 exc_v0	#get the original current value of v0 for task1
li $k1 0		
sw $k0 pcb_task1	#save the current EPC in the control block of task1
sw $k1 pcb_task1+4	#set the state of task1 to idle
sw $v0 pcb_task1+8	#save v0 in the control block of task1
sw $a0 pcb_task1+12	#save a0 in the control block of task1
sw $t0 pcb_task1+16	#save t0 in the control block of task1

li $k1 1			
lw $k0 pcb_task2		#get the saved EPC on task2 control block 
mtc0 $k0 $14			#adjust the current EPC to that from task2 control block
sw $k1 pcb_task2+4		#set the state of task2 to running 
lw $v0 pcb_task2+8		#load v0 of task2
lw $a0 pcb_task2+12		#load a0 of task2
sw $v0 exc_v0			#store the current v value in the exc_v0 in case we jumped out mid of exception handling
sw $a0 exc_a0			#store the current a value in the exc_a0 in case we jumped out mid of exception handling

# Get the value of the count reg and then add a hundred to it and then store this value in the compare reg
mfc0 $k0 $9
addiu $k0 $k0 100
mtc0 $k0 $11

eret

task2_running:
mfc0 $k0 $14	#get the current EPC
lw $a0 exc_a0	#get the original current value of a0 for task2
lw $v0 exc_v0	#get the original current value of v0 for task2
li $k1 0
sw $k0 pcb_task2	#save the current EPC in the control block of task2
sw $k1 pcb_task2+4	#set the state of task2 to idle
sw $v0 pcb_task2+8	#save v0 in the control block of task2
sw $a0 pcb_task2+12	#save a0 in the control block of task2

li $k1 1
lw $k0 pcb_task1		#get the saved EPC on task1 control block
mtc0 $k0 $14			#adjust the current EPC to that from task1 control block
sw $k1 pcb_task1+4		#set the state of task1 to running
lw $v0 pcb_task1+8		#load v0 of task1
lw $a0 pcb_task1+12		#load a0 of task1
lw $t0 pcb_task1+16		#load t0 of task2
sw $v0 exc_v0			#store the current v value in the exc_v0 in case we jumped out mid of exception handling
sw $a0 exc_a0			#store the current a value in the exc_a0 in case we jumped out mid of exception handling

# Get the value of the count reg and then add a hundred to it and then store this value in the compare reg
mfc0 $k0 $9
addiu $k0 $k0 100
mtc0 $k0 $11

eret

# Process control blocks
# Location 0: the program counter
# Location 1: state of the process; here 0 -> idle, 1 -> running
# Location 2-..: state of the registers
	.kdata
pcb_task1:
.word task1
.word 0
.word 0		#save v0
.word 0		#save a0
.word 0  	#save t0 	
# TODO Allocate space for the state of all registers here
pcb_task2:
.word task2
.word 0
.word 0  	#save v0
.word 0 	#save a0
# TODO Allocate space for the state of all registers here
