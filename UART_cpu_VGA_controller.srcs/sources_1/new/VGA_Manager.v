`timescale 1ns / 1ps

`define CHAR_WIDTH  9
`define CHAR_HEIGHT 12

`define ALPHABET_SIZE   37

`define KERNING         1
`define MAX_STRING_SIZE 30

module VGA_Manager (
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
    output reg write_enable        ,
    output reg [11:0] current_color
);

parameter WIDTH = 640, HEIGHT = 480;

parameter MAX_PIXEL_COUNT = WIDTH * HEIGHT;

/*------------------------------------------------------------------------------
--  PREVIOUS/CURRENT VALUES FOR SAVING FRAME INFO
------------------------------------------------------------------------------*/
reg [9:0]  x_coord      ;
reg [9:0]  y_coord      ;
reg [1:0] user_command ;

integer i, j;
/*------------------------------------------------------------------------------
--  STRING/CHAR REGISTERS FOR DRAW
------------------------------------------------------------------------------*/
reg [$clog2(`MAX_STRING_SIZE)-1:0] 	char_counter                      ;
reg [0:$clog2(`ALPHABET_SIZE)-1] 	usr_string_reg [0:`MAX_STRING_SIZE-1];
reg [0:$clog2(`ALPHABET_SIZE)-1] 	sys_string_reg [0:`MAX_STRING_SIZE-1];
// reg [$clog2(`MAX_STRING_SIZE)-1:0] 	string_size                       ;
reg [0:`CHAR_WIDTH-1] char_reg [0:`CHAR_HEIGHT-1]                     ;
reg [0:`CHAR_WIDTH-1] alphabet [0:`CHAR_HEIGHT-1] [0:`ALPHABET_SIZE-1];

/*------------------------------------------------------------------------------
--  REGISTERS FOR STORAGE X/Y COORDS FOR CURRENT CHAR
------------------------------------------------------------------------------*/
reg [3:0] x_char, y_char;

localparam  STATES = 7,
            STATE_SIZE = $clog2(STATES);

localparam WAIT_COMMAND             = 4'd0, 
           RESET_FRAME              = 4'd1,
           DRAW_CPU_STRING          = 4'd2,
           DRAW_CPU_STRING_SYMBOL   = 4'd3,
           DRAW_USER_STRING         = 4'd4,
           DRAW_USER_STRING_SYMBOL  = 4'd5,
           DRAW_SYMBOL              = 4'd6,
           END_EXEC                 = 4'd7;

reg [STATE_SIZE-1:0] state;

initial begin
    current_color <= 12'hFFF;
    state <= WAIT_COMMAND;
    VGA_busy <= 1'd0;
    write_enable <= 1'd0;
    $readmemb("alphabet.mem", alphabet);
    for (i = 0; i < `MAX_STRING_SIZE; i = i + 1) begin
        usr_string_reg[i] <= 0;
        sys_string_reg[i] <= 0;
    end
	for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
		char_reg[j] <= 0;
    i <= 0;
	j <= 0;
end

