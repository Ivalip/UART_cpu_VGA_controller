`timescale 1ns / 1ns

module top #
(
    localparam CLOCK_RATE  = 100_000_000,
    localparam BAUD_RATE   = 9600,       
    localparam DIGIT_RANK  = 6,
    localparam LED_DELITEL = 8192
) (
    input  clk,             
    input  RsRx,            
    input  rst,             
//    output [7:0] AN,        
//    output [6:0] SEG,       
    
    output [3:0] vgaRed,    
    output [3:0] vgaGreen,  
    output [3:0] vgaBlue,   
    
    output  Hsync,
    output  Vsync
);

localparam WIDTH = 640, HEIGHT = 480;
parameter CMD_COUNT = 22,
          LIT_SIZE = 10,
          CMD_SIZE  = $clog2(CMD_COUNT);
parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE;

wire [11:0] CPU_to_VGA_color, current_color, VGA_color;

// UART-Manager connections
wire UART_Input_Ready;               
wire UART_end_command;               
wire [DIGIT_RANK - 1:0] UART_Data_In;

// Handler connections
wire end_command, CPU_ready, command_ready;
// CPU connections
wire [BUS_WIDTH - 1 :0] CPU_command;

wire VGA_busy, reset;

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

btn_filter btn_c_filter (
    .CLK(clk),
    .CLOCK_ENABLE(1'b1),
    .IN_SIGNAL(rst),
    .OUT_SIGNAL(),
    .OUT_SIGNAL_ENABLE(reset)
);

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

    .VGA_ready            (~VGA_busy),
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

wire seg_clk_div_out;
wire vga_clk;

// divider #(.MOD(LED_DELITEL)) clk_LED_divider (
//     .clk(clk),
//     .clk_out(seg_clk_div_out)
// );

// SevenSegmentLED seg(
//     .clk(seg_clk_div_out),
//     .RESET(1'b0),
//     .NUMBER(8'h00),
//     .AN_MASK(8'hFF),
//     .AN(AN),
//     .SEG(SEG)
// );

divider #(.MOD(4)) VGA_divider
(
    .clk (clk),
    .clk_out (vga_clk)
);

//initial begin
//    next_x <= 0;
//    next_y <= 0;
//end

//always @(posedge vga_clk) begin
//    if (next_y == HEIGHT - 1) begin
//        next_x <= 0;
//        next_y = 0;
//    end else begin
//        if (next_x == WIDTH - 1) begin
//            next_x <= 0;
//            next_y <= next_y + 1;
//        end else next_x <= next_x + 1;
//    end
//end

wire [9:0] next_x, next_y;
wire write_enable;
wire [18:0] vram_address, VGA_address;
assign VGA_address = next_y * WIDTH + next_x;

//VGA_2_mod vga_core (
//    .clk      (clk),          // Тактовая частота 25 МГц с выхода делителя
//    .mem_data (VGA_color),        // 12-битный цвет пикселя, считанный из BRAM
//    .mem_addr (VGA_address), // Выходной адрес чтения, генерируемый модулем
//    .vgaRed   (vgaRed),           // 4-бит Красный
//    .vgaGreen (vgaGreen),         // 4-бит Зеленый
//    .vgaBlue  (vgaBlue),          // 4-бит Синий
//    .Hsync    (Hsync),            // Линия строчной синхронизации
//    .Vsync    (Vsync),            // Линия кадровой синхронизации		
//    .vgaBegin (),  
//    .vgaEnd   ()     
//);

VGA_1_mod vga(
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
    .douta (             ),
    .clkb  (vga_clk      ),
    .web   (1'b0         ),
    .addrb (VGA_address  ),
    .dinb  (12'b0        ),
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
    .VGA_busy        (VGA_busy),
    .write_enable    (write_enable),
    .current_color   (current_color)
);

endmodule