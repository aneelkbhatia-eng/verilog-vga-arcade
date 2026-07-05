`timescale 1ns / 1ps
module time_counter(
    input  clk,
    input  inc,
    input  reset,
    output [15:0] Count
);
   
    wire [15:0] counter_q;

    countUD16L u_cnt (
        .clk  (clk),
        .reset(reset),
        .up   (inc),
        .dw   (1'b0),
        .ld   (1'b0),
        .Din  (16'b0),
        .Q    (counter_q),
        .utc  (),
        .dtc  ()
    );

    assign Count = counter_q;
endmodule


//count 16
module countUD16L
  ( input        clk,
    input        reset,
    input        up,
    input        dw,
    input        ld,
    input  [15:0] Din,
    output [15:0] Q,
    output       utc,
    output       dtc
  );

  
   wire [15:0] d_next;
   wire [15:0] alu_sum;
   wire [15:0] q_reg;
   wire       en_step;
   wire       en_ff;

   FDRE #(.INIT(1'b0)) ff0 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[0]), .Q(q_reg[0]));
   FDRE #(.INIT(1'b0)) ff1 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[1]), .Q(q_reg[1]));
   FDRE #(.INIT(1'b0)) ff2 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[2]), .Q(q_reg[2]));
   FDRE #(.INIT(1'b0)) ff3 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[3]), .Q(q_reg[3]));
   FDRE #(.INIT(1'b0)) ff4 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[4]), .Q(q_reg[4]));
   FDRE #(.INIT(1'b0)) ff5 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[5]), .Q(q_reg[5]));
   FDRE #(.INIT(1'b0)) ff6 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[6]), .Q(q_reg[6]));
   FDRE #(.INIT(1'b0)) ff7 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[7]), .Q(q_reg[7]));
   FDRE #(.INIT(1'b0)) ff8 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[8]), .Q(q_reg[8]));
   FDRE #(.INIT(1'b0)) ff9 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[9]), .Q(q_reg[9]));
   FDRE #(.INIT(1'b0)) ff10 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[10]), .Q(q_reg[10]));
   FDRE #(.INIT(1'b0)) ff11 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[11]), .Q(q_reg[11]));
   FDRE #(.INIT(1'b0)) ff12 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[12]), .Q(q_reg[12]));
   FDRE #(.INIT(1'b0)) ff13 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[13]), .Q(q_reg[13]));
   FDRE #(.INIT(1'b0)) ff14 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[14]), .Q(q_reg[14]));
   FDRE #(.INIT(1'b0)) ff15 (.C(clk), .R(reset), .CE(en_ff), .D(d_next[15]), .Q(q_reg[15]));

   assign Q = q_reg;

   assign en_step = up ^ dw;
   assign en_ff   = ld | en_step;

   mux16bit u_sel (.A(alu_sum), .B(Din), .Sel(ld), .C(d_next));
   AddSub16 u_alu (.A(q_reg), .B(16'b0000_0000_0000_0001), .sub(dw), .S(alu_sum), .ovfl());

   assign utc = &Q;
   assign dtc = &(~Q);

endmodule

//addsub8
module AddSub16
  ( input  [15:0] A,
    input  [15:0] B,
    input        sub,
    output [15:0] S,
    output       ovfl
  );

    
    wire [15:0] b_eff;
    
    mux16bit u_bsel (.A(B), .B(~B), .Sel(sub), .C(b_eff));
    adder16  u_add  (.A(A), .B(b_eff), .cin(sub), .S(S), .ovfl(ovfl));

endmodule


//mux16
module mux16bit
  ( input  [15:0] A,
    input  [15:0] B,
    input        Sel,
    output [15:0] C
  );

  assign C = (~{16{Sel}} & A) | ({16{Sel}} & B);

endmodule


//adder16
module adder16
  ( input  [15:0] A,
    input  [15:0] B,
    input        cin,
    output [15:0] S,
    output       cout,
    output       ovfl
  );

   
    wire c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15;

    fullAdd fa0 (.A(A[0]), .B(B[0]), .Cin(cin), .S(S[0]), .Cout(c1));
    fullAdd fa1 (.A(A[1]), .B(B[1]), .Cin(c1),  .S(S[1]), .Cout(c2));
    fullAdd fa2 (.A(A[2]), .B(B[2]), .Cin(c2),  .S(S[2]), .Cout(c3));
    fullAdd fa3 (.A(A[3]), .B(B[3]), .Cin(c3),  .S(S[3]), .Cout(c4));
    fullAdd fa4 (.A(A[4]), .B(B[4]), .Cin(c4),  .S(S[4]), .Cout(c5));
    fullAdd fa5 (.A(A[5]), .B(B[5]), .Cin(c5),  .S(S[5]), .Cout(c6));
    fullAdd fa6 (.A(A[6]), .B(B[6]), .Cin(c6),  .S(S[6]), .Cout(c7));
    fullAdd fa7 (.A(A[7]), .B(B[7]), .Cin(c7),  .S(S[7]), .Cout(c8));
    fullAdd fa8 (.A(A[8]), .B(B[8]), .Cin(c8),  .S(S[8]), .Cout(c9));
    fullAdd fa9 (.A(A[9]), .B(B[9]), .Cin(c9),  .S(S[9]), .Cout(c10));
    fullAdd fa10 (.A(A[10]), .B(B[10]), .Cin(c10),  .S(S[10]), .Cout(c11));
    fullAdd fa11 (.A(A[11]), .B(B[11]), .Cin(c11),  .S(S[11]), .Cout(c12));
    fullAdd fa12 (.A(A[12]), .B(B[12]), .Cin(c12),  .S(S[12]), .Cout(c13));
    fullAdd fa13 (.A(A[13]), .B(B[13]), .Cin(c13),  .S(S[13]), .Cout(c14));
    fullAdd fa14 (.A(A[14]), .B(B[14]), .Cin(c14),  .S(S[14]), .Cout(c15));
    fullAdd fa15 (.A(A[15]), .B(B[15]), .Cin(c15),  .S(S[15]), .Cout(cout));

    assign ovfl = c15 ^ cout;

endmodule


module fullAdd
  ( input  A,
    input  B,
    input  Cin,
    output S,
    output Cout
  );

    
    wire ha_c0;
    wire ha_s0;
    wire ha_c1;

    halfAdd ha0 (.A(A),    .B(B),   .S(ha_s0), .C(ha_c0));
    halfAdd ha1 (.A(ha_s0),.B(Cin), .S(S),     .C(ha_c1));

    assign Cout = ha_c0 | ha_c1;

endmodule


module halfAdd
  ( input  A,
    input  B,
    output S,
    output C
  );

    assign S = A ^ B;
    assign C = A & B;

endmodule