always @(posedge clk) begin
    if (reset) begin
        current_color <= 12'hFFF;
        VGA_busy <= 1'd0;
        write_enable <= 1'd0;
        for (i = 0; i < `MAX_STRING_SIZE; i = i + 1) begin
            usr_string_reg[i] <= 0;
            sys_string_reg[i] <= 0;
        end
        for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
            char_reg[j] <= 0;
        i <= 0;
        j <= 0;
    end else begin
        case (state)
            WAIT_COMMAND: begin
                if (usr_symb_rdy) begin
                    VGA_busy <= 1'b1;
                    for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                        char_reg[i] <= alphabet[i][usr_symb];
                    state <= DRAW_SYMBOL;
                end else if (cpu_char_rdy) begin
                    sys_string_reg[char_counter] <= sys_char;
                    char_counter <= char_counter + 1;
                end else if (write_char_en) begin
                    usr_string_reg[char_counter] <= sys_char;
                    char_counter <= char_counter + 1;
                end else if (cpu_cmd_ready) begin
                    VGA_busy <= 1'b1;
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
                        3'd4: begin // CPU ASCI (CSTR) (только после заполнения строки идет отрисовка)
                            state <= DRAW_CPU_STRING;
                        end
                        3'd5: begin // endline
                            x_coord <= 5; // start left position
                            y_coord <= y_coord + (`CHAR_HEIGHT + `KERNING); // new string
                        end
                        3'd6: begin // reset frame and draw usr_structure
                            write_enable <= 1;
                            vram_address <= 0;
                            state <= RESET_FRAME;
                        end
                    endcase
                end else begin
                    VGA_busy <= 1'b0;
                end
            end

            RESET_FRAME: begin
                if (vram_address != MAX_PIXEL_COUNT) begin
                    vram_address <= vram_address + 1;
                end else begin
                    write_enable <= 0;
                    case (user_command)
                        2'd1: begin
                            vram_address <= y1_coord * WIDTH + x1_coord;
                            current_color <= color;
                            write_enable <= 1'd1;
                            state <= END_EXEC;
                        end
                        2'd2: begin
                            current_color <= color;
                            y_coord <= y1_coord;
                            x_coord <= x1_coord;
                            char_counter <= 0;
                            y_char <= 0;
                            x_char <= 0;
                            state <= DRAW_USER_STRING;
                            vram_address <= y1_coord * WIDTH + x1_coord;
                        end
                        2'd3: begin
                        end
                    endcase
                    current_color <= color;
                end
            end

            DRAW_CPU_STRING: begin
                write_enable <= 1'd0;
                if (char_counter == sys_string_len) begin
                    char_counter <= 0;
                    state <= END_EXEC;
                end else begin
                    for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                        char_reg[i] <= alphabet[i][sys_string_reg[char_counter]];
                    x_char <= 0;
                    y_char <= 0;
                    vram_address <= y_coord * WIDTH + x_coord;
                    state <= DRAW_CPU_STRING_SYMBOL;
                end
            end
            
            DRAW_CPU_STRING_SYMBOL: begin
                if (y_char == `CHAR_HEIGHT) begin
                    char_counter <= char_counter + 1;
                    x_coord <= x_coord + `CHAR_WIDTH + `KERNING;
                    write_enable <= 1'd0;
                    state <= DRAW_CPU_STRING;
                end else if (x_char == `CHAR_WIDTH) begin
                    write_enable <= 1'd0;
                    y_char <= y_char + 1;                              
                    x_char <= 0;                                       
                    vram_address <= vram_address + WIDTH - `CHAR_WIDTH;
                end else if (x_char == 0) begin
                    if(char_reg[y_char][0]) begin
                        write_enable <= 1'd1;
                    end else begin
                        write_enable <= 1'd0;
                    end
                    x_char <= x_char + 1;
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

            DRAW_USER_STRING: begin
                write_enable <= 1'd0;
                if (char_counter == user_string_len) begin
                    char_counter <= 0;
                    state <= END_EXEC;
                end else begin
                    for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                        char_reg[i] <= alphabet[i][usr_string_reg[char_counter]];
                    x_char <= 0;
                    y_char <= 0;
                    vram_address <= y_coord * WIDTH + x_coord;
                    state <= DRAW_USER_STRING_SYMBOL;
                end
            end
            
            DRAW_USER_STRING_SYMBOL: begin
                if (y_char == `CHAR_HEIGHT) begin
                    char_counter <= char_counter + 1;
                    x_coord <= x_coord + `CHAR_WIDTH + `KERNING;
                    write_enable <= 1'd0;
                    state <= DRAW_USER_STRING;
                end else if (x_char == `CHAR_WIDTH) begin
                    write_enable <= 1'd0;
                    y_char <= y_char + 1;                              
                    x_char <= 0;                                       
                    vram_address <= vram_address + WIDTH - `CHAR_WIDTH;
                end else if (x_char == 0) begin
                    if(char_reg[y_char][0]) begin
                        write_enable <= 1'd1;
                    end else begin
                        write_enable <= 1'd0;
                    end
                    x_char <= x_char + 1;
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

            DRAW_SYMBOL: begin
                if (y_char == `CHAR_HEIGHT) begin
                    x_coord <= x_coord + `CHAR_WIDTH + `KERNING;
                    write_enable <= 1'd0;
                    state <= END_EXEC;
                end else if (x_char == `CHAR_WIDTH) begin
                    write_enable <= 1'd0;
                    y_char <= y_char + 1;                              
                    x_char <= 0;                                       
                    vram_address <= vram_address + WIDTH - `CHAR_WIDTH;
                end else if (x_char == 0) begin
                    if(char_reg[y_char][0]) begin
                        write_enable <= 1'd1;
                    end else begin
                        write_enable <= 1'd0;
                    end
                    x_char <= x_char + 1;
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
                y_char <= 0;
                x_char <= 0;
                write_enable <= 1'd0;
                VGA_busy <= 0;
                state <= WAIT_COMMAND;
            end
        endcase
    end
end

endmodule