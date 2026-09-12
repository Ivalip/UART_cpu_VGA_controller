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
    output [7:0] AN,        
    output [6:0] SEG,       
    
    output [3:0] vgaRed,    
    output [3:0] vgaGreen,  
    output [3:0] vgaBlue,   
    
    output  Hsync,
    output  Vsync
);

parameter CMD_COUNT = 22,
parameter LIT_SIZE = 10,
parameter CMD_SIZE  = $clog2(CMD_COUNT),
parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE;

wire [11:0] VGA_color;

// UART-Manager connections
wire UART_Input_Ready;               
wire UART_end_command;               
wire [DIGIT_RANK - 1:0] UART_Data_In;

// Handler connections
wire end_command, CPU_ready, command_ready;
// CPU connections
wire [BUS_WIDTH - 1 :0] CPU_command;

input extern_command_ready,
input [BUS_WIDTH - 1 : 0] extern_command,
output reg CPU_ready,

input VGA_ready,
output reg [2:0] vga_command_flag,
output reg vga_cmd_ready,

output reg [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len,
output reg [$clog2(`MAX_STRING_SIZE)-1:0] sys_string_len,

output reg  cpu_char_rdy   , // 1 priority - for draw symbols from cpu (CCHR)
output reg  write_char_en  , // 2 priority - for save symbols from user_input (UCHR)
wire [5:0] sys_char , // cpu_input (cpu_char_rdy/write_char_en)

wire [11:0] cpu_color, vga_color;

wire [9:0]  x1_coord,
            y1_coord,
            x2_coord,
            y2_coord,
            x3_coord,
            y3_coord;

initial begin

end

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

cpu VGA_cpu (
    .clk                  (clk                ),              
    .reset                (reset              ),

    .extern_command_ready (),
    .extern_command       (),
    .CPU_ready            (),
    .VGA_ready            (),
    .vga_command_flag     (),
    .vga_cmd_ready        (),
    .user_string_len      (),
    .sys_string_len       (),
    .write_char_en        (),
    .cpu_char_rdy         (),
    .sys_char             (),
    .x1_coord             (x1_coord),
    .y1_coord             (y1_coord),
    .x2_coord             (x2_coord),
    .y2_coord             (y2_coord),
    .x3_coord             (x3_coord),
    .y3_coord             (y3_coord)
);

wire seg_clk_div_out;
wire vga_clk;

divider #(.MOD(LED_DELITEL)) clk_LED_divider (
    .clk(clk),
    .clk_out(seg_clk_div_out)
);

SevenSegmentLED seg(
    .clk(seg_clk_div_out),
    .RESET(1'b0),
    .NUMBER(shift_register),
    .AN_MASK(an_mask),
    .AN(AN),
    .SEG(SEG)
);

divider #(.MOD(4)) VGA_divider
(
    .clk (clk),
    .clk_out (vga_clk)
);

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
   .blank        (vga_blank  )      // BLANK to VGA connector
);

BRAM_mem_gen_12x307200 VGA_MEM
(
    .clka  (clk          ),
    .wea   (write_enable ),
    .addra (VGA_address  ),
    .dina  (color        ),
    .douta (1'b0         ),
    .clkb  (vga_clk      ),
    .web   (1'b0         ),
    .addrb (vram_address ),
    .dinb  (1'b0         ),
    .doutb (VGA_color    )
);

input  cpu_cmd_ready     , // 3 priority - for executing cpu_cmd
                            // (draw string, endline, draw all)
input  [2:0] cpu_command ,
/*------------------------------------------------------------------------------
--  MAIN PARAMETERS FOR DRAW
------------------------------------------------------------------------------*/
input  usr_symb_rdy      , // 0 priority - for draw symbols from UART_input immediately
input  [5:0] usr_symb    , // user_input
input  cpu_char_rdy      , // 1 priority - for draw symbols from cpu (CCHR)
input  write_char_en     , // 2 priority - for save symbols from user_input (UCHR) via cpu
input  [5:0] sys_char    , // cpu_input (cpu_char_rdy/write_char_en)
input  [11:0] color ,
input  [$clog2(`MAX_STRING_SIZE)-1:0] sys_string_len ,
input  [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len,
input  [9:0] x1_coord ,
input  [9:0] y1_coord ,
input  [9:0] x2_coord ,
input  [9:0] y2_coord ,
input  [9:0] x3_coord ,
input  [9:0] y3_coord ,
/*------------------------------------------------------------------------------
--  OUTPUTS FOR DRAWING
------------------------------------------------------------------------------*/
output reg [18:0] vram_address ,
output reg VGA_busy            ,
output reg write_enable        ,
output reg [11:0] current_color

VGA_Manager VGA_manager (
    .clk                (clk                ),
    .reset              (reset              ),

    .cpu_cmd_ready
    .cpu_command
    .usr_symb_rdy
    .usr_symb
    .cpu_char_rdy
    .write_char_en
    .sys_char
    .color
    .sys_string_len
    .user_string_len
    .x1_coord
    .y1_coord
    .x2_coord
    .y2_coord
    .x3_coord
    .y3_coord
);




endmodule