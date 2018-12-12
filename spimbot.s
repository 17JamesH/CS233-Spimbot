.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

RIGHT_WALL_SENSOR 		= 0xffff0054
PICK_TREASURE           = 0xffff00e0
TREASURE_MAP            = 0xffff0058
MAZE_MAP                = 0xffff0050

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8


# struct spim_treasure
#{
#    short x;
#    short y;
#    int points;
#};
#
#struct spim_treasure_map
#{
#    unsigned length;
#    struct spim_treasure treasures[50];
#};
.data

.align 4
puzzle:         .word 0:128

update:         .word 0

solution:       .word 0

map:            .word 0:408

#Insert whatever static memory you need here

.text
main:
        li      $t4, 1                          # global interrupt enable
        or      $t4, $t4, BONK_INT_MASK         # bonk interrupt enable
        or      $t4, $t4, REQUEST_PUZZLE_INT_MASK       # request interrupt enable
        or      $t4, $t4, TIMER_INT_MASK        # timer interrupt enble
        mtc0    $t4, $12                        # set interrupt mask

        sub     $sp, $sp, 4                     # Save ra
        sw      $ra, 0($sp)
        jal     check_puzzle
        jal     east
        jal     south
        jal     east
        jal     north
        #jal     north
        jal     check_puzzle
        sw      $0, PICK_TREASURE


        lw      $ra, 0($sp)
        add     $sp, $sp, 4
        jr      $ra                         #ret

north: # Drives north 1 square
        sub     $sp, $sp, 4             # Save ra to Stack
        sw      $ra, 0($sp)
        li      $a0, 270                # Set absolute angle to north
        sw      $a0, ANGLE              # ^
        li      $a0, 1                  # ^
        sw      $a0, ANGLE_CONTROL      # ^
        jal     drive                   # Drive 1 square
        lw      $ra, 0($sp)             #restore ra
        add     $sp, $sp, 4
        jr      $ra                     # return

west: # Drives west 1 square
        sub     $sp, $sp, 4             # Save ra to Stack
        sw      $ra, 0($sp)
        li      $a0, 180                # Set absolute angle to west
        sw      $a0, ANGLE              # ^
        li      $a0, 1                  # ^
        sw      $a0, ANGLE_CONTROL      # ^
        jal     drive                   # Drive 1 square
        lw      $ra, 0($sp)             #restore ra
        add     $sp, $sp, 4
        jr      $ra                     # return

east: # Drives east 1 square
        sub     $sp, $sp, 4             # Save ra to Stack
        sw      $ra, 0($sp)
        li      $a0, 0                # Set absolute angle to east
        sw      $a0, ANGLE              # ^
        li      $a0, 1                  # ^
        sw      $a0, ANGLE_CONTROL      # ^
        jal     drive                   # Drive 1 square
        lw      $ra, 0($sp)             #restore ra
        add     $sp, $sp, 4
        jr      $ra                     # return

south: # Drives south 1 square
        sub     $sp, $sp, 4             # Save ra to Stack
        sw      $ra, 0($sp)
        li      $a0, 90                # Set absolute angle to south
        sw      $a0, ANGLE              # ^
        li      $a0, 1                  # ^
        sw      $a0, ANGLE_CONTROL      # ^
        jal     drive                   # Drive 1 square
        lw      $ra, 0($sp)             #restore ra
        add     $sp, $sp, 4
        jr      $ra                     # return

drive:  #Drives forward 1 square
        li      $a0, 10                 # Set Velocity to 10
        sw      $a0, VELOCITY           # ^
        lw      $a0, TIMER              # Get Current time
        add     $a0, $a0, 10000         # Find time it takes to move 1 pixel
        sw      $a0, TIMER              # Requests interrupt after said time has passed
drive_wait:
        lw      $a0, VELOCITY           # Read current velocity
        bne     $a0, $0, drive_wait     # Wait until velocity = 0
        jr      $ra                     # Ret

