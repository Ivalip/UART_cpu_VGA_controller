`timescale 1ns / 1ps

module divider 
#(
    parameter MOD = 4,
    parameter STEP = 1
)
(
    input clk,
    output reg clk_out
);

localparam HALF_MOD = MOD / 2;
localparam COUNTER_VALUE_SIZE = $clog2(MOD + 1);

reg [COUNTER_VALUE_SIZE-1:0] counter_value;

initial begin
    counter_value <= 0;
    clk_out <= 0;
end

always @(posedge clk)
    begin
        counter_value <= counter_value + STEP;
        

        // Переключаем сигнал clk_out каждые HALF_MOD тактов
        if (counter_value == (HALF_MOD - 1)) begin
            clk_out       <= ~clk_out;
            counter_value <= 0;
        end
    end
endmodule