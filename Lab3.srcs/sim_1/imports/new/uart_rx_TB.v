`timescale 1ns / 1ps
module uart_rx_TB ();
 
  // We downscale the values in the simulation
  // this will give CLKS_PER_BIT = 100 / 10 = 10
  localparam CLK_FREQ_inst  = 100;
  localparam BAUD_RATE_inst = 10;
  localparam CLKS_PER_BIT   = CLK_FREQ_inst / BAUD_RATE_inst;
 
  // inputs (define as reg)
  reg         rClk = 0;
  reg         rRst = 0;
  reg         rRxSerial = 1;  // Idle high for UART
  
  // outputs (define as wire)
  wire        wRxDV;
  wire [7:0]  wRxByte;
  
  // instantiate module under test
  uart_rx #( .CLK_FREQ(CLK_FREQ_inst), .BAUD_RATE(BAUD_RATE_inst) ) 
  UART_RX_INST
    (.iClk(rClk),
     .iRst(rRst),
     .iRxSerial(rRxSerial),
     .oRxDV(wRxDV),
     .oRxByte(wRxByte)
     );
  
  // define the clock
  localparam T = 4;
  always
    #(T/2) rClk <= !rClk;
  
  // Task to send a byte over serial
  task UART_SEND_BYTE;
    input [7:0] data;
    integer i;
    begin
      // Send start bit (low)
      rRxSerial = 0;
      #(CLKS_PER_BIT * T);
      
      // Send data bits (LSB first)
      for (i = 0; i < 8; i = i + 1)
      begin
        rRxSerial = data[i];
        #(CLKS_PER_BIT * T);
      end
      
      // Send stop bit (high)
      rRxSerial = 1;
      #(CLKS_PER_BIT * T);
    end
  endtask
 
  // input stimulus
  initial
    begin
      // Display info for simulation
      $display("UART RX Testbench Started");
      $display("Clock period: %0d ns, Bit period: %0d ns", T, CLKS_PER_BIT * T);
      
      // Begin with serial line idle (high) and circuit in reset
      rRxSerial = 1;
      rRst = 1;
      #(5*T);
      
      // Disable reset
      rRst = 0;
      #(5*T);
      
      // Send first test byte
      $display("Sending byte: 0x56");
      UART_SEND_BYTE(8'h56);
      
      // Wait to see if byte was received correctly
      #(5*T);
      
      // Send second test byte
      $display("Sending byte: 0xA3");
      UART_SEND_BYTE(8'hA3);
      
      // Wait to see if byte was received correctly
      #(5*T);
      
      // Send third test byte with a specific bit pattern to test edge cases
      $display("Sending byte: 0xFF");
      UART_SEND_BYTE(8'hFF);
      
      // Allow enough time for the receiver to process
      #(10*T);
      
      $display("UART RX Testbench Completed");
      $stop;  // Stop simulation
    end
   
  // Monitor to check received bytes
  always @(posedge wRxDV)
  begin
    $display("Time %0t: Byte received: 0x%h", $time, wRxByte);
  end
   
endmodule