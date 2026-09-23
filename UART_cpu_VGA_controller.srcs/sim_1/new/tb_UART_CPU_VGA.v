`timescale 1ns / 1ps

module tb_top;
`include "global_defines.vh"

parameter CLOCK_RATE = 100_000_000;
parameter BAUD_RATE = 2_500_000;
parameter DIGIT_RANK = 6;
parameter DIGIT_COUNT = 1;
parameter LED_DELITEL = 16000;
localparam BIT_TIME = 1_000_000_000 / BAUD_RATE;
localparam CR_CODE  = 8'h0D;
localparam WIDTH = 640, HEIGHT = 480;
reg clk;
reg reset;
reg RsRx;
         
wire [3:0] vgared, vgaGreen, vgaBlue;

wire [11:0] VGA_color;	   
wire  Hsync;
wire  Vsync;

wire UART_Input_Ready;               
wire UART_end_command;               
wire [DIGIT_RANK - 1:0] UART_Data_In;

wire clk_div_out;
wire vga_clk;

parameter CMD_COUNT = 22,
          LIT_SIZE = 10,
          CMD_SIZE  = $clog2(CMD_COUNT);
parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE;

wire [11:0] CPU_to_VGA_color, current_color;

// Handler connections
wire end_command, CPU_ready, command_ready;
// CPU connections
wire [BUS_WIDTH - 1 :0] CPU_command;

wire VGA_ready;

wire cpu_cmd_ready, cpu_char_rdy, write_char_en;
wire [2:0] cpu_to_vga_command;
wire [5:0] sys_char;

