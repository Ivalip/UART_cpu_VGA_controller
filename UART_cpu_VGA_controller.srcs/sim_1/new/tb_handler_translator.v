`timescale 1ns/1ps

module tb_handler_translator;

reg clk;
reg rst_n;
reg [5:0] usr_symb;
reg usr_symb_rdy;
reg end_command;
reg CPU_ready;

wire [14:0] cpu_command;
wire command_ready;

integer matrix_file;
wire write_enable;
assign write_enable = command_ready;
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
) uut (
    .clk           (clk),
    .rst_n         (rst_n),
    .symbol        (usr_symb),
    .symb_ready    (usr_symb_rdy),
    .CPU_ready     (CPU_ready),
    .end_command   (end_command),
    .cpu_command   (cpu_command),
    .command_ready (command_ready)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

always @(posedge clk) begin
    if (write_enable) begin
        $fwrite(matrix_file, "1");
    end else begin
        $fwrite(matrix_file, "0");
    end
end

task do_reset;
    begin
        rst_n <= 1;
        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
    end
endtask

task task_send_uart_char;
    input [5:0] char_code;
    begin
        $display("[%t] Sending UART symbol: %d", $realtime, char_code);
        wait(!uut.Translator_busy);
        usr_symb     <= char_code;
        usr_symb_rdy <= 1'b1;
        @(posedge clk);
        usr_symb_rdy <= 1'b0;
        repeat(4)@(posedge clk);
    end
endtask

task send_enter;
    begin
        wait(!uut.Translator_busy);
        $display("[%t] Sending Enter (end_command)", $realtime);
        end_command <= 1'b1;
        @(posedge clk);
        end_command <= 1'b0;
        repeat(4)@(posedge clk);
    end
endtask

task test_pixl_sequence;
    begin
        $display("\n--- Starting PIXL Sequence Test ---");
        task_send_uart_char(P);
        task_send_uart_char(I);
        task_send_uart_char(X);
        task_send_uart_char(L);
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D8);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D3);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        send_enter();
        wait(command_ready);
        wait(command_ready);
        $display("[%t] PIXL sequence finished. Output CPU Command: %b", $realtime, cpu_command);
        @(posedge clk);
    end
endtask

task test_asci_sequence;
    begin
        $display("\n--- Starting ASCI Sequence Test ---");
        task_send_uart_char(A);
        task_send_uart_char(S);
        task_send_uart_char(C);
        task_send_uart_char(I);
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D8);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D3);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D2);
        send_enter();
        task_send_uart_char(D0);
        task_send_uart_char(D0);
        task_send_uart_char(D6);
        send_enter();
        task_send_uart_char(P);
        task_send_uart_char(R);
        task_send_uart_char(I);
        task_send_uart_char(V);
        task_send_uart_char(E);
        task_send_uart_char(T);
        send_enter();
        send_enter();
        wait(command_ready);
        wait(command_ready);
        $display("[%t] ASCI sequence finished. Output CPU Command: %b", $realtime, cpu_command);
        @(posedge clk);
    end
endtask

initial begin
    matrix_file = $fopen("write_enable_log.txt", "w");
    if (matrix_file == 0) begin
        $display("Error: Could not open log file!");
        $finish;
    end
    usr_symb = 0;
    usr_symb_rdy = 0;
    end_command = 0;
    CPU_ready = 1;
    do_reset();
    test_pixl_sequence();
    repeat(10) @(posedge clk);
    do_reset();
    test_asci_sequence();
    repeat(20) @(posedge clk);
    $fclose(matrix_file);
    $display("\nAll tests finished successfully.");
    $finish;
end

endmodule