`timescale 1ns / 1ns

module top #
(
    localparam CLOCK_RATE  = 100_000_000,    // Частота ПЛ�?С XC7A100T-1CSG324 семейства Artix-7 (в Гц)
    localparam BAUD_RATE   = 9600,	         // Скорость передачи данных по UART (в бод)
    localparam DIGIT_RANK  = 6,
    localparam LED_DELITEL = 8192
) (
	input  clk,		   // Синхросигнал
	input  RsRx,	   // Бит принимаемых данных (UART_RX)
	output [7:0] AN,
    output [6:0] SEG,
    
    output [3:0] vgaRed,	// Глубина красного цвета, закодированного четырьмя битами
	output [3:0] vgaGreen,  // Глубина зелёного цвета, закодированного четырьмя битами
	output [3:0] vgaBlue,	// Глубина синего цвета, закодированного четырьмя битами
	
	output  Hsync,	// Выход для сигнала горизонтальной синхронизации
	output  Vsync	// Выход для сигнала вертикальной синхронизации
);

wire [11:0] VGA_color;	                     // Шина для цвета, получаемая с выхода процессора

// UART-Manager connections
wire UART_Input_Ready;                       // Сигнал о готовности данных на UART
wire UART_end_command;                       // Сигнал о приеме команды с UART (CR)
wire [DIGIT_RANK - 1:0] UART_Data_In;        // Шина для приема данных с UART (6 bit)

// RAM connections
wire [33:0] RAM_command;
wire [33:0] CPU_command;
reg ROM_ENABLE;

// SevenSegmentLED connections
reg [47:0] shift_register;
reg [7:0] an_mask;

reg reset = 0;
reg [47:0] UART_command;
reg [33:0] command;
reg [3:0] param_counter;
reg [4:0] string_len;
reg [4:0] command_addr;

reg [2:0] state;

localparam  INPUT_COMMAND       = 0,
            INIT_PARAM_COUNTER  = 1,
            INPUT_PARAMS        = 2,
            INPUT_PARAM         = 3,
            INPUT_END_COMMAND   = 4,
            TRANSLATE_COMMAND   = 5,
            DELAY_COMMAND       = 6,
            WAIT_CPU_EXECUTION  = 7;

reg valid_in;
reg [1:0] error;
reg reset_flag;



reg [3:0] i;
reg [3:0] j;

initial
begin
    i <= 0;
    j <= 0;
    string_len <= 0;
    reset_flag <= 0;
    valid_in <= 0;
    UART_command <= 48'd0;
    command <= 34'd0;
    command_addr <= 5'd0;
    ROM_ENABLE <= 0;
    state <= INPUT_COMMAND;
    an_mask <= 8'b00000000;
    param_counter <= 0;
    shift_register <= 48'b0;
end

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

wire [4:0]  prog_counter;
wire [9:0]  next_y;
wire [9:0]  next_x;
wire [18:0] vram_address;
wire [9:0]  vgaY;
wire [9:0]  vgaX;
wire [18:0] VGA_address;
wire [11:0] color;


wire write_parameter, command_flag, VGA_input_busy, VGA_exec_busy, vga_blank, start_exec;
wire [23:0] VGA_Manager_command;
wire [9:0] litera;
wire write_enable;

wire vio_write;
wire [18:0] vio_address;
assign vram_address = next_y * 10'd640 + next_x;

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

cpu VGA_cpu (
    .clk                 (clk                ),              
    .reset               (reset              ),
    .start_cpu           (Ready_IN           ),
    .cpu_command         (CPU_command        ),
    .VGA_input_busy      (VGA_input_busy     ),
    .VGA_exec_busy       (VGA_exec_busy      ),
    
    .vgaX                (vgaX               ),    
    .vgaY                (vgaY               ),
    .color               (color              ),
    .command_flag        (command_flag       ),
    .write_parameter     (write_parameter    ),
    .VGA_Manager_command (VGA_Manager_command),
    .flag_end_ex         (start_exec         ),
    .litera              (litera             ),
    .prog_counter        (prog_counter       )
);

VGA_Manager VGA_manager (
    .clk                (clk                ),
    .reset              (reset              ),
    .vga_blank          (vga_blank          ),
    .start_exec         (start_exec         ),
    .command_flag       (command_flag       ),
    .command            (VGA_Manager_command),
    .color_in           (color              ),
    .vgaX               (vgaX               ),
    .vgaY               (vgaY               ),
    .write_parameter    (write_parameter    ),
    .litera             (litera             ),
    
    .vram_address       (VGA_address        ),
    .VGA_input_busy     (VGA_input_busy     ),
    .VGA_exec_busy      (VGA_exec_busy      ),
    .write_enable       (write_enable       )
);

// Автомат, занимающийся менеджментом входных данных с UART на ПЛ�?С
UART_Input_Manager #(.DIGIT_RANK(DIGIT_RANK)) uart_input_manager 
(
	.clk(clk), 		                  // Вход синхросигнала
	.reset(reset),
	.RsRx(RsRx),
	.out(UART_Data_In),                // Выходные данные с UART
	.ready_out(UART_Input_Ready),	   // Выход - сигнал о том, что символ на выходе UART сформирован
	.end_command(UART_end_command)     // Сигнал о принятии полной команды
);

endmodule