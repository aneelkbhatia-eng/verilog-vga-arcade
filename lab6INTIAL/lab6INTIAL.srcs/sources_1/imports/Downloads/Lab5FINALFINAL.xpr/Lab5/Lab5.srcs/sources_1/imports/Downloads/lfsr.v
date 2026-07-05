module lfsr(
    input clk,
    input reset,
    input en,
    output [7:0] Lfsr
);
    wire [7:0] rnd; 
    wire xor_o; 
    
    assign xor_o = rnd[0]^rnd[5]^rnd[6]^rnd[7];
    // Your code here.
    FDRE #(.INIT(1'b1)) lfsr_0 (.C(clk), .R(reset), .CE(en), .D(xor_o), .Q(rnd[0]));
    FDRE #(.INIT(1'b0)) lfsr_1 (.C(clk), .R(reset), .CE(en), .D(rnd[0]), .Q(rnd[1]));
    FDRE #(.INIT(1'b0)) lfsr_2 (.C(clk), .R(reset), .CE(en), .D(rnd[1]), .Q(rnd[2]));
    FDRE #(.INIT(1'b0)) lfsr_3 (.C(clk), .R(reset), .CE(en), .D(rnd[2]), .Q(rnd[3]));
    FDRE #(.INIT(1'b0)) lfsr_4 (.C(clk), .R(reset), .CE(en), .D(rnd[3]), .Q(rnd[4]));
    FDRE #(.INIT(1'b0)) lfsr_5 (.C(clk), .R(reset), .CE(en), .D(rnd[4]), .Q(rnd[5]));
    FDRE #(.INIT(1'b0)) lfsr_6 (.C(clk), .R(reset), .CE(en), .D(rnd[5]), .Q(rnd[6]));
    FDRE #(.INIT(1'b0)) lfsr_7 (.C(clk), .R(reset), .CE(en), .D(rnd[6]), .Q(rnd[7]));
    
    assign Lfsr = rnd; 
    
endmodule