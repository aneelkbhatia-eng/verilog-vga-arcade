`timescale 1ns / 1ps

module syncs(
    input [15:0] vpx,
    input [15:0] hpx,
    output vsync,
    output hsync
    );
   
    assign hsync = ~((hpx >= 16'd656) & (hpx <= 16'd752)); // Hsync Low Region
    assign vsync = ~((vpx >= 16'd490) & (vpx < 16'd492)); // Vsync Low Region

endmodule