`timescale 1ns / 1ps

module ripple_carry_adder_Nb#(
    parameter   ADDER_WIDTH = 16
    )
    (
    input   wire [ADDER_WIDTH-1:0]  iA, iB, 
    input   wire                    iCarry,
    output  wire [ADDER_WIDTH-1:0]  oSum, 
    output  wire                    oCarry
);

    wire[ADDER_WIDTH:0] internal_carry;
    
    // Set the initial carry input
    assign internal_carry[0] = iCarry;
    
    // variable to control for loop
    genvar i;

    // instantiate N 1-bit full adders
    generate
        for (i=0; i<ADDER_WIDTH; i=i+1) 
        begin
            full_adder full_adder_inst (
                .iA(iA[i]),
                .iB(iB[i]),
                .iCarry(internal_carry[i]),
                .oSum(oSum[i]),
                .oCarry(internal_carry[i+1])
            );
        end 
    endgenerate
    
    // Connect the final carry out
    assign oCarry = internal_carry[ADDER_WIDTH];

endmodule