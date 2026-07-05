`timescale 1ns / 1ps

module pixelAddress(
    input clk,
    input reset,  
    output [15:0] hpx,
    output [15:0] vpx,
    output active
    );
   
// HPX HORIZONTAL:
    // set the LED range:
    wire hpx_en;
    assign hpx_en = 1'b1; // horizontal is always on (lecture)
    wire h_last;
    assign h_last = (hpx == 16'd799); // last pixel of the full 800-pixel line
    wire h_up;
    assign h_up = hpx_en & ~h_last; // count up by one
    wire h_dw;
    assign h_dw = 1'b0; // cant go down
    wire [15:0] h_Din;
    assign h_Din = 16'd0; // 16 bit input via lab
    wire h_utc, h_dtc;
   
    countUD16L HPX_counter(.clk(clk), .reset(reset), .up(h_up), .dw(h_dw), .ld(h_last), .Din(h_Din), .Q(hpx), .utc(h_utc), .dtc(h_dtc));
   
// VPX VERTICAL:
    //set the LED range:
    wire vpx_en;
    assign vpx_en = (hpx == 16'd799); // end of line pulse, 1 clock cycle signals that tells the vertical counter when it can change
    wire v_last;
    assign v_last = (vpx == 16'd524); // las row of the full 525-row frame.
    wire v_ld;
    assign v_ld = vpx_en & v_last; // reset vpx back to 0 when end of line and on the last row
    wire v_up;
    assign v_up = vpx_en & ~v_last; // count up by one  
    wire v_dw;
    assign v_dw = 1'b0; // vertical counter never counts downward per Lab 6
    wire [15:0] v_Din; // 16 bit input
    assign v_Din = 16'd0;
    wire v_utc, v_dtc;
   
    countUD16L VPX_counter( .clk(clk), .reset(reset), .up(v_up), .dw(v_dw), .ld(v_ld), .Din(v_Din), .Q(vpx), .utc(v_utc), .dtc(v_dtc));
   
    assign active = (hpx < 16'd640) & (vpx < 16'd480); // Lab guideline says that the active region is 640 x 480
   
endmodule