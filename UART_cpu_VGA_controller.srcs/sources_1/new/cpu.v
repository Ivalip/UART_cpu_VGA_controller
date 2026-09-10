`timescale 1ns / 1ps

module cpu #(
    parameter CMD_COUNT = 22,
    parameter LIT_SIZE = 10,
    parameter CMD_SIZE  = $clog2(CMD_COUNT),
    parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
    input clk,
    input reset,

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
    output reg  [5:0] sys_char , // cpu_input (cpu_char_rdy/write_char_en)
    
    output reg [9:0] vgaX,
    output reg [9:0] vgaY,

    output [11:0] color,

    output reg [9:0] x1_coord,
    output reg [9:0] y1_coord,
    output reg [9:0] x2_coord,
    output reg [9:0] y2_coord,
    output reg [9:0] x3_coord,
    output reg [9:0] y3_coord
);

reg [3:0] vgaRed  ;
reg [3:0] vgaGreen;
reg [3:0] vgaBlue ;

assign color = {vgaRed, vgaGreen, vgaBlue};

localparam CMD_MEM_SIZE = 128,
           ADDR_CMD_MEM_SIZE = $clog2(CMD_MEM_SIZE),
           COP_SIZE = $clog2(CMD_COUNT);

localparam PIXL = 0 ,
           ASCI = 1 ,
           TRIG = 2 ,

           CSLN = 3 ,
           CCHR = 4 ,
           CSTR = 5 ,
           
           DRAW = 6 ,
           WAIT = 7 ,

           USLN = 8 ,
           UCHR = 9 ,
           
           CLRR = 10,
           CLRG = 11,
           CLRB = 12,
           
           CRX1 = 13,
           CRX2 = 14,
           CRX3 = 15,
           
           CRY1 = 16,
           CRY2 = 17,
           CRY3 = 18,
           
           EROR = 19,
           ENDL = 20;

reg [BUS_WIDTH - 1 : 0] cmd_mem [0 : CMD_MEM_SIZE - 1];
reg [BUS_WIDTH - 1 : 0] cmd;                 // Current command
// reg [CMD_SIZE - 1 : 0] prev_extern_command; // Previous extern command

reg [ADDR_CMD_MEM_SIZE - 1 : 0] pc;         // Program counter
reg [1:0] stage_counter;

wire [COP_SIZE - 1 : 0] cop = cmd [BUS_WIDTH - 1 -: COP_SIZE];
wire [LIT_SIZE - 1 : 0] literal =  cmd [BUS_WIDTH - 1 - COP_SIZE -: LIT_SIZE];

initial begin
    CPU_ready <= 0;

    write_char_en <= 0;

    vgaX <= 0;
    vgaY <= 0;

    vgaRed   <= 0;
    vgaGreen <= 0;
    vgaBlue  <= 0;

    vga_command_flag <= 0;
    vga_cmd_ready <= 0;

    cpu_char_rdy  <= 0;
    write_char_en <= 0;
    sys_char      <= 0;

    user_string_len <= 0;
    sys_string_len  <= 0;

    stage_counter <= 0;
    pc <= 0;

    x1_coord <= 0;
    y1_coord <= 0;
    x2_coord <= 0;
    y2_coord <= 0;
    x3_coord <= 0;
    y3_coord <= 0;

    $readmemb("CPU_mem.mem", cmd_mem);
    cmd <= cmd_mem[0];
end

always @(posedge clk) begin
    if (reset) begin
        CPU_ready <= 0;

        write_char_en <= 0;

        vgaX <= 0;
        vgaY <= 0;

        vgaRed   <= 0;
        vgaGreen <= 0;
        vgaBlue  <= 0;

        vga_command_flag <= 0;
        vga_cmd_ready <= 0;

        cpu_char_rdy  <= 0;
        write_char_en <= 0;
        sys_char      <= 0;

        user_string_len <= 0;
        sys_string_len  <= 0;

        cmd <= cmd_mem[0];
        stage_counter <= 0;
        pc <= 0;

        x1_coord <= 0;
        y1_coord <= 0;
        x2_coord <= 0;
        y2_coord <= 0;
        x3_coord <= 0;
        y3_coord <= 0;
        
    end else begin
        if (stage_counter == 0) begin
            if (cop == WAIT) begin
                CPU_ready <= 1;
                if (extern_command_ready) begin
                    cmd <= extern_command;
                    CPU_ready <= 0;
                    stage_counter <= stage_counter + 1;
                end
            end else begin
                cmd <= cmd_mem[pc];
                stage_counter <= stage_counter + 1;
            end
        end

        if (stage_counter == 1) begin
            if (VGA_ready) begin
                case (cop)
                    EROR: begin
                        case (literal)
                            10'd1: pc <= 10;  // Jump to wait reset sequence (in cpu_mem.mem) after incorrect cmd
                            10'd2: pc <= 100; // Jump to wait reset sequence (in cpu_mem.mem) after incorrect value
                        endcase
                    end
                    CRX1: x1_coord <= literal[9:0];
                    CRY1: y1_coord <= literal[9:0];
                    CRX2: x2_coord <= literal[9:0];
                    CRY2: y2_coord <= literal[9:0];
                    CRX3: x3_coord <= literal[9:0];
                    CRY3: y3_coord <= literal[9:0];
                    CLRR: vgaRed   <= literal[3:0];
                    CLRG: vgaGreen <= literal[3:0];
                    CLRB: vgaBlue  <= literal[3:0];
                    CSLN: sys_string_len  <= literal[4:0];
                    USLN: user_string_len <= literal[4:0];
                    PIXL: begin
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 1;
                    end
                    ASCI: begin // for draw string from user
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 2;
                    end
                    TRIG: begin
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 3;
                    end
                    CSTR: begin // for draw string from cpu
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 4;
                    end
                    ENDL: begin // for endline
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 5;
                    end
                    CCHR: begin // draw char from cpu
                        sys_char <= literal[5:0];
                        cpu_char_rdy <= 1;
                    end
                    UCHR: begin // save user char from input
                        sys_char <= literal[5:0];
                        write_char_en <= 1;
                    end
                    DRAW: begin
                        vga_cmd_ready <= 1;
                        vga_command_flag <= 6;
                    end
                endcase
                stage_counter <= 2;
            end
        end
        
        if (stage_counter == 2) begin
            case (cop)
                PIXL, ASCI, TRIG, CSTR,
                ENDL, DRAW: begin
                    vga_cmd_ready <= 0;
                    pc <= pc + 1;
                end
                CCHR: begin
                    cpu_char_rdy <= 0;
                    pc <= pc + 1;
                end
                UCHR: begin
                    write_char_en <= 0;
                    pc <= pc + 1;
                end
                USLN, CSLN,CRX1, CRY1,
                CRX2, CRY2, CRX3, CRY3,
                CLRR, CLRG, CLRB: begin
                    pc <= pc + 1;
                end
            endcase
            stage_counter <= 0;
        end
    end
end

endmodule