wire  [$clog2(`MAX_STRING_SIZE)-1:0] sys_string_len , user_string_len;

wire [9:0]  x1_coord,
            y1_coord,
            x2_coord,
            y2_coord,
            x3_coord,
            y3_coord;

// btn_filter btn_c_filter (
//     .CLK(clk),
//     .CLOCK_ENABLE(1'b1),
//     .IN_SIGNAL(reset),
//     .OUT_SIGNAL(),
//     .OUT_SIGNAL_ENABLE(reset)
// );

UART_Input_Manager #(
    .CLOCK_RATE (CLOCK_RATE),
    .BAUD_RATE  (BAUD_RATE),
    .DIGIT_RANK (DIGIT_RANK)
) uart_input_manager (
    .clk(clk),                    
    .reset(reset),                
    .RsRx(RsRx),                  
    .out(UART_Data_In),           
    .ready_out(UART_Input_Ready), 
    .end_command(UART_end_command)
);

CMD_Handler #(
    .DIGIT_RANK (DIGIT_RANK),
    .CMD_COUNT  (CMD_COUNT ),
    .LIT_SIZE   (LIT_SIZE  )
) cmd_handler (
    .clk            (clk),
    .rst_n          (reset),

    .symbol         (UART_Data_In),
    .symb_ready     (UART_Input_Ready),
    .end_command    (UART_end_command),

    .CPU_ready      (CPU_ready),
    .cpu_command    (CPU_command),
    .command_ready  (command_ready)
);

cpu #(
    .CMD_COUNT (CMD_COUNT),
    .LIT_SIZE  (LIT_SIZE )
) VGA_cpu (
    .clk                  (clk                ),              
    .reset                (reset              ),

    .extern_command_ready (command_ready),
    .extern_command       (CPU_command),
    .CPU_ready            (CPU_ready),

    .VGA_ready            (!VGA_ready),
    .vga_command_flag     (cpu_to_vga_command),
    .vga_cmd_ready        (cpu_cmd_ready),
    .color                (CPU_to_VGA_color),

    .user_string_len      (user_string_len),
    .sys_string_len       (sys_string_len),
    .write_char_en        (write_char_en),

    .cpu_char_rdy         (cpu_char_rdy),
    .sys_char             (sys_char),

    .x1_coord             (x1_coord),
    .y1_coord             (y1_coord),
    .x2_coord             (x2_coord),
    .y2_coord             (y2_coord),
    .x3_coord             (x3_coord),
    .y3_coord             (y3_coord)
);

divider #(.MOD(4)) VGA_divider
(
    .clk (clk),
    .clk_out (vga_clk)
);

wire [9:0] next_x, next_y;
wire write_enable;
wire [18:0] vram_address, VGA_address;
assign VGA_address = next_y * WIDTH + next_x;

VGA vga(
   .clk          (vga_clk    ),     // 25 MHz
   .reset        (reset      ),     // Active high
   .color_in     (VGA_color  ),
   .next_x       (next_x     ),     // x-coordinate of NEXT pixel that will be drawn
   .next_y       (next_y     ),     // y-coordinate of NEXT pixel that will be drawn
   .hsync        (Hsync      ),     // HSYNC (to VGA connector)
   .vsync        (Vsync      ),     // VSYNC (to VGA connctor)
   .vga_red      (vgaRed     ),     // RED (to resistor DAC VGA connector)
   .vga_green    (vgaGreen   ),     // GREEN (to resistor DAC to VGA connector)
   .vga_blue     (vgaBlue    ),     // BLUE (to resistor DAC to VGA connector)
   .sync         (           ),     // SYNC to VGA connector
   .blank        (           )      // BLANK to VGA connector
);

BRAM_mem_gen_12x307200 VGA_MEM
(
    .clka  (clk          ),
    .wea   (write_enable ),
    .addra (vram_address ),
    .dina  (current_color),
    .douta (         ),
    .clkb  (vga_clk      ),
    .web   (         ),
    .addrb (VGA_address  ),
    .dinb  (         ),
    .doutb (VGA_color    )
);

VGA_Manager VGA_manager (
    .clk                (clk  ),
    .reset              (reset),

    .cpu_cmd_ready   (cpu_cmd_ready),
    .cpu_command     (cpu_to_vga_command),

    .usr_symb_rdy    (UART_Input_Ready),
    .usr_symb        (UART_Data_In),

    .cpu_char_rdy    (cpu_char_rdy),
    .write_char_en   (write_char_en),
    .sys_char        (sys_char),

    .color           (CPU_to_VGA_color),
    .sys_string_len  (sys_string_len  ),
    .user_string_len (user_string_len ),
    .x1_coord        (x1_coord),
    .y1_coord        (y1_coord),
    .x2_coord        (x2_coord),
    .y2_coord        (y2_coord),
    .x3_coord        (x3_coord),
    .y3_coord        (y3_coord),
    .vram_address    (vram_address),
    .VGA_busy        (VGA_ready),
    .write_enable    (write_enable),
    .current_color   (current_color)
);

task uart_send_byte;
    input [7:0] data;
    integer bit_idx;
    begin
        RsRx = 1'b0; // �����-���
        #(BIT_TIME);
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            RsRx = data[bit_idx];
            #(BIT_TIME);
        end
        RsRx = 1'b1;
        #(BIT_TIME);
        #(BIT_TIME * 2);
        repeat (200) @(posedge clk);
        wait (CPU_ready == 1'b1 && VGA_manager.VGA_busy == 1'b0);
    end
endtask

// ��������� ������� Enter (CR)
task task_send_uart_cr;
    begin
        wait(!cmd_handler.translator.Translator_busy);
        uart_send_byte(CR_CODE);
        repeat (200) @(posedge clk);
        wait (CPU_ready == 1'b1 && VGA_manager.VGA_busy == 1'b0);
    end

endtask

// ��������������� ���������� ������ ����� ��� ���������� ������������ ���� ������
task task_send_string_cmd;
    input [3:0] chars_count;   // ������ �������� ��������� ������� (��� 3-� �������� ��� 2)
    input [47:0] user_symbols; // ���� � ������������ �� 8 ��� ASCII-���������
    integer char_idx;
    begin
        wait(!cmd_handler.translator.Translator_busy);
        for (char_idx = chars_count; char_idx >= 0; char_idx = char_idx - 1) begin
            uart_send_byte(user_symbols[char_idx*8 +: 8]);
        end
    end
endtask

// =========================================================================
// ��������������� ������ ������������������� � ������� ����
// =========================================================================
task task_send_uart_sequence;
    input [1:0] sequence_type;
    begin
        case (sequence_type)
            // --- �������� �1: ������� (PIXL) ---
            2'd1: begin
                // ��� ������� � ������� ASCII
                uart_send_byte(8'h50); // 'P'
                uart_send_byte(8'h49); // 'I'
                uart_send_byte(8'h58); // 'X'
                uart_send_byte(8'h4C); // 'L'
                
                // ����� � ASCII: "0", "0", "8" � �.�.
                task_send_string_cmd(2, "008"); task_send_uart_cr(); // Green
                task_send_string_cmd(2, "003"); task_send_uart_cr(); // Red
                task_send_string_cmd(2, "002"); task_send_uart_cr(); // Blue
                
                // ���������� X1=2, Y1=5
                task_send_string_cmd(2, "002"); task_send_uart_cr(); // X1
                task_send_string_cmd(2, "005"); task_send_uart_cr(); // Y1
                
                // ��������� ������ ����� CR ��� �������� � DRAW
                task_send_uart_cr();
            end
            
            // --- �������� �2: ����� (ASCI) ---
            2'd2: begin
                // ��� ������� � ������� ASCII
                uart_send_byte(8'h41); // 'A'
                uart_send_byte(8'h53); // 'S'
                uart_send_byte(8'h43); // 'C'
                uart_send_byte(8'h49); // 'I'
                
                // ����� ������ � ���������� ������ ���������� �����
                task_send_string_cmd(2, "008"); task_send_uart_cr(); // Green
                task_send_string_cmd(2, "003"); task_send_uart_cr(); // Red
                task_send_string_cmd(2, "002"); task_send_uart_cr(); // Blue
                task_send_string_cmd(2, "002"); task_send_uart_cr(); // X1
                task_send_string_cmd(2, "002"); task_send_uart_cr(); // Y1
                
                // ����� ����������� ����������� ������: 6 ������ -> "006"
                task_send_string_cmd(2, "006"); task_send_uart_cr();
                
                // ������� ����� "PRIVET" (������ ���������������� ���������� ��������)
                uart_send_byte(8'h50); // 'P'
                uart_send_byte(8'h52); // 'R'
                uart_send_byte(8'h49); // 'I'
                uart_send_byte(8'h56); // 'V'
                uart_send_byte(8'h45); // 'E'
                uart_send_byte(8'h54); // 'T'
                
                // ��� ���������������� �������� �������: ������� ENDL � ������� DRAW
                task_send_uart_cr();
                task_send_uart_cr();
            end
        endcase
    end
endtask

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // ������ 5 �� ����������� ������ -> ������ ������ 10 ��
end
initial begin
    reset = 0;
    RsRx = 1'b1;
    reset  = 1'b0;
    #40;
    reset = 1'b1;
    #200; 
    reset = 1'b0;
    wait (CPU_ready == 1'b1 && VGA_manager.VGA_busy == 1'b0);
    task_send_uart_sequence(2'd1);
    repeat (300) @(posedge clk);
    wait (CPU_ready == 1'b1 && VGA_manager.VGA_busy == 1'b0);
    reset = 1'b1;
    #200; 
    reset = 1'b0;
    wait (CPU_ready == 1'b1 && VGA_manager.VGA_busy == 1'b0);
    task_send_uart_sequence(2'd2);
    wait (VGA_manager.state == VGA_manager.DRAW_SYMBOL || VGA_manager.write_enable == 1'b1);
    wait (VGA_manager.VGA_busy == 1'b0);
    #50000; 
    $finish;
end

endmodule