check_puzzle:    # checks for and solves if possible puzzle
        sub     $sp, $sp, 4
        sw      $ra, 0($sp)

        lw      $t0, update                     # Get update flag
        beq     $t0, $0, cp_end             # Branch if no puzzle

        li      $t1, 0                          # Write 0 to velocity
        sw      $t1, VELOCITY($0)               # Write 0 to velocity

        jal     sudoku
        la      $a0, puzzle                     # Get puzzle address
        sw      $a0, SUBMIT_SOLUTION            # submit solution

        sw      $0, update                      # update = 0
        la      $a0, puzzle                     # request puzzle
        sw      $a0, puzzle                     # request puzzle
cp_end:
        lw      $ra, 0($sp)
        add     $sp, $sp, 4
        jr      $ra


## SUDOKU HELPERS ##
get_square_begin:
	div	$v0, $a0, 4
	mul	$v0, $v0, 4
	jr	$ra


.globl has_single_bit_set
has_single_bit_set:
	beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub	$a1, $a0, 1
	and	$a1, $a0, $a1
	bne	$a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
	li	$v0, 1
	jr	$ra
hsbs_ret_zero:
	li	$v0, 0
	jr	$ra


get_lowest_set_bit:
	li	$v0, 0			# i
	li	$t1, 1

glsb_loop:
	sll	$t2, $t1, $v0		# (1 << i)
	and	$t2, $t2, $a0		# (value & (1 << i))
	bne	$t2, $0, glsb_done
	add	$v0, $v0, 1
	blt	$v0, 16, glsb_loop	# repeat if (i < 16)

	li	$v0, 0			# return 0
glsb_done:
	jr	$ra

## SUDOKU RULE 1 ##
board_address:
	mul	$v0, $a1, 16		# i*16
	add	$v0, $v0, $a2		# (i*16)+j
	sll	$v0, $v0, 1		# ((i*9)+j)*2
	add	$v0, $a0, $v0
	jr	$ra

.globl rule1
rule1:
	sub	$sp, $sp, 32
	sw	$ra, 0($sp)		# save $ra and free up 7 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# board
	sw	$s3, 16($sp)		# value
	sw	$s4, 20($sp)		# k
	sw	$s5, 24($sp)		# changed
	sw	$s6, 28($sp)		# temp
	move	$s2, $a0		# store the board base address
	li	$s5, 0			# changed = false

	li	$s0, 0			# i = 0
r1_loop1:
	li	$s1, 0			# j = 0
r1_loop2:
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s1		# j
	jal	board_address
	lhu	$s3, 0($v0)		# value = board[i][j]
	move	$a0, $s3
	jal	has_single_bit_set
	beq	$v0, 0, r1_loop2_bot	# if not a singleton, we can go onto the next iteration

	li	$s4, 0			# k = 0
r1_loop3:
	beq	$s4, $s1, r1_skip_row	# skip if (k == j)
	move	$a0, $s2		# board
	move 	$a1, $s0		# i
	move	$a2, $s4		# k
	jal	board_address
	lhu	$t0, 0($v0)		# board[i][k]
	and	$t1, $t0, $s3
	beq	$t1, 0, r1_skip_row
	not	$t1, $s3
	and	$t1, $t0, $t1
	sh	$t1, 0($v0)		# board[i][k] = board[i][k] & ~value
	li	$s5, 1			# changed = true

r1_skip_row:
	beq	$s4, $s0, r1_skip_col	# skip if (k == i)
	move	$a0, $s2		# board
	move 	$a1, $s4		# k
	move	$a2, $s1		# j
	jal	board_address
	lhu	$t0, 0($v0)		# board[k][j]
	and	$t1, $t0, $s3
	beq	$t1, 0, r1_skip_col
	not	$t1, $s3
	and	$t1, $t0, $t1
	sh	$t1, 0($v0)		# board[k][j] = board[k][j] & ~value
	li	$s5, 1			# changed = true

