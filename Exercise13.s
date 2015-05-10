            TTL Program Title for Listing Header Goes Here
;****************************************************************
;This exercise implements GetChar and PutChar using an interrupt service routine
;Name:  Lauren Giannotti
;Date:  04/06/2015
;Class:  CMPE-250
;Section:  Lab 2, Monday, 6:00 PM
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;February 16, 2015
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates
IN_PTR      EQU 0	
OUT_PTR     EQU 4
BUF_STRT    EQU 8    
BUF_PAST    EQU 12
BUF_SIZE    EQU 16
NUM_ENQD    EQU 17
Q_BUF_SZ    EQU 80
Q_REC_SZ    EQU 18
min_lowercase EQU 97			;lowercase letters start at ascii value 97
max_lowercase EQU 122			;lowercase letters have highest ascii value of 122
MAX_STRING EQU 79				;max length of the string	
CR EQU 0x0D						;carriage return
LF EQU 0x0A						;live feed
;UART_C2_T_RI EQU UART_C2_RIE_MASK :OR: UART_C2_TE_MASK :OR: UART_C2_RE_MASK
UART1_IRQ_PRI EQU 3
	
UART_C2_T_RI  EQU  (UART_C2_RIE_MASK :OR: UART_C2_RE_MASK :OR: UART_C2_TE_MASK)							;enable everything except the TIE
UART_C2_TI_RI EQU  (UART_C2_RIE_MASK :OR: UART_C2_TIE_MASK :OR: UART_C2_RE_MASK :OR: UART_C2_TE_MASK )	;enable everyting including the interrupt mask

PIT_MCR_EN_FRZ	EQU	PIT_MCR_FRZ_MASK
PIT_LDVAL_10ms	EQU	239999
PIT_TCTRL_CH_IE EQU (PIT_TCTRL_TIE_MASK :OR: PIT_TCTRL_TEN_MASK)
PIT_IRQ_PRI		EQU 0	

 
;Port D
PTD5_MUX_GPIO EQU (1 << PORT_PCR_MUX_SHIFT)
SET_PTD5_GPIO EQU (PORT_PCR_ISF_MASK :OR: PTD5_MUX_GPIO)
;Port E
PTE29_MUX_GPIO EQU (1 << PORT_PCR_MUX_SHIFT)
SET_PTE29_GPIO EQU (PORT_PCR_ISF_MASK :OR: PTE29_MUX_GPIO)

POS_RED EQU 29
POS_GREEN EQU 5
LED_RED_MASK EQU (1 << POS_RED)
LED_GREEN_MASK EQU (1 << POS_GREEN)
LED_PORTD_MASK EQU LED_GREEN_MASK
LED_PORTE_MASK EQU LED_RED_MASK

;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
PORT_PCR_PIN_MUX_SELECT_3  EQU	0x00000300
;---------------------------------------------------------------
;Port E
PORT_PCR_PTE0_MUX_UART1_TX  EQU  PORT_PCR_MUX_SELECT_3_MASK
PORT_PCR_PTE1_MUX_UART1_RX  EQU  PORT_PCR_MUX_SELECT_3_MASK
PORT_PCR_SET_PTE0_UART1_TX  EQU  \
             (PORT_PCR_ISF_MASK :OR: PORT_PCR_PTE0_MUX_UART1_TX)
PORT_PCR_SET_PTE1_UART1_RX  EQU  \
             (PORT_PCR_ISF_MASK :OR: PORT_PCR_PTE1_MUX_UART1_RX)
;---------------------------------------------------------------
;SIM_SCGC4
;1->11:UART1 clock gate control (enabled)
SIM_SCGC4_UART1CGC_MASK  EQU  SIM_SCGC4_UART1_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->   13:Port E clock gate control (enabled)
SIM_SCGC5_PORTECGC_MASK  EQU  SIM_SCGC5_PORTE_MASK
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   17:UART1 open drain enable (disabled)
; 0->   06:UART1 receive data select (UART1_RX)
;00->05-04:UART1 transmit data select source (UART1_TX)
SIM_SOPT5_UART1_EXTERN_MASK_CLEAR  EQU  (SIM_SOPT5_UART1ODE_MASK \
    :OR: SIM_SOPT5_UART1RXSRC_MASK :OR: SIM_SOPT5_UART1TXSRC_MASK)
