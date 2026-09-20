`timescale 1ns/1ps

`define MAX_STRING_SIZE 30

module tb_handler_cpu;

reg clk;
reg rst_n;
wire reset_cpu;
assign reset_cpu = rst_n;

reg [5:0] usr_symb;
reg usr_symb_rdy;
reg end_command;

wire [14:0] interconnect_bus;
wire interconnect_ready;
wire CPU_ready;

reg mock_vga_ready;
wire vga_cmd_ready;
wire [2:0] vga_command_flag;

wire cpu_char_rdy;
wire write_char_en;
wire [5:0] sys_char;
wire [11:0] cpu_color;
wire [9:0] x1, y1, x2, y2, x3, y3;
wire [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len, sys_string_len;

localparam A = 6'd10, B = 6'd11, C = 6'd12, D = 6'd13, 
           E = 6'd14, F = 6'd15, G = 6'd16, H = 6'd17,
           I = 6'd18, J = 6'd19, K = 6'd20, L = 6'd21,
           M = 6'd22, N = 6'd23, O = 6'd24, P = 6'd25,
           Q = 6'd26, R = 6'd27, S = 6'd28, T = 6'd29,
           U = 6'd30, V = 6'd31, W = 6'd32, X = 6'd33,
           Y = 6'd34, Z = 6'd35;

localparam D0 = 6'd0, D1 = 6'd1, D2 = 6'd2, D3 = 6'd3,
           D4 = 6'd4, D5 = 6'd5, D6 = 6'd6, D7 = 6'd7,
           D8 = 6'd8, D9 = 6'd9;

CMD_Handler #(
    .DIGIT_RANK(6),
    .CMD_COUNT(22),
    .LIT_SIZE(10)
) handler_inst (
    .clk           (clk),
    .rst_n         (rst_n),
    .symbol        (usr_symb),
    .symb_ready    (usr_symb_rdy),
    .CPU_ready     (CPU_ready),
    .end_command   (end_command),
    .cpu_command   (interconnect_bus),
    .command_ready (interconnect_ready)
);

cpu #(
    .CMD_COUNT(22),
    .LIT_SIZE(10)
) cpu_inst (
    .clk                  (clk),
    .reset                (reset_cpu),
    .extern_command_ready (interconnect_ready),
    .extern_command       (interconnect_bus),
    .CPU_ready            (CPU_ready),
    .VGA_ready            (mock_vga_ready),
    .vga_command_flag     (vga_command_flag),
    .vga_cmd_ready        (vga_cmd_ready),
    .user_string_len      (user_string_len),
    .sys_string_len       (sys_string_len),
    .cpu_char_rdy         (cpu_char_rdy),
    .write_char_en        (write_char_en),
    .sys_char             (sys_char),
    .color                (cpu_color),
    .x1_coord             (x1),
    .y1_coord             (y1),
    .x2_coord             (x2),
    .y2_coord             (y2),
    .x3_coord             (x3),
    .y3_coord             (y3)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end



task do_system_reset;
    begin
        rst_n <= 1;
        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
    end
endtask

task send_symbol;
    input [5:0] ascii_code;
    begin
        wait(CPU_ready);
        usr_symb     <= ascii_code;
        usr_symb_rdy <= 1'b1;
        @(posedge clk);
        usr_symb_rdy <= 1'b0;
        repeat (20) @(posedge clk);
    end
endtask

task send_enter;
    begin
        wait(CPU_ready);
        end_command <= 1'b1;
        @(posedge clk);
        end_command <= 1'b0;
        repeat (20) @(posedge clk);
    end
endtask

task execute_pixl_test;
    begin
        send_symbol(P);  send_symbol(I);  send_symbol(X);  send_symbol(L);
        send_symbol(D0); send_symbol(D0); send_symbol(D8); send_enter();
        send_symbol(D0); send_symbol(D0); send_symbol(D3); send_enter();
        send_symbol(D0); send_symbol(D0); send_symbol(D2); send_enter();
        send_symbol(D0); send_symbol(D0); send_symbol(D2); send_enter();
        send_symbol(D0); send_symbol(D0); send_symbol(D5); send_enter();
        send_enter();
        wait(x1 == 10'd2 && y1 == 10'd5);
    end
endtask

task execute_error_test;
    begin
        send_symbol(P); send_symbol(R); send_symbol(I); send_symbol(V);
        wait(cpu_inst.cop == 5'd19); 
    end
endtask

initial begin
    usr_symb     = 0;
    usr_symb_rdy = 0;
    end_command  = 0;
    do_system_reset();
    mock_vga_ready <= 1;
    wait(CPU_ready == 1'b1);
    execute_pixl_test();
    repeat(20) @(posedge clk);
    do_system_reset();
    wait(CPU_ready == 1'b1);
    execute_error_test();
    repeat(50) @(posedge clk);
    $finish;
end

endmodule