r1_skip_col:
	add	$s4, $s4, 1		# k ++
	blt	$s4, 16, r1_loop3

	## doubly nested loop
	move	$a0, $s0		# i
	jal	get_square_begin
	move	$s6, $v0		# ii
	move	$a0, $s1		# j
	jal	get_square_begin	# jj

	move 	$t0, $s6		# k = ii
	add	$t1, $t0, 4		# ii + GRIDSIZE
	add 	$s6, $v0, 4		# jj + GRIDSIZE

r1_loop4_outer:
	sub	$t2, $s6, 4		# l = jj  (= jj + GRIDSIZE - GRIDSIZE)

r1_loop4_inner:
	bne	$t0, $s0, r1_loop4_1
	beq	$t2, $s1, r1_loop4_bot

r1_loop4_1:
	mul	$v0, $t0, 16		# k*16
	add	$v0, $v0, $t2		# (k*16)+l
	sll	$v0, $v0, 1		# ((k*16)+l)*2
	add	$v0, $s2, $v0		# &board[k][l]
	lhu	$v1, 0($v0)		# board[k][l]
   	and	$t3, $v1, $s3		# board[k][l] & value
	beq	$t3, 0, r1_loop4_bot

	not	$t3, $s3
	and	$v1, $v1, $t3
	sh	$v1, 0($v0)		# board[k][l] = board[k][l] & ~value
	li	$s5, 1			# changed = true

r1_loop4_bot:
	add	$t2, $t2, 1		# l++
	blt	$t2, $s6, r1_loop4_inner

	add	$t0, $t0, 1		# k++
	blt	$t0, $t1, r1_loop4_outer


r1_loop2_bot:
	add	$s1, $s1, 1		# j ++
	blt	$s1, 16, r1_loop2

	add	$s0, $s0, 1		# i ++
	blt	$s0, 16, r1_loop1

	move	$v0, $s5		# return changed
	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	add	$sp, $sp, 32
	jr	$ra

## SUDOKU ##
sudoku:
        la      $a0, puzzle
        jal     rule1                   # Rule1
        beq     $v0, $0, s_end          # If done solving
        j       sudoku
s_end:
        jr      $ra


# Kernel Text
.kdata
chunkIH:    .space 28
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)

        mfc0      $k0, $13             # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
        mfc0       $k0, $13        # Get Cause register, again
        beq        $k0, 0, done        # handled all outstanding interrupts

        and        $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
        bne        $a0, 0, bonk_interrupt

        and        $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
        bne        $a0, 0, timer_interrupt

        and 	   $a0, $k0, REQUEST_PUZZLE_INT_MASK
        bne 	   $a0, 0, request_puzzle_interrupt

        li        $v0, PRINT_STRING    # Unhandled interrupt types
        la        $a0, unhandled_str
        syscall
        j    done

bonk_interrupt:
        sw      $v0, BONK_ACK        # acknowledge interrupt
        j       interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
        sw      $a0, REQUEST_PUZZLE_ACK         # Acknowledge puzzle interrupt
        la      $a0, update                    # Flip update flag
        li      $t0, 1                          # Flip update flag
        sw      $t0, 0($a0)
	j	interrupt_dispatch	 # see if other interrupts are waiting

timer_interrupt:
sw      $0, VELOCITY                    # Stop moving
sw      $a0, TIMER_ACK                  # Acknowledge timer interrupt
j        interrupt_dispatch             # see if other interrupts are waiting

non_intrpt:                # was some non-interrupt
        li        $v0, PRINT_STRING
        la        $a0, non_intrpt_str
        syscall                # print out an error message
        # fall through to done

done:
        la      $k0, chunkIH
        lw      $a0, 0($k0)        # Restore saved registers
        lw      $v0, 4($k0)
	lw      $t0, 8($k0)
        lw      $t1, 12($k0)
        lw      $t2, 16($k0)
        lw      $t3, 20($k0)
.set noat
        move    $at, $k1        # Restore $at
.set at
        eret
