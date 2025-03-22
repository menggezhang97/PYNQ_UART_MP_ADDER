`timescale 1ns / 1ps


module full_adder(
    input wire iA, iB, iCarry,
    output wire oSum, oCarry
    );
    
    assign oSum = ((iA ^ iB) ^ (iCarry));
    assign oCarry = ((iA ^ iB) & iCarry)|(iA & iB);
    
    
endmodule
