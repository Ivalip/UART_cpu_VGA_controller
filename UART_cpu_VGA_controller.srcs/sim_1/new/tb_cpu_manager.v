`timescale 1ns/1ps

`define MAX_STRING_SIZE 30

module tb_cpu_manager;

localparam CMD_COUNT = 22, LIT_SIZE = 10, CMD_SIZE  = $clog2(CMD_COUNT);
localparam BUS_WIDTH = CMD_SIZE + LIT_SIZE;

integer matrix_file;
reg drawing_active;

reg clk;
reg reset;
reg extern_command_ready;
reg [BUS_WIDTH - 1 : 0] extern_command;
reg [5:0] usr_symb;
reg usr_symb_rdy;

wire CPU_ready, VGA_busy, vga_cmd_ready;
wire [2:0] vga_command_flag;
wire [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len, sys_string_len;
wire [5:0] sys_char;
wire cpu_char_rdy, write_char_en, write_enable;
wire [9:0] x1_coord, y1_coord, x2_coord, y2_coord, x3_coord, y3_coord;
wire [18:0] vram_address;
wire [11:0] current_color;
wire [11:0] cpu_color;
wire [4:0] cpu_cmd_cop;
wire [9:0] cpu_cmd_literal;
assign cpu_cmd_cop = VGA_cpu.cop;
assign cpu_cmd_literal = VGA_cpu.literal;

localparam PIXL = 5'd0,  ASCI = 5'd1,  TRIG = 5'd2,
           CSLN = 5'd3,  CCHR = 5'd4,  CSTR = 5'd5,
           DRAW = 5'd6,  WAIT = 5'd7,  USLN = 5'd8,
           UCHR = 5'd9,  CLRR = 5'd10, CLRG = 5'd11,
           CLRB = 5'd12, CRX1 = 5'd13, CRX2 = 5'd14,
           CRX3 = 5'd15, CRY1 = 5'd16, CRY2 = 5'd17,
           CRY3 = 5'd18, EROR = 5'd19, ENDL = 5'd20;

localparam A = 6'd10, B = 6'd11, C = 6'd12, D = 6'd13, 
           E = 6'd14, F = 6'd15, G = 6'd16, H = 6'd17,
           I = 6'd18, J = 6'd19, K = 6'd20, L = 6'd21,
           M = 6'd22, N = 6'd23, O = 6'd24, P = 6'd25,
           Q = 6'd26, R = 6'd27, S = 6'd28, T = 6'd29,
           U = 6'd30, V = 6'd31, W = 6'd32, X = 6'd33,
           Y = 6'd34, Z = 6'd35;

cpu VGA_cpu (
    .clk                  ( clk                  ),
    .reset                ( reset                ), 
    .extern_command_ready ( extern_command_ready ),
    .extern_command       ( extern_command       ),
    .CPU_ready            ( CPU_ready            ),
    .VGA_ready            ( !VGA_busy            ), 
    .vga_command_flag     ( vga_command_flag     ),
    .vga_cmd_ready        ( vga_cmd_ready        ),
    .user_string_len      ( user_string_len      ),
    .sys_string_len       ( sys_string_len       ),
    .cpu_char_rdy         ( cpu_char_rdy         ), 
    .write_char_en        ( write_char_en        ), 
    .sys_char             ( sys_char             ), 
    .color                ( cpu_color            ), 
    .x1_coord             ( x1_coord             ),
    .y1_coord             ( y1_coord             ),
    .x2_coord             ( x2_coord             ),
    .y2_coord             ( y2_coord             ),
    .x3_coord             ( x3_coord             ),
    .y3_coord             ( y3_coord             ) 
);

VGA_Manager monitor_manager(
    .clk                ( clk               ),
    .reset              ( reset             ),
    .cpu_cmd_ready      ( vga_cmd_ready     ),
    .cpu_command        ( vga_command_flag  ),
    .usr_symb_rdy       ( usr_symb_rdy      ), 
    .usr_symb           ( usr_symb          ), 
    .cpu_char_rdy       ( cpu_char_rdy      ), 
    .write_char_en      ( write_char_en     ), 
    .sys_char           ( sys_char          ), 
    .color              ( cpu_color         ), 
    .sys_string_len     ( sys_string_len    ),
    .user_string_len    ( user_string_len   ),
    .x1_coord           ( x1_coord          ),
    .y1_coord           ( y1_coord          ),
    .x2_coord           ( x2_coord          ),
    .y2_coord           ( y2_coord          ),
    .x3_coord           ( x3_coord          ),
    .y3_coord           ( y3_coord          ),
    .vram_address       ( vram_address      ),
    .VGA_busy           ( VGA_busy          ),
    .write_enable       ( write_enable      ),
    .current_color      ( current_color     ) 
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    matrix_file = $fopen("symbol_matrix_dump.txt", "w");
    if (matrix_file == 0) begin
        $finish;
    end
    extern_command_ready = 0;
    extern_command = 0;
    usr_symb = 0;
    usr_symb_rdy = 0;
    reset = 0;
    @(posedge clk);
    do_reset();
    testsuite();
    $stop;
    $fclose(matrix_file);
end

always @(posedge clk) begin
    if (drawing_active) begin
        if (write_enable) begin
            $fwrite(matrix_file, "1");
        end else begin
            $fwrite(matrix_file, "0");
        end
    end
end

always @(*) begin
    drawing_active = (monitor_manager.state == monitor_manager.DRAW_CPU_STRING_SYMBOL ||
                      monitor_manager.state == monitor_manager.DRAW_USER_STRING_SYMBOL||
                      monitor_manager.state == monitor_manager.DRAW_SYMBOL);
end

reg prev_drawing_active;
reg [3:0] prev_x_char;

always @(posedge clk) begin
    if (reset) begin
        prev_drawing_active <= 1'b0;
        prev_x_char         <= 4'd0;
    end else begin
        prev_drawing_active <= drawing_active;
        prev_x_char         <= monitor_manager.x_char;
        if (drawing_active) begin
            if (monitor_manager.x_char < 9) begin
                if (monitor_manager.x_char != prev_x_char || (monitor_manager.x_char == 0 && !prev_drawing_active)) begin
                    if (write_enable) begin
                        $fwrite(matrix_file, "1");
                    end else begin
                        $fwrite(matrix_file, "0");
                    end
                end
            end
            if (monitor_manager.x_char == 9 && prev_x_char != 9) begin
                $fwrite(matrix_file, "\n");
            end
        end
        if (prev_drawing_active && !drawing_active) begin
            $fwrite(matrix_file, "\n-------------------\n\n"); 
        end
    end
end

task task_send_uart_char;
    input [5:0] char_code;
    begin
        $display("Send %h symbol %d", char_code, $time);
        usr_symb     <= char_code;
        usr_symb_rdy <= 1'b1;
        @(posedge clk);
        // #0.1;
        usr_symb     <= 6'd0;
        usr_symb_rdy <= 1'b0;
    end
endtask


task task_send_extern_cmd;
    input [4:0] cop_code;
    input [9:0] lit_value;
    begin
        wait(CPU_ready);
        wait(!VGA_busy);
        @(posedge clk);
        $display("Extern_command time %d", $time);
        extern_command <= {cop_code, lit_value};
        extern_command_ready <= 1'b1;
        @(posedge clk);
        extern_command_ready <= 1'b0;
        extern_command <= 0;
    end
endtask

task send_command;
    input [3:0] chars;
    input [41:0] user_symbols; 
    input [4:0]  cop_code;     
    input [9:0]  lit_value;    
    integer char_idx;
    begin
        if (!CPU_ready) begin
            wait(CPU_ready);
        end
        for (char_idx = chars; char_idx >= 0; char_idx = char_idx - 1) begin
            task_send_uart_char(user_symbols[char_idx*6 +: 6]);
            repeat (2) @(posedge clk);
            wait(!VGA_busy);
        end
        task_send_extern_cmd(cop_code, lit_value);
        repeat (3) @(posedge clk);
    end
endtask

task do_reset;
    begin
        reset <= 1;
        @(posedge clk);
        reset <= 0;
        @(posedge clk);
        wait(monitor_manager.state == monitor_manager.WAIT_COMMAND);
    end
endtask

task send_PIXL_cmd;
    begin
        wait(CPU_ready == 1'b1);
        send_command(3, {P,I,X,L}, PIXL, 10'd0);
        send_command(2, {6'd0, 6'd0, 6'd8}, CLRG, 10'd8);
        send_command(2, {6'd0,6'd0,6'd3}, CLRR, 10'd3);
        send_command(2, {6'd0,6'd0,6'd2}, CLRB, 10'd2);
        send_command(2, {6'd0,6'd0,6'd2}, CRX1, 10'd2);
        send_command(2, {6'd0,6'd0,6'd2}, CRY1, 10'd2);
        wait(VGA_cpu.pc == 284);
        send_command(3, {D,R,A,W}, DRAW, 10'd0);
        wait(monitor_manager.state == monitor_manager.END_EXEC);
    end
endtask

task send_ASCI_cmd;
    begin
        wait(CPU_ready == 1'b1);
        send_command(3, {A,S,C,I}, ASCI, 10'd0);
        send_command(2, {6'd0, 6'd0, 6'd8}, CLRG, 10'd8);
        send_command(2, {6'd0,6'd0,6'd3}, CLRR, 10'd3);
        send_command(2, {6'd0,6'd0,6'd2}, CLRB, 10'd2);
        send_command(2, {6'd0,6'd0,6'd2}, CRX1, 10'd2);
        send_command(2, {6'd0,6'd0,6'd2}, CRY1, 10'd2);
        send_command(2, {6'd0,6'd0,6'd6}, USLN, 10'd6);
        send_command(0, {P}, UCHR, 10'd25);
        send_command(0, {R}, UCHR, 10'd27);
        send_command(0, {I}, UCHR, 10'd18);
        send_command(0, {V}, UCHR, 10'd31);
        send_command(0, {E}, UCHR, 10'd14);
        send_command(0, {T}, UCHR, 10'd29);
        send_command(3, {E, N, D, L}, ENDL, 10'd0);
        wait(VGA_cpu.pc == 284);
        send_command(3, {D,R,A,W}, DRAW, 10'd0);
        wait(monitor_manager.state == monitor_manager.END_EXEC);
    end
endtask

task testsuite;
    begin
        do_reset();
        send_PIXL_cmd();
        do_reset();
        send_ASCI_cmd();
        #100;
        $finish;
    end
endtask

endmodule
