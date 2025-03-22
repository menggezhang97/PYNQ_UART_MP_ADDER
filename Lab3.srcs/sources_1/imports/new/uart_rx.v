`timescale 1ns / 1ps

module uart_rx #(
    parameter   CLK_FREQ      = 125_000_000,
    parameter   BAUD_RATE     = 115_200,
    // Example: 125 MHz Clock / 115200 baud UART -> CLKS_PER_BIT = 1085 
    parameter   CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE
  )
  (
   input wire       iClk, iRst,
   input wire       iRxSerial, // Serial input line
   output wire      oRxDV,     // Data Valid signal 
   output wire [7:0] oRxByte   // Received byte
   );
  
  // State definition  
  localparam sIDLE         = 3'b000;
  localparam sRX_START     = 3'b001;
  localparam sRX_DATA      = 3'b010;
  localparam sRX_STOP      = 3'b011;
  localparam sDONE         = 3'b100;
  
  // Register variables required to drive the FSM
  //---------------------------------------------
  // Remember:  -> 'current' is the register output
  //            -> 'next' is the register input
  
  // -> FSM state
  reg [2:0] rFSM_Current, wFSM_Next; 
  
  // -> counter to keep track of the clock cycles
  reg [$clog2(CLKS_PER_BIT):0]   rCnt_Current, wCnt_Next;
    
  // -> counter to keep track of received bits
  // (between 0 and 7)
  reg [2:0] rBit_Current, wBit_Next;
  
  // -> the byte we are receiving
  reg [7:0] rRxData_Current, wRxData_Next;
  
  // -> temporary register for double-flop synchronization
  reg rRxSync1, rRxSync2;
  wire wRxSynced;
  
  // Double-flop synchronization of the serial input
  always @(posedge iClk)
  begin
    rRxSync1 <= iRxSerial;
    rRxSync2 <= rRxSync1;
  end
  
  assign wRxSynced = rRxSync2;
  
  // Register updates
  //------------------------------------------ 
  // Needs to be done with a clocked always block 
  // Don't forget the synchronous reset (default state)
  
  always @(posedge iClk)
  begin
    if (iRst==1)
      begin
        rFSM_Current <= sIDLE;
        rCnt_Current <= 0;
        rBit_Current <= 0;
        rRxData_Current <= 0;
      end
    else
      begin
        rFSM_Current <= wFSM_Next;
        rCnt_Current <= wCnt_Next;
        rBit_Current <= wBit_Next;
        rRxData_Current <= wRxData_Next;
      end
  end
  
  // Next state logic
  //------------------------------------------ 
  // -> this is a COMBINATIONAL module, which specifies the next state 
  //    of the FSM and also the next value of the previous registers
     
  always @(*)
    begin
      
      case (rFSM_Current)
      
        // IDLE STATE:
        // -> we simply wait here until iRxSerial goes low (start bit)   
        sIDLE :
          begin
            wCnt_Next = 0;
            wBit_Next = 0;
             
            if (wRxSynced == 0)  // Start bit detected (active low)
              begin
                wFSM_Next = sRX_START;
                wRxData_Next = 0;   // Clear data register
              end
            else
              begin    
                wFSM_Next = sIDLE;
                wRxData_Next = rRxData_Current;
              end
          end 
           
        // RX_START STATE:
        // -> we sample in the middle of the start bit to confirm it's valid
        // -> we wait for CLKS_PER_BIT/2 cycles to reach the middle
        sRX_START :
            begin
              wRxData_Next = rRxData_Current;
              wBit_Next = 0;
               
              if (rCnt_Current < (CLKS_PER_BIT/2 - 1))
                begin
                  wFSM_Next = sRX_START;
                  wCnt_Next = rCnt_Current + 1;
                end
              else
                begin
                  // Check if start bit is still low at the midpoint
                  if (wRxSynced == 0)
                    begin
                      wFSM_Next = sRX_DATA;
                      wCnt_Next = 0;  // Reset counter for full bit period
                    end
                  else
                    begin
                      // False start bit, go back to idle
                      wFSM_Next = sIDLE;
                      wCnt_Next = 0;
                    end
                end
            end 
           
           
          // RX_DATA STATE:
          // -> we sample 8 data bits in the middle of each bit period
          // -> we use rCnt_Current to count clock cycles 
          // -> we use rBit_Current to keep track of number of bits received
          // -> we shift in the received bits from LSB to MSB
          
          sRX_DATA :
            begin
              
              // Wait for middle of bit period to sample
              if (rCnt_Current < (CLKS_PER_BIT - 1))
                begin
                  wFSM_Next = sRX_DATA;
                  wCnt_Next = rCnt_Current + 1;
                  wRxData_Next = rRxData_Current;
                  wBit_Next = rBit_Current;
                end
              else
                begin
                  // Sample the bit at the middle of the period
                  wCnt_Next = 0;  // Reset counter for next bit
                  
                  // Sample data bit and shift it into the data register
                  // Shift the received bit into the MSB position
                  wRxData_Next = {wRxSynced, rRxData_Current[7:1]};
                  
                  if (rBit_Current < 7)
                    begin
                      wFSM_Next = sRX_DATA;
                      wBit_Next = rBit_Current + 1;
                    end
                  else
                    begin
                      wFSM_Next = sRX_STOP;
                      wBit_Next = 0;
                    end
                end
            end  
            
           
          // RX_STOP STATE:
          // -> we wait for the stop bit and verify it's high
          // -> we sample in the middle of the stop bit period
          sRX_STOP :
            begin
              wRxData_Next = rRxData_Current;
              wBit_Next = 0;
               
              if (rCnt_Current < (CLKS_PER_BIT - 1))
                begin
                  wFSM_Next = sRX_STOP;
                  wCnt_Next = rCnt_Current + 1;
                end
              else
                begin
                  // Stop bit should be high (1)
                  if (wRxSynced == 1)
                    begin
                      wFSM_Next = sDONE;
                    end
                  else
                    begin
                      // Framing error - stop bit not detected
                      // For simplicity, we still move to DONE state
                      wFSM_Next = sDONE;
                    end
                  wCnt_Next = 0;
                end
            end 
           
           
          // DONE STATE:
          // -> assert oRxDV for one clock cycle
          sDONE :
            begin
              wRxData_Next = rRxData_Current;
              wBit_Next = 0;
              wCnt_Next = 0;
              wFSM_Next = sIDLE;
            end
           
           
          default :
            begin   
              wFSM_Next = sIDLE;
              wCnt_Next = 0;
              wBit_Next = 0;
              wRxData_Next = 0;
            end 
        endcase
    end
 
  // Output logic
  //------------------------------------------ 
  // -> these are COMBINATIONAL circuits, which specify the value of
  //    the outputs, based on the current state of the registers used
  //    in the FSM
  
  // Output oRxDV (Data Valid)
  //  -> it is '0' by default
  //  -> it is '1' during sDONE
  assign oRxDV = (rFSM_Current == sDONE) ? 1 : 0;
  
  // Output oRxByte : the received byte
  assign oRxByte = rRxData_Current;
   
endmodule