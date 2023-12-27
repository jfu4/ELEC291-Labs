; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.1 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P4.5 is pressed.
$NOLIST
$MODLP51RC2
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

; buttons in order:UPDOWN, INCREMENT, DECREMENT, BOOT_BUTTON, SNOOZE
BOOT_BUTTON   equ P4.5
SOUND_OUT     equ P1.1
UPDOWN        equ P0.0

INCREMENT	  equ P0.3
INCREMENT_HR 	  equ P0.6
POWER  		  equ P2.4

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

;my code
counter_min: ds 1
counter_hr:  ds 1

alarm_min:   ds 1
alarm_hr:    ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
;half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
seconds_flag:      dbit 1 ;Set to one in the ISR every time 1000 ms had passed


cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'BCD_counter: xx ', 0
Time_Message: 	  db 'Time', 0
Alarm_Message:    db 'Alarm', 0
Colon:			  db ':', 0
AM:				  db 'A', 0
PM:				  db 'P', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti	

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl P1.0 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(5), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(5), Timer2_ISR_done
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb seconds_flag ; Let the main program know a second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates ae sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable beep-silence-beep-silenc
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	
	; Increment the BCD counter
	mov a, BCD_counter
	;jnb UPDOWN, Timer2_ISR_decrement
	add a, #0x01
	da a
	cjne a, #0x60, timer_seconds
	clr a
	
	;minutes
	mov BCD_counter, a
	mov a, counter_min
	add a, #0x01
	da a
	cjne a, #0x60, timer_minutes
	clr a
	
	;hours
	mov counter_min, a
	mov a, counter_hr
	add a, #0x01
	da a
	cjne a, #0x13, timer_hours
	;cjne r5, #'P', timer_PM
	;cjne r5, #'A', timer_AM
	;cjne a, #0x12, timer_hours
	;time is now 12 hr
	;sjmp check_time
	clr a
	add a, #0x01
	
	mov counter_hr, a
	mov a, BCD_counter
	
Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti

timer_seconds:
	mov BCD_counter, a
	sjmp Inc_Done
timer_buffer_1:
	ljmp Inc_Done	
timer_minutes:
	mov counter_min, a
	sjmp Inc_Done
	
timer_hours:
	mov counter_hr, a	
	sjmp Inc_Done

timer_AM:
	Set_Cursor(1, 15)
	Display_char(#'A')
	mov r5, #'A'
	sjmp Inc_Done

timer_PM:
	Set_Cursor(1, 15)
	Display_char(#'P')
	mov r5, #'P'
	sjmp timer_buffer_1

check_time:
	;am pm
	cjne r5, #'P', timer_PM
	cjne r5, #'A', timer_AM
	sjmp timer_last
	
timer_last:
	mov a, counter_hr
	add a, #0x01
	da a
	cjne a, #0x13, timer_last_jmp
	clr a
	add a, #0x01
	
	mov counter_hr, a
	mov a, BCD_counter
	ljmp Inc_Done
	
alarm_on:
	cjne a, alarm_min, timer_minutes
	cjne a, alarm_hr, timer_hours

	ljmp Timer0_ISR
timer_last_jmp:
	mov counter_hr, a	
	sjmp timer_last
	
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init ;lcall just goes to specific memory address
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb EA   ; Enable Global interrupts (setb sets bit operand to 1)
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Time_Message)
    Set_Cursor(2,1)
    Send_Constant_String(#Alarm_Message)
    
    mov alarm_min, #0x00
    mov alarm_hr, #0x00
    
    Set_Cursor(2, 10)
    Display_BCD(alarm_min)
    
	Set_Cursor(2, 9)     
	Display_char(#':')
	
    Set_Cursor(2, 7)
    Display_BCD(alarm_hr)
        
    Set_Cursor(1, 15)
	Display_char(#'A')

	mov r5, #'A'
    setb seconds_flag
	mov counter_hr, #0x12
	; After initialization the program stays in this 'forever' loop
	
loop:
	jb INCREMENT, loop_c ; if the 'INCREMENT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb INCREMENT, loop_c ; if the 'BOOT' button is not pressed skip
	jnb INCREMENT, $
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	mov a, alarm_min
	add a, #1
	da a
	Set_Cursor(2, 10)
    Display_BCD(alarm_min)
	mov alarm_min, a
	cjne a, #0x60, loop_c
	mov alarm_min, #0x00
	
loop_c:
	jb INCREMENT_HR, loop_b ; if the 'INCREMENT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb INCREMENT_HR, loop_b  ; if the 'BOOT' button is not pressed skip
	jnb INCREMENT_HR, $	
	
	mov a, alarm_hr
	add a, #1
	da a
	Set_Cursor(2, 7)
    Display_BCD(alarm_hr)
	mov alarm_hr, a
	cjne a, #0x13, loop_b
	mov alarm_hr, #0x00

loop_a:
	jnb seconds_flag, loop
loop_b:
    clr seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
	Set_Cursor(1, 6)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(counter_hr) ; This macro is also in 'LCD_4bit.inc'
	Set_Cursor(1, 8)    
	Display_char(#':')
	Set_Cursor(1, 9)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(counter_min) ; This macro is also in 'LCD_4bit.inc'
	Set_Cursor(1, 11)     
	Display_char(#':')
	Set_Cursor(1, 12)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'
    ljmp loop
END
