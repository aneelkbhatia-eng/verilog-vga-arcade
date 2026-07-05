module edgeDetector(
    input clk, 
    input reset, 
    input button, 
    output edge_o 
    );
    
    wire [1:0]inner; 
    
    FDRE #(.INIT(1'b0)) bit(.C(clk), .R(reset), .CE(1'b1), .D(button), .Q(inner[0]));
    FDRE #(.INIT(1'b0)) bit1(.C(clk), .R(reset), .CE(1'b1), .D(inner[0]), .Q(inner[1]));
    
    assign edge_o = button & ~inner[0] & ~inner[1];
    
endmodule
