`timescale 1ns / 1ps

`define CHAR_WIDTH  9
`define CHAR_HEIGHT 12

`define ALPHABET_SIZE   35

`define KERNING         1
`define MAX_STRING_SIZE 30

module VGA_Manager #(
    parameter LIT_SIZE = 10
)(
    input  clk   ,
    input  reset ,
    /*------------------------------------------------------------------------------
    --  FLAGS FOR EXECUTING
    ------------------------------------------------------------------------------*/
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
    output reg write_enable
);

parameter WIDTH = 640, HEIGHT = 480;

parameter MAX_PIXEL_COUNT = WIDTH * HEIGHT;

/*------------------------------------------------------------------------------
--  PREVIOUS/CURRENT VALUES FOR SAVING FRAME INFO
------------------------------------------------------------------------------*/
reg [9:0]  x_coord      ;
reg [9:0]  y_coord      ;
reg [11:0] current_color;
reg [1:0] user_command ;

integer i, j, k;
/*------------------------------------------------------------------------------
--  STRING/CHAR REGISTERS FOR DRAW
------------------------------------------------------------------------------*/
reg [$clog2(`MAX_STRING_SIZE)-1:0] 	char_counter                      ;
reg [0:$clog2(`ALPHABET_SIZE)-1] 	usr_string_reg [0:`MAX_STRING_SIZE-1];
reg [0:$clog2(`ALPHABET_SIZE)-1] 	sys_string_reg [0:`MAX_STRING_SIZE-1];
reg [$clog2(`MAX_STRING_SIZE)-1:0] 	string_size                       ;
reg [0:`CHAR_WIDTH-1] char_reg [0:`CHAR_HEIGHT-1]                     ;
reg [0:`CHAR_WIDTH-1] alphabet [0:`CHAR_HEIGHT-1] [0:`ALPHABET_SIZE-1];

/*------------------------------------------------------------------------------
--  REGISTERS FOR STORAGE X/Y COORDS FOR CURRENT CHAR
------------------------------------------------------------------------------*/
reg [3:0] x_char, y_char;

localparam  STATES = 9,
            STATE_SIZE = $clog2(STATES);
localparam WAIT_COMMAND         = 4'd0,
           DELAY                = 4'd1,
           WAIT_PARAMETER       = 4'd2,
           WAIT_START_FLAG      = 4'd3,
           START_DRAW           = 4'd4,
           DRAW_ASCII_SEQUENCE  = 4'd5,
           DRAW_SYMBOLS         = 4'd6,
           DRAW_ONE_SYMBOL      = 4'd7,
           END_EXEC             = 4'd8;

reg [STATE_SIZE-1:0] state;

initial begin
    state <= WAIT_COMMAND;
    VGA_input_busy <= 1'd0;
    VGA_exec_busy  <= 1'd0;
    write_enable   <= 1'd0;
    $readmemb("alphabet.mem", alphabet);
    for (i = 0; i < `MAX_STRING_SIZE; i = i + 1)
        string_reg[i] <= 0;
	for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
		char_reg[j] <= 0;
    i <= 0;
	j <= 0;
	k <= 0;
end

always @(posedge clk) begin
    if (reset) begin
        VGA_input_busy <= 1'd0;
        VGA_exec_busy  <= 1'd0;
        write_enable   <= 1 'd0;
        for (i = 0; i < `MAX_STRING_SIZE; i = i + 1)
        begin
            string_reg[i] <= 0;
        end
        for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
            char_reg[j] <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
    end else begin
        case (state)
            WAIT_COMMAND: begin
                if (usr_symb_rdy) begin
                    VGA_busy <= 1'b1;
                    string_size   <= 1;
                    string_reg[0] <= usr_symb;
                    state <= DRAW_SYMBOL;
                end else if (cpu_char_rdy) begin
                    VGA_busy <= 1'b1;
                    string_size   <= 1;
                    string_reg[0] <= sys_char;
                    state <= DRAW_SYMBOL;
                end else if (cpu_cmd_ready) begin
                    case (cpu_command)
                        3'd1: begin // PIXL
                            user_command <= 1;
                        end
                        3'd2: begin // ASCI
                            user_command <= 2;
                        end
                        3'd3: begin // TRIG
                            user_command <= 3;
                        end
                        3'd4: begin // CPU ASCI (CSTR)
                            state <= DRAW_SYMBOLS;
                        end
                        3'd5: begin // endline
                            x_coord <= 5; // start left position
                            y_coord <= y_coord - (CHAR_HEIGHT + KERNING); // new string
                        end
                        3'd6: begin // reset frame and draw usr_structure
                            
                        end
                    endcase
                    VGA_busy <= 1'b1;
                end else begin
                    VGA_busy <= 1'b0;
                end
            end

            START_DRAW: begin
                case(cpu_command)
                    PIXL: begin
                        vram_address <= y1_coord * WIDTH + x1_coord;
                        write_enable <= 1'd1;
                        state <= END_EXEC;
                    end

                    ASCI: begin
                        y_coord <= y1_coord;
                        x_coord <= x1_coord;
                        char_counter <= 0;
                        y_char <= 0;
                        x_char <= 0;
                        string_size <= string_len;
                        state <= DRAW_SYMBOLS;
                    end

                    TRIG: begin
                    
                    end
                endcase
            end
            
            DRAW_SYMBOLS: begin
                write_enable <= 1'd0;
                if (char_counter == string_size)
                begin
                    y_coord <= y_coord + `CHAR_HEIGHT;
                    state <= END_EXEC;
                end else begin
                    for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                        char_reg[i] <= alphabet[i][string_reg[char_counter]];
                    x_char <= 0;
                    y_char <= 0;
                    vram_address <= y_coord * WIDTH + x_coord;
                    state <= DRAW_ONE_SYMBOL;
                end
            end
            
            DRAW_ONE_SYMBOL: begin
                if (y_char == `CHAR_HEIGHT) begin
                    char_counter <= char_counter + 1;
                    x_coord <= x_coord + `CHAR_WIDTH;
                    write_enable <= 1'd0;
                    state <= DRAW_SYMBOLS;
                end else if (x_char == `CHAR_WIDTH) begin
                    write_enable <= 1'd0;
                    y_char <= y_char + 1;                              
                    x_char <= 0;                                       
                    vram_address <= vram_address + WIDTH - `CHAR_WIDTH;
                    state <= DRAW_ONE_SYMBOL;
                end else if (x_char == 0) begin
                    if(char_reg[y_char][0]) begin
                        write_enable <= 1'd1;
                    end else begin
                        write_enable <= 1'd0;
                    end
                    x_char <= 1;
                    state <= DRAW_ONE_SYMBOL;
                end else begin
                    if(char_reg[y_char][x_char]) begin
                        write_enable <= 1'd1;
                    end else begin
                        write_enable <= 1'd0;
                    end
                    x_char <= x_char + 1;
                    vram_address <= vram_address + 1;
                end
            end
            END_EXEC: begin
                write_enable <= 1'd0;
                state <= WAIT_COMMAND;
            end
        endcase
    end
end

endmodule