;---------------------------------------------------------------
;UARTx_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00000->4-0:SBR[12:0] (BUSCLK / (16 x 9600))
;BUSCLK = CORECLK / 2 = PLLCLK / 4
;PLLCLK is 96 MHz
;BUSCLK is 24 MHz
;SBR = 24 MHz / (16 x 9600) = 156.25 --> 156 = 0x009C
UART_BDH_9600  EQU  0
;---------------------------------------------------------------
;UARTx_BDL
;26->7-0:SBR[7:0] (BUSCLK / 16 x 9600))
;BUSCLK = CORECLK / 2 = PLLCLK / 4
;PLLCLK is 96 MHz
;BUSCLK is 24 MHz
;SBR = 24 MHz / (16 x 9600) = 156.25 --> 0x9C
UART_BDL_9600  EQU  156
;---------------------------------------------------------------
;UARTx_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:UARTSWAI=UART stop in wait mode (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UARTx_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=trasmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART_C2_T_R  EQU  (UART_C2_TE_MASK :OR: UART_C2_RE_MASK)
;---------------------------------------------------------------
;UARTx_C3
;0-->7:R8=9th data bit for receiver (not used M=0)
;0-->6:T8=9th data bit for transmitter (not used M=0)
;0-->5:TXDIR=TxD pin direction in single-wire mode (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not invereted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UARTx_C4
;0-->  7:TDMAS=transmitter DMA select (disabled)
;0-->  6:Reserved; read-only; always 0
;0-->  5:RDMAS=receiver full DMA select (disabled)
;0-->  4:Reserved; read-only; always 0
;0-->  3:Reserved; read-only; always 0
;0-->2-0:Reserved; read-only; always 0
UART_C4_NO_DMA  EQU  0x00
;---------------------------------------------------------------
;UARTx_S2
;0-->7:LBKDIF=LIN break detect interrupt flag
;0-->6:RXEDGIF=RxD pin active edge interrupt flag
;0-->5:(reserved);read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag
UART_S2_NO_RXINV_BRK10_NO_LBKDETECT  EQU  0x00
;---------------------------------------------------------------



;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL46 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<

		BL Initialize_Queue_Record
		BL Init_UART1			;initailize uart
		BL NVIC
		BL Init_PIT
		BL InitPortDandE
		BL LED_Init
		BL PDDR
		CPSIE I					;enable interrupts
        MOVS R4,#0              ;initialize game round
start

        
		BL Green_off
		BL Red_off
		
		LDR R0,=RunStopWatch	;timer depends on user delay
		MOVS R1,#1
		STRB R1,[R0,#0]
		
        BL newline
		LDR R0,=prompt			;enter a key to start the game
		BL PutString
		BL newline
		MOVS R0,#'>'
		BL PutChar
		BL GetChar

		
round      
		LDR R0,=Count
		MOVS R2,R0				;save count address
		LDR R0,[R0,#0]			;get value
		
		MOVS R1,#3				;mask of 11 (last two bits)
		ANDS R1,R1,R0			;mod by 4
		
		MOVS R0,#0
		STR R0,[R2,#0]			;initialize count to 0
		
		CMP R1,#0
		BEQ neither_setup
		
		CMP R1,#1
		BEQ both_setup
		
		CMP R1,#2
		BEQ red_setup

		CMP R1,#3
		BEQ green_setup
;---------------------------------------------------------------------------

neither_setup
		BL Red_off
		BL Green_off
		LDR R2,=neither			;setup input parameters for subroutine
		MOVS R3,#'n'
		B call_subroutine
		
both_setup
		BL Green_on
		BL Red_on
		LDR R2,=both			;setup input parameters for subroutine
		MOVS R3,#'b'
		B call_subroutine
		
red_setup
		BL Red_on
		BL Green_off
		LDR R2,=red				;setup input parameters for subroutine
		MOVS R3,#'r'
		B call_subroutine
		
green_setup	
		BL Green_on
		BL Red_off
		LDR R2,=green			;setup input parameters for subroutine
		MOVS R3,#'g'
		B call_subroutine
		
call_subroutine
        ADDS R4,R4,#1           ;increase the game round by 1 every time it loops back
		;;handle round logic
		BL Game_Round
		
		;;check time expired flag, run expiration logic or branch to next round pending results
		
		
		;go to new round if expired flag not set
		B round                 

		;run expiration logic if expired flag settime_expired
		MOVS R0,#'X'
		BL PutChar
		LDR R0,=out_of_time
		BL PutString
		MOVS R0,R2				;load string for neither, both, red, or green
		BL PutString
		BL newline
	
        LDR R0,=your_score_is   ;prints: "Game over. Your score is"
        BL PutString
         MOVS R0,R4              ;put the score into the string
        BL PutNumUB              ;print the decimal form on the terminal screen
        LDR R0,=points
        BL PutString
		B start


;>>>>>   end main program code <<<<<
;Stay here
            B       .
            LTORG
            ALIGN
;---------------------------------------------------------------
;>>>>> begin subroutine code <<<<<
;****************************************************************************************************
newline
		PUSH{R0,LR}
		MOVS R0,#CR				;carriage return
		BL PutChar
		MOVS R0,#LF				;line feed
		BL PutChar				;completes a new line
		POP{R0,PC}

;********************************************************************************************************************
;Input Parameters
;custom string address: R2
;checking character	  : R3
;game round           : R4
Game_Round
		PUSH {R1-R4,LR}
        CMP R4,#5             ;try with 4 rounds for now ;check if you already went through 10 rounds
        BEQ done_game
        
        LDR R0,=round_number
        BL PutString
        MOVS R0,R4              ;put the game round number into R0
        BL PutNumUB             ;print the decimal form on the terminal screen
        BL newline
retry

		BL check_pressed		;uses R1
		CMP R1,#1				;if the user pressed a key
		BNE not_pressed
		BL GetChar
		CMP R0,R3				;check if the user pressed correct character
		BEQ correct_answer
		BNE incorrect
correct_answer
        BL PutChar              ;print the user's character on the screen
		LDR R0,=correct
		BL PutString
		MOVS R0,R2				;load string for neither, both, red, or green
		BL PutString
		BL newline
		B increase_score
		
incorrect
        BL PutChar              ;print the user's character on the screen
		LDR R0,=wrong
		BL PutString
		BL newline
		
not_pressed
		LDR R0,=Count
		LDR R0,[R0,#0]			
		LDR R5,=1000            ;10 seconds/.01 count constant = 1000
		CMP R0,R5				;check if 10 seconds has passed
		
		;if the time has expired, set expire flag, return from subroutine
		
		;if the time has not expired, brandh to retry
		
		B retry


increase_score

		;increase the score here and return from subroutine
		



        POP{R1-R4,PC}


;*****************************************************************************************
Initialize_Queue_Record
;initializes the queue record structure for a queue buffer of 4 characters (4bytes)
        LDR R0,=RxQBuffer               ;load into R0 the address of QBuffer (character to enqueue)
        LDR R1,=RxQRecord               ;load into R1 the address of the queue record structure
        STR R0,[R1,#IN_PTR]             ;points to the beginning of the queue buffer
        STR R0,[R1,#OUT_PTR]            ;points to the beginning of the queue buffer
        STR R0,[R1,#BUF_STRT]           ;address of beginning of queue buffer
        MOVS R2,#80           		    ;move the capacity of the queue buffer into R2
        ADDS R0,R0,R2                   ;increment the character (R0) by the queue buffer size
        STR R0,[R1,#BUF_PAST]           ;first address past the end of the QBuffer
        STRB R2,[R1,#BUF_SIZE]          ;store a byte of the contents in R2 into the address in R1 with an offset of the buffer size
        MOVS R0,#0                      ;move a zero into R0
        STRB R0,[R1,#NUM_ENQD]          ;store a byte of the contents in R0 into the address of R1 with an offset of Num_enqd.
		
        LDR R0,=TxQBuffer               ;load into R0 the address of QBuffer (character to enqueue)
        LDR R1,=TxQRecord               ;load into R1 the address of the queue record structure
        STR R0,[R1,#IN_PTR]             ;points to the beginning of the queue buffer
        STR R0,[R1,#OUT_PTR]            ;points to the beginning of the queue buffer
        STR R0,[R1,#BUF_STRT]           ;address of beginning of queue buffer
        MOVS R2,#80           		    ;move the capacity of the queue buffer into R2
        ADDS R0,R0,R2                   ;increment the character (R0) by the queue buffer size
        STR R0,[R1,#BUF_PAST]           ;first address past the end of the QBuffer
        STRB R2,[R1,#BUF_SIZE]          ;store a byte of the contents in R2 into the address in R1 with an offset of the buffer size
        MOVS R0,#0                      ;move a zero into R0
        STRB R0,[R1,#NUM_ENQD]          ;store a byte of the contents in R0 into the address of R1 with an offset of Num_enqd.
		
		LDR R0,=QBuffer                 ;load into R0 the address of QBuffer (character to enqueue)
        LDR R1,=QRecord                 ;load into R1 the address of the queue record structure
        STR R0,[R1,#IN_PTR]             ;points to the beginning of the queue buffer
        STR R0,[R1,#OUT_PTR]            ;points to the beginning of the queue buffer
        STR R0,[R1,#BUF_STRT]           ;address of beginning of queue buffer
        MOVS R2,#4		                ;move the capacity of the queue buffer into R2
        ADDS R0,R0,R2                   ;increment the character (R0) by the queue buffer size
        STR R0,[R1,#BUF_PAST]           ;first address past the end of the QBuffer
        STRB R2,[R1,#BUF_SIZE]          ;store a byte of the contents in R2 into the address in R1 with an offset of the buffer size
        MOVS R0,#0                      ;move a zero into R0
        STRB R0,[R1,#NUM_ENQD]          ;store a byte of the contents in R0 into the address of R1 with an offset of Num_enqd.
		
		
		BX LR
;*****************************************************************************************************************************
UART1_ISR
;interrupt service routine that handles UART1 transmit and receive interrupts
;gets the value from the status register and determines whether or not to tramit based on TDRE and RDRF bits
;
		CPSID I
		PUSH {LR}
		LDR R3,=UART1_BASE				;setting up the address for where the uart is so that we can do displacement
		MOVS R1,#UART_C2_TIE_MASK		;isolates the TIE bit
		LDRB R2,[R3,#UART_C2_OFFSET]	;getting control register 2 value from the uart
		TST R2,R1						;and with the mask and current control 2 register value
		BEQ check_receive				;becvause you know transmit doesn't have anything
		;interrupt is enabled if you passed this
		MOVS R1,#UART_S1_TDRE_MASK		;mask
		LDRB R2,[R3,#UART_S1_OFFSET]	;
		TST R1,R2						;Checking to see if tdre bit is set
		BEQ check_receive
		;if it got past, then it is set. there is something to be transmitted
		LDR R1,=TxQRecord				;dequeue needs an address to transmit
		BL Dequeue
		BCS ISR_dequeue_failure
		STRB R0,[R3,#UART_D_OFFSET]		;gives the dequeued char to the uart so that it can transmit it
		B check_receive
		
ISR_dequeue_failure
		MOVS R2,#UART_C2_T_RI			;the control register value that the register needs to be reset to when the error happens
		STRB R2,[R3,#UART_C2_OFFSET]	;store at the base with control 2 equate value offset.
	
check_receive	
		LDRB R2,[R3,#UART_S1_OFFSET]	;R2 is given the value of the status register (byte value)
		MOVS R1,#UART_S1_RDRF_MASK	 	;mask
		LDRB R2,[R3,#UART_S1_OFFSET]	;
		TST R1,R2						;Checking to see if tdre bit is set
		BEQ finish_ISR					;if the branch happens then RDRF =0 which means you don't have to handle it because there's nothing to receive.
		LDRB R0,[R3,#UART_D_OFFSET]		;loading the ascii value from the uart because you know that there is an ascii there now
		LDR R1,=RxQRecord	
		BL Enqueue						;puts the ascii value in the queue
		
finish_ISR
		CPSIE I
		POP {PC}
		
;****************************************************************************************************

CopyString
;Creates a null terminated string in memory starting at the address in R1 by copying the characters from a null-terminated
;source string from memory starting at the address in R0
;R0 gets copied into R1

		PUSH{R0-R3}
		MOVS R2,#0						;initialize counter
CopyStringLoop
		LDRB R3,[R0,R2]					;getting the current ascii value from memory using offset of counter
		STRB R3,[R1,R2]					;storing the current ascii value into the desired register
       	ADDS R2,R2,#1					;increment counter
		CMP R3,#0						;check for null-terminating character
		BEQ endofstring_CS				;branch if reached null terminating char
		B CopyStringLoop
endofstring_CS
		POP{R0-R3}	
		BX LR
		
;********************************************************************************************************************
ReverseString
;Reverses the characters of a null-terminated string in memory starting at the address in R0
;R0: string starts at address in R0
;R2: incrementing counter: used for iteration and R0 memory address offset
;R3: the ascii value of the current character in the string
;R4: incrementing counter used for offset when storing characters back into R0

		PUSH {R2-R4}
		MOVS R2,#0						;initialize first offset counter
		MOVS R4,#0						;initialize second offset counter
Loop_ReverseString
		LDRB R3,[R0,R2]					;get the current ascii value from the string starting at address in R0 by using offset of char counter
		CMP R3,#0						;check for null-termination
		BEQ null_loop					;branch if you reach the zero
		PUSH{R3}						;push the current character on the stack
		ADDS R2,R2,#1					;increment character counter to use for offset when loading when you loop again
		B Loop_ReverseString
null_loop
		POP{R3}							;pop character off of the top of the stack
		STRB R3,[R0,R4]					;put current character back into R0 w/ offset of new counter
		ADDS R4,R4,#1					;increment counter
		CMP R4,R2						;compare the counters
		BEQ done_reverse				;if you reach the same value as the same counter then that means you reached the end of the string again.
		B null_loop
done_reverse
		POP{R2-R4}
		BX LR
;********************************************************************************************************************
SearchStringChar
;Searches the null-terminated string in memory starting at the address in R1 for the character in R0
;If that character is present in the string, on return the value of register R2 will be the position of that character in the string
;e.g: 1 if its the first char, 2 if its the second char
;otherwise, R2 will be 0 on return
;R1:	address of the string
;R0:	character you are searching for
;R2:	output

		PUSH{R0,R1,R3}					;exclude R2 because r2 is the output
		MOVS R2,#0						;initialize position counter
Loop_SearchString
		LDRB R3,[R1,R2]					;getting current ascii value
		ADDS R2,R2,#1					;incrementing counter
		CMP R0,R3						;comparing current ascii to the one you're seaching for
		BEQ found						;if they are equal, then you found the char
		CMP R3,#0						;check for null termination
		BEQ didnt_find					;if you reach null termination, then that means you didn't find the char you're looking for
		B Loop_SearchString				;loop
found
		POP{R0,R1,R3}					;pop registers
		BX LR							;go back to main program code
didnt_find		
		MOVS R2,#0						;move 0 into R2 if it didn't find the char
		B found


		
;********************************************************************************************************************
Dequeue
;Attempts to get a character from the queue whose record structure's address is in R1.
;if the queue is not empty, it dequeues a single character from the queue to R0, and returns with the CCR C bit cleared
;C bit cleared reports dequeue success, C bit set reports dequeue failure.
;Input: R1: address of queue record structure
;Output: character dequeued into R0, PSR C flag
;Modify: R0 and PSR. All other registers remain unchanged on return.

        PUSH{R1-R4}                     ;save on stack any register used, other than PSR
		LDRB R2,[R1,#NUM_ENQD]			;puts the number of enqueued elements into R2
        CMP R2,#0                       ;Check if queue is empty
        BEQ queue_empty_DQ
        ;if the queue is not empty:
		LDR R2,[R1,#OUT_PTR]			;load the outpointer address into a register
        LDRB R0,[R2,#0]                 ;get queue item (character/byte)at OutPointer (R2)
        ADDS R2,R2,#1                   ;Increment outpointer past queue item (increment by 1 byte value)
        STR R2,[R1,#OUT_PTR]            ;updates the value of the outpointer
        LDRB R3,[R1,#NUM_ENQD]          ;load the num_enqd equate value into a register
        SUBS R3,R3,#1                   ;decrement numberEnqueued.
		STRB R3,[R1,#NUM_ENQD]			;storing updated number of elements into the queue record structure
        LDR R3,[R1,#BUF_PAST]          ;load buf_past value into register
        CMP R2,R3                       ;check to see if outpointer is outside of the queue buffer
        BHS outside_buffer_DQ
        ;if out_ptr NOT outside queue buffer:
        MOVS R3,#0						
		LSRS R3,R3,#1					;clear carry flag
		POP{R1-R4}                      ;restore any registers pushed onto the stack
        BX LR                           ;go back to main code
outside_buffer_DQ
		LDR R3,[R1,#BUF_STRT]			;adjust outpointer to start of queue buffer
		STR R3,[R1,#OUT_PTR]
		MOVS R3,#0						
		LSRS R3,R3,#1					;clear carry flag
		POP{R1-R4}                      ;restore any registers pushed onto the stack
        BX LR                           ;go back to main code
queue_empty_DQ
        MOVS R3,#1						
		LSRS R3,R3,#1					;set carry flag
        POP{R1-R4}                      ;restore any registers pushed onto the stack
        BX LR                           ;go back to main code
;********************************************************************************************************************
Enqueue
;Attempts to put a character in the queue whose queue record structure' saddress is in R1.
;if the queue is not full, enqueues the single character from R0 to the queue, and returns with the CCR C bit cleared
;C bit cleared reports enqueue success, C bit set reports enqueue failure.
;Input: R0: character to enqueue
;       R1: Address of queue record structure
;Output: PSR C flag (success = 0, failure = 1)
;All other registers remain unchanged on return.
        PUSH{R1-R4}                     ;save on stack any register used, other than PSR
		LDRB R2,[R1,#NUM_ENQD]			;puts the number of enqueued elements into R2
		LDRB R3,[R1,#BUF_SIZE]			;buffer size
        CMP R2,R3                       ;Check if queue is full
        BHS queue_full_EQ
        ;if the queue is not full:
        LDR R3,[R1,#IN_PTR]             ;getting the address for the character
		STRB R0,[R3,#0]        	 		;put new element at memory location where in pointer points (enqueue char)
        ADDS R2,R2,#1                   ;increment numberEnqueued.
		ADDS R3,R3,#1                   ;Increment in pointer past queue item (increment by 1 byte value) 
        STRB R2,[R1,#NUM_ENQD]          ;
		
        LDR R2,[R1,#BUF_PAST]           ;move buf_past value into register
        CMP R3,R2                       ;check to see if inpointer is outside of the queue buffer
        BHS outside_buffer_EQ
        ;if you didn't go past, you still need to update the inpointer
       	STR R3,[R1,#IN_PTR]				;storing the updated in pointer in the queue record
		B EnqueueDone
		
outside_buffer_EQ
        ;if you go past, reset to the start of buffer
		LDR R3,[R1,#BUF_STRT]
		STR R3,[R1,#IN_PTR]				;storing the updated in pointer in the queue record
		MOVS R2,#0						;moving 0 into R2			
		LSRS R2,R2,#1					;clear carry flag
		B EnqueueDone

queue_full_EQ
        MOVS R3,#1						
		LSRS R3,R3,#1					;set carry flag

EnqueueDone
		POP{R1-R4}                      ;restore any registers pushed onto the stack
        BX LR                           ;go back to main code
;********************************************************************************************************************
;reads a string from the terminal keyboard to memory starting at the address in R0 and adds null termination
;accepts characters typed on the terminal keyboard until the carriage return char is received
;echoes character and stores character at next position in string for each char up to MAX_STRING-1 chars
;for any character typed after the first MAX_STRING-1 chars, it does not store the char in the string and doesn't echo the char
;when carriage return char has been received, it null terminates the string, advances the cursor to the next line, and returns.
GetString
		PUSH{R0-R3,LR}					;R0, R1, R2, and link register
		MOVS R1,R0						;duplicating R0 memory address
		MOVS R2,#0						;initialize counter
		MOVS R3,#MAX_STRING
		SUBS R3,R3,#1
while_get_string
		BL GetChar						;allows user to enter in a character. stores it into R0
		BL PutChar						;print character to screen so you can see what you're typing
		CMP R0,#13						;check for the enter character
		BEQ end_loop					;end the loop if enter character was pressed
		CMP R2,R3						;compare to 78 because reserve null character at end of string
		BGE max_string_length
		STRB R0,[R1,R2]					;storing char into string, which is in address stored in R1
		ADDS R2,R2,#1					;increment counter by 1
		B while_get_string				;loop again
end_loop
		BL PutChar						;printing out the carriage return character (enter) bc thats the character that ends the loops
		MOVS R0,#LF						;move line feed into R0
		BL PutChar						;completes new line output
		MOVS R0,#0						;move a null character into R0
		STRB R0,[R1,R2]					;store the null character at the end of the string
		POP{R0-R3,PC}					;program counter
max_string_length
		BL GetChar						;allows user to enter characters but doesn't store/echo to screen
		CMP R0,#13						;compare to enter
		BEQ end_loop					;ends loop if enter was pressed
		B max_string_length				;stuck in loop until they press enter
;*******************************************************************************************************************************
;displays null-terminated string from memory starting at R0
;returns without advancing to the next line
PutString
		PUSH{R0-R3,LR}
		MOVS R3,R0						;duplicate register
		LDRB R0,[R3,#0]					;load byte for 1 ascii value from R3 (R3=memory address of 1st letter of the string)
		MOVS R1,#0						;initialize index
while_length_string
		CMP R0,#0						;compare char to null ascii value, which is zero
		BEQ end_of_string
		ADDS R1,R1,#1					;increment counter by 1
		BL PutChar						;outputs the string
		LDRB R0,[R3,R1]					;load the value in R0 with the offset of R1 (looking at the next character in the string)
		B while_length_string
end_of_string
		POP{R0-R3,PC}
;*********************************************************************************************************************************
PDDR
		PUSH{R0,R1}
		LDR R0,=FGPIOD_BASE
		LDR R1,=LED_PORTD_MASK
		STR R1,[R0,#GPIO_PDDR_OFFSET]
		
		LDR R0,=FGPIOE_BASE
		LDR R1,=LED_PORTE_MASK
		STR R1,[R0,#GPIO_PDDR_OFFSET]
		POP{R0,R1}
		BX LR
;*********************************************************************************************************************************
InitPortDandE
		PUSH{R0-R2}
		LDR R0,=SIM_SCGC5
		LDR R1,=(SIM_SCGC5_PORTD_MASK :OR: SIM_SCGC5_PORTE_MASK)
		LDR R2,[R0,#0]
		ORRS R2,R2,R1
		STR R2,[R0,#0]
		POP{R0-R2}
		BX LR
;*********************************************************************************************************************************
LED_Init
		;red LED
		PUSH{R0,R1}
		LDR R0,=PORTE_BASE
		LDR R1,=SET_PTE29_GPIO
		STR R1,[R0,#PORTE_PCR29_OFFSET]
		
		;green LED
		LDR R0,=PORTD_BASE
		LDR R1,=SET_PTD5_GPIO
		STR R1,[R0,#PORTD_PCR5_OFFSET]
		POP{R0,R1}
		BX LR
;*********************************************************************************************************************************
Red_on
		PUSH{R0-R1}
		LDR R0,=FGPIOE_BASE
		LDR R1,=LED_RED_MASK
		STR R1,[R0,#GPIO_PCOR_OFFSET]
		POP{R0-R1}
		BX LR
;*********************************************************************************************************************************
Red_off
		PUSH{R0-R1}
		LDR R0,=FGPIOE_BASE
		LDR R1,=LED_RED_MASK
		STR R1,[R0,#GPIO_PSOR_OFFSET]
		POP{R0-R1}
		BX LR
;*********************************************************************************************************************************
Green_off
		PUSH{R0-R1}
		LDR R0,=FGPIOD_BASE
		LDR R1,=LED_GREEN_MASK
		STR R1,[R0,#GPIO_PSOR_OFFSET]
		POP{R0-R1}
		BX LR
;*********************************************************************************************************************************
Green_on
		PUSH{R0-R1}
		LDR R0,=FGPIOD_BASE
		LDR R1,=LED_GREEN_MASK
		STR R1,[R0,#GPIO_PCOR_OFFSET]
		POP{R0-R1}
		BX LR
;*********************************************************************************************************************************

check_pressed
        PUSH {LR}						;pushing registers to use in subroutine
		
		LDR R1,=RxQRecord				;load into R1 because thats what dequeue takes

		CPSID I							;mask other interrupts
		LDRB R1,[R1,#NUM_ENQD]
		CMP R1,#0						; if R1 > 0
		BNE gotchar
		MOVS R1,#0						;if nothing enqueued, then return 0
		B done_check
gotchar
		MOVS R1,#1						;return 1
done_check
		CPSIE I							;unmask other interrupts
        POP {PC}              		    ;popping registers so we can use them in main code
;*********************************************************************************************************************************		
;ascii value of character is loaded into R0
;waiting for the user to enter a character and loads value into R0 when typed
;when RDRF=1 then that means user typed char, which means user sent character to uart
;otherwise, keep looping and waiting

GetChar
        PUSH {R1-R3, LR}				;pushing registers to use in subroutine
		LDR R1,=RxQRecord				;load into R1 because thats what dequeue takes
get_loop
		CPSID I							;mask other interrupts
		BL Dequeue						;dequeue character from RxQueue
		CPSIE I							;unmask other interrupts
		BCS get_loop					;branch if c set because if c clear then end the loop
        POP {R1-R3, PC}                  ;popping registers so we can use them in main code
		
;**************************************************************************************************
;takes value in R0 (ascii value) and gives it to the uart to display it on the screen
PutChar
        PUSH {R1-R3,LR}					;push registers to use in subroutines
		LDR R1,=TxQRecord				;load into R1 because thats what enqueue takes
put_loop
		CPSID I							;mask other interrupts
		BL Enqueue
		CPSIE I							;unmask interrupts
		BCS put_loop					;branch back if c flag set (enqueue unsuccessful)
		LDR R2,=UART1_BASE
		MOVS R3,#UART_C2_TI_RI			;allowing the ISR to be run
		STRB R3,[R2,#UART_C2_OFFSET]	;storing the set bit into the C2 register
        POP{R1-R3,PC}                   ;popping registers so we can use them in main code
;****************************************************************************************************		
;displays the length of string in decimal form
;make sure R0 has unsigned value because DIVU only works with unsigned values
;R1 is the dividend
;R0 is the divisor
PutNumU
		PUSH{R0-R2,LR}					;preserve link register b/c called within a diff subroutine
		MOVS R2,#0						;counter keeps track of how many decimal values are pushed onto the stack
loop_PNU
		MOVS R1,R0						;make a copy of R0
		MOVS R0,#10						;dividing by a factor of 10
		BL DIVU							;divides by a factor of 10
		ADDS R1,#0x30					;converting R0 to the correct numerical ascii value
		PUSH{R1}						;push R1 onto the stack, R1 contains decimal digit
		ADDS R2,R2,#1					;increment counter
		CMP R0,#0						;check to see if remainder=0
		BNE loop_PNU					;loop back if remainder is not equal to zero
Print_putnumU
		CMP R2,#0						;compare stack counter to zero
		BEQ putnumU_finished			;branch if stack counter is zero
		POP{R0}							;pop decimal number of digits from top of stack into R0
		BL PutChar						;diplay the character on the screen
		SUBS R2,R2,#1					;decrement counter
		B Print_putnumU					;continuously put more characters on screen
putnumU_finished
		POP{R0-R2,PC}
		
;****************************************************************************************************
PutNumHex
;Input		 R0: unsigned word value to print in hex
;Modify		 PSR (after return, nothing else)	 
;prints unsigned word value in R0 to the terminal screen in hexadecimal format.
	PUSH{R1-R4,LR}
	MOVS R1,R0							;copy register
	MOVS R0,#'0'						;move 0 for hex prefix
	BL PutChar							;print the 0
	MOVS R0,#'x'						;move x for hex prefix
	BL PutChar							;print x
	
	;MOVS R2,#8							;move 8 because there are 8 hex chars
										;R2 = down counter
	MOVS R3,#28							;28 = the shift amount 32-28=4 most significant hex digit
	MOVS R4,#0x0F						;mask for the last four bits
	
Loop_PNH
	CMP R3,#0							;compare to zero
	BLT Done_PNH						;branch because shift amount is negative
	
	MOVS R0,R1							;move copy back into R0
	LSRS R0,R0,R3						;shift by shifting amount
	SUBS R3,R3,#4						;decrement shift amount for next loop
	ANDS R0,R0,R4						;and R0 with the mask
	CMP R0,#10							;check if value is greater than ten because then it would need letters A-F
	BGE greaterthan10_PNH				;
	;less than 10
	ADDS R0,R0,#'0'						;convert to ascii by adding ascii value for 0.
	BL PutChar
	B Loop_PNH
greaterthan10_PNH
	SUBS R0,R0,#10						;subtract result from shift by 10
	ADDS R0,R0,#'A'						;add to ascii value of 10, which is A
	BL PutChar
	B Loop_PNH
Done_PNH
	POP{R1-R4,PC}

;**********************************************************************************
PutNumUB
;print the unsigned byte value in R0 to the terminal screen in decimal
;
;
	PUSH{R1-R4,LR}
	MOVS R1,#0xFF						;mask with 1s to preserve last byte
	ANDS R0,R0,R1						;and the word value with the mask
	BL PutNumU							;call PutNumU to print the number in decimal
	POP{R1-R4,PC}
;*************************************************************************************
;continually subtracts the divisor from the dividend while counting the number of subtractions
;number of subtractions is the quotient
;at end of subroutine, R1 value is the remainder.
;R1/R0 = R0 remainder R1
;checks if the divisor is zero
;checks if the dividend is zero
DIVU
		PUSH {R2-R3}					; saves R2 into stack so main program doesn't overwrite data
		MOVS R2,#0						; initializing the counter to zero
		CMP R0, #0						; check if R0=0 (dividing by zero)
		BEQ DivideByZero				; branch if R0=0
		CMP R1, #0						; check if R1=0 (0/anything = 0)
		BEQ DividendZero				; branch if R1=0
		;compare r1 with 0

	
Loop
		CMP R1,R0						; check if there is a remainder
		BLO	End_Loop					; branch to end loop if R0 is greater than R1
		SUBS R1,R1,R0					; subtracting 
		ADDS R2,R2,#1					; adding 1 to counter after every subtraction
		B Loop							; continue subtracting	
	
End_Loop								; R0 > R1
		MOVS R0,R2						; counter is quotient, so move it into specified register
	
Clear_CFlag								; clearing c flag after operation is finished
		MRS R2, APSR					; taking entire status register and putting it into R2
		MOVS R3,#0x20					; c bit is in 0010
		LSLS R3,R3,#24					; move bits all the way to the left to the front of the 32 bit register
		BICS R2,R3		   				; clears the 28th bit which is the c bit
		MSR APSR,R2						; putting the entire word back into the status register
	
Done

		POP {R2-R3}						; restore to original value for main program to continue
		BX LR							; branching back to the address that BL is stored in

DividendZero
		MOVS R0,#0						; counter is zero: 0/anything = 0
		MOVS R1,#0						; remainder is zero: 0/anything has remainder of 0
		B Clear_CFlag					; branch so that the division finishes
	
DivideByZero							; R0=0	

		MOVS R0,#1						; move a 1 into R0
		LSRS R0,R0,#1					; shift R0 to the right by one bit (R0 becomes 0 again)
										; carry flag is set to 1 from the R0 shift	
		
		B Done
;****************************************************************************
NVIC
;3rd block
;The pit interrupt priority is set to 0, the highest priority
;add equates to the top

		PUSH {R0-R1}
		LDR R0,=NVIC_ISER				;load the address into R0
		LDR R1,=UART1_IRQ_MASK			;load the isr mask into a different register
        LDR R2,=PIT_IRQ_MASK			;load in the pit mask
		ORRS R1,R1,R2					;or them together
		STR R1,[R0,#0]					;store that mask into address in R0
		;set uart1 irq priority (assumin gonly irq's from uart1)
		LDR R0,=UART1_IPR				;load the IPR address
		LDR R1,=(UART1_IRQ_PRI << UART1_PRI_POS)	;shift
		STR R1,[R0,#0]					;store into ipr
        ;set pit priority
        LDR R1,=PIT_IPR
        LDR R2,=(PIT_IRQ_PRI << PIT_PRI_POS)
        STR R2,[R1,#0]

		CPSIE I							;unmask interrupts
		POP {R0-R1}
		BX LR
;****************************************************************************
;initializes the uart for the specifications for our board
;pushes and pops registers so we can use them in main code
;sets/clears UART1 bit, moves baud rate of 9600
Init_UART1  
        PUSH{R0-R2}                     ; pushing registers so that information isn't overwritten


		;Select/configure UART1 sources
		;Set SIM_SOPT5 for UART1 External
		LDR R0,=SIM_SOPT5
		LDR R1,=SIM_SOPT5_UART1_EXTERN_MASK_CLEAR
		LDR R2,[R0,#0]					 ;current SIM_SOPT5 value
		BICS R2,R2,R1					 ;only UART1 bits cleared
		STR R2,[R0,#0]					 ;update SIM_SOPT5

		;Enable clocks for UART1 and PORT E
		;Set SIM_SCGC4 for UART1 Clock Enabled
		LDR R0,=SIM_SCGC4
		LDR R1,=SIM_SCGC4_UART1CGC_MASK
		LDR R2,[R0,#0]					 ;current SIM_SCGC4 value
		ORRS R2,R2,R1					 ;only UART1 bit set
		STR R2,[R0,#0]					 ;update SIM_SCGC4

		;Select pins to connect to UART1
		;Set SIM_CGC5 for Port E Clock Enabled
		LDR R0,=SIM_SCGC5
		LDR R1,=SIM_SCGC5_PORTECGC_MASK
		LDR R2,[R0,#0]					 ;current SIM_SCGC5 value
		ORRS R2,R2,R1 					 ;only PORTE bit set
		STR R2,[R0,#0] 					 ;update SIM_SCGC5
		
		LDR R0,=PORTE_PCR0
		LDR R1,=PORT_PCR_SET_PTE0_UART1_TX
		STR R1,[R0,#0] 					 ;PortE_PCR0 = UART1_TX
		LDR R0,=PORTE_PCR1
		LDR R1,=PORT_PCR_SET_PTE1_UART1_RX
		STR R1,[R0,#0]					 ;PortE_PCR1 = UART1_RX

        ;Load base address for UART1
        LDR R0,=UART1_BASE              ; loading the UART1_BASE into R0

        ;Set UART1 baud rate—BDH before BDL

        MOVS R1,#UART_BDH_9600          ; moving the baud rate of 9600 into R1
        STRB R1,[R0,#UART_BDH_OFFSET]   ; initializing: storing the contents of R0 into the memory address of R1 with offset
        MOVS R1,#UART_BDL_9600
        STRB R1,[R0,#UART_BDL_OFFSET]

        ;Set UART1 character format for serial bit stream
        MOVS R1,#UART_C1_8N1
        STRB R1,[R0,#UART_C1_OFFSET]
        MOVS R1,#UART_C3_NO_TXINV
        STRB R1,[R0,#UART_C3_OFFSET]
        MOVS R1,#UART_C4_NO_DMA
        STRB R1,[R0,#UART_C4_OFFSET]
        MOVS R1,#UART_S2_NO_RXINV_BRK10_NO_LBKDETECT
        STRB R1,[R0,#UART_S2_OFFSET]

        ;Enable UART1 transmitter and receiver
        ;—only after preceding instructions
        MOVS R1,#UART_C2_T_RI
        STRB R1,[R0,#UART_C2_OFFSET]
	

        POP{R0-R2}                      ; popping registers so that we can continue in main code
        BX LR
;>>>>>   end subroutine code <<<<<
            ALIGN
       
;**********************************************************************
Init_PIT
;Init_PIT initializes the PIT to generate an interrupt every 10-milliseconds.
; enables pit
;sets the timing
;first two big blocks

		PUSH{R1-R3}
        LDR R1,=SIM_SCGC6                       ;load the sim address
        LDR R2,=SIM_SCGC6_PIT_MASK              ;load a mask
        LDR R3,[R1,#0]                          ;save R1's value in a register
        ORRS R3,R3,R2                           ;OR the sim address and the mask together
        STR R3,[R1,#0]                          ;store the number with enabled/cleared bits.

        ;configures the PIT to generate an interrupt form channel 0 every 0.01 s
        ;add equates to code
        ;overwriting registers
        ;second block
        LDR R1,=PIT_BASE
        LDR R2,=PIT_MCR_EN_FRZ
        STR R2,[R1,#PIT_MCR_OFFSET]             ;enable PIT module
        LDR R1,=PIT_CH0_BASE                    ;load the channel 0 base
        LDR R2,=PIT_LDVAL_10ms                  ;load the millisecond address
        STR R2,[R1,#PIT_LDVAL_OFFSET]           ;interrupt 0.01 s
        LDR R2,=PIT_TCTRL_CH_IE                 ;load another address
        STR R2,[R1,#PIT_TCTRL_OFFSET]           ;store the TCRL into the pit base with TCRL offset
		POP{R1-R3}
		BX LR

;**********************************************************************
PIT_ISR
;On a PIT interrupt, if the (byte) variable RunStopWatch is not zero, PIT_ISR increments the (word) variable by one.
;otherwise, it leaves count unchanged.
;Registers modified: R4 and R5
		CPSID I
		PUSH {LR}

        LDR R0,=Count                   ;getting the address of the count variable
        LDR R1,[R0,#0]                  ;getting the value at count's address
        LDR R2,=RunStopWatch            ;getting the address of the RunStopWatch variable
        LDRB R2,[R2,#0]                 ;getting the value at RunStopWatch's address

        CMP R2,#0                       ;check if RunStopWatch's value is zero
        BNE increment_count             ;if RunStopWatch is not zero, increment count by one
        B finish_PIT_ISR                ;finish the ISR so that it doen't continue and increment count

increment_count
        ADDS R1,R1,#1                   ;increment count by one
		STR R1,[R0,#0]
finish_PIT_ISR
		;TFLG code in lecture section of mycourses
		LDR R1,=PIT_CH0_BASE
		LDR R2,=PIT_TFLG_TIF_MASK
		STR R2,[R1,#PIT_TFLG_OFFSET]
		CPSIE I
		POP {PC}
;**********************************************************************

;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    Dummy_Handler      ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD    Dummy_Handler      ;28:UART0 (status; error)
            DCD    UART1_ISR	      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    PIT_ISR            ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<	
;all prompts and informational strings are null terminated.
prompt				DCB	 	"Enter any key to start the game. ",0				         	    ; new line, then ",0" tells putstring when to stop
wrong				DCB 	":	Wrong",0	
correct				DCB 	":	Correct--color was ",0	
out_of_time			DCB 	":	Out of time--color was ",0	
red					DCB 	"red",0	
green				DCB 	"green",0	
both				DCB 	"both",0	
neither				DCB 	"neither",0	
your_score_is		DCB 	"Game over. Your score is ",0	
points				DCB 	" points!",0	
round_number		DCB 	"Round #",0	






;>>>>>   end constants here <<<<<	
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
RxQBuffer SPACE Q_BUF_SZ
	ALIGN
TxQBuffer SPACE Q_BUF_SZ
	ALIGN
RxQRecord SPACE Q_REC_SZ
	ALIGN
TxQRecord SPACE Q_REC_SZ
	ALIGN
QBuffer SPACE Q_BUF_SZ					        		;queue contents
	ALIGN
QRecord SPACE Q_REC_SZ                                  ;queue management record
	ALIGN
Count SPACE 4
    ALIGN
RunStopWatch SPACE 1
    ALIGN
user_string SPACE MAX_STRING							;allocate maximum amount of space that you need
	ALIGN
;>>>>>   end variables here <<<<<
            END                