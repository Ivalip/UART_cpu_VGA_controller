`timescale 1ns / 1ps

module divider 
#(
    MOD = 4,
    STEP = 1
)
(
    input clk,
    output reg clk_out
);

localparam COUNTER_VALUE_SIZE = $clog2(MOD);

reg [COUNTER_VALUE_SIZE-1:0] counter_value;

initial
begin
    counter_value <= 0;
    clk_out <= 0;
end

always @(posedge clk)
    begin
        counter_value <= counter_value + STEP;
        clk_out <= 0;
        if (counter_value == MOD - 1)
        begin
            clk_out <= ~clk_out;
            counter_value <= 0;
        end
    end
endmodule