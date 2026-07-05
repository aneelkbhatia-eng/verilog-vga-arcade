module ringCounter
  (
    input        clk,
    input        advance,
    input        reset,
    output [3:0] Ring
   );
   
   wire [3:0]star; 
   
   FDRE #(.INIT(1'b1)) bit_0(.C(clk), .R(reset), .CE(advance), .D(star[3]), .Q(star[0]));
   FDRE #(.INIT(1'b0)) bit_1(.C(clk), .R(reset), .CE(advance), .D(star[0]), .Q(star[1]));
   FDRE #(.INIT(1'b0)) bit_2(.C(clk), .R(reset), .CE(advance), .D(star[1]), .Q(star[2]));
   FDRE #(.INIT(1'b0)) bit_3(.C(clk), .R(reset), .CE(advance), .D(star[2]), .Q(star[3]));
   
   assign Ring = star; 

endmodule
