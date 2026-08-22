`timescale 1ns / 1ps

module cpu #(
    parameter CMD_COUNT = 45,
    parameter LIT_SIZE = 10,
    parameter CMD_SIZE  = $clog2(CMD_COUNT),
    parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
    input clk,
    input reset,

    input extern_command_ready,
    input [BUS_WIDTH - 1 : 0] extern_command,

    input VGA_ready,

    output reg endline,   // UART_endline

    output reg [$clog2(`MAX_STRING_SIZE)-1:0] string_len,
    output reg [5:0] char,
    output reg write_char_en,

    output reg [9:0] vgaX,
    output reg [9:0] vgaY,

    output [11:0] color,

    output reg [1:0] command_flag,
    output reg CPU_ready,

    output reg [9:0] x1_coord,
    output reg [9:0] y1_coord,
    output reg [9:0] x2_coord,
    output reg [9:0] y2_coord,
    output reg [9:0] x3_coord,
    output reg [9:0] y3_coord,

    output [4:0] pc
);

reg [3:0] vgaRed  ;
reg [3:0] vgaGreen;
reg [3:0] vgaBlue ;

assign color = {vgaRed, vgaGreen, vgaBlue};

localparam CMD_MEM_SIZE = 32,
           ADDR_CMD_MEM_SIZE = $clog2(CMD_MEM_SIZE),
           CMD_SIZE = 34,
           LIT_SIZE = 10,
           COP_SIZE = 24;

localparam CRX1 = 24'b001100_011011_100001_000001,
           CRY1 = 24'b001100_011011_100010_000001,
           CRX2 = 24'b001100_011011_100001_000010,
           CRY2 = 24'b001100_011011_100010_000010,
           CRX3 = 24'b001100_011011_100001_000011,
           CRY3 = 24'b001100_011011_100010_000011,
           CLRR = 24'b001100_010101_011011_011011,
           CLRG = 24'b001100_010101_011011_010000,
           CLRB = 24'b001100_010101_011011_001011,

           PIXL = 24'b011001_010010_100001_010101,
           ASCI = 24'b001010_011100_001100_010010,
           TRIG = 24'b011101_011011_010010_010000,

           LIT  = 24'b000000_010101_010010_011101,
           STRL = 24'b011100_011101_011011_010101,
           ENDL = 24'b001110_010111_001101_010101,
           SYMB = 24'b011100_100010_010110_001011,

           END  = 24'b000000_001110_010111_001101,
           RST  = 24'b000000_011011_011100_011101,
           WRST = 24'b100000_011011_011100_011101,
           NRST = 24'b010111_011011_011100_011101;

reg [CMD_SIZE - 1 : 0] cmd_mem [0 : CMD_MEM_SIZE - 1];
reg [CMD_SIZE - 1 : 0] cmd;          // Current command
reg [ADDR_CMD_MEM_SIZE - 1 : 0] pc;  // Program counter
reg [LIT_SIZE - 1 : 0] res;          // Result register
reg [2:0] stage_counter;

reg [1:0] current_error;

wire [COP_SIZE - 1 : 0] cop = cmd [CMD_SIZE - 1 -: COP_SIZE];
wire [LIT_SIZE - 1 : 0] literal =  cmd [CMD_SIZE - 1 - COP_SIZE -: LIT_SIZE];

initial begin
    cmd <= 0;
    res <= 0;
    stage_counter <= 0;
    pc <= 0;

    draw_symb     <= 0;
    endline       <= 0;
    write_char_en <= 0;

    x1_coord <= 0;
    y1_coord <= 0;
    x2_coord <= 0;
    y2_coord <= 0;
    x3_coord <= 0;
    y3_coord <= 0;

    string_len    <= 0;
    litera        <= 0;
    command_flag  <= 0;
    CPU_busy      <= 0;

    vgaRed   <= 0;
    vgaGreen <= 0;
    vgaBlue  <= 0;
    $readmemb("CPU_mem.mem", cmd_mem);
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cmd <= 0;
        res <= 0;
        stage_counter <= 0;
        pc <= 0;

        draw_symb     <= 0;
        endline       <= 0;
        write_char_en <= 0;

        x1_coord <= 0;
        y1_coord <= 0;
        x2_coord <= 0;
        y2_coord <= 0;
        x3_coord <= 0;
        y3_coord <= 0;

        string_len   <= 0;
        litera       <= 0;
        command_flag <= 0;
        CPU_busy     <= 0;

        vgaRed   <= 0;
        vgaGreen <= 0;
        vgaBlue  <= 0;
    end else begin
        if (stage_counter == 0) begin
            if (draw_symb) draw_symb <= 0;
            if (endline) endline <= 0;
            if (write_char_en) write_char_en <= 0;
            
            case (cop)
                WAIT:
                begin
                    if (valid_in)
                        if (error) begin
                            current_error <= error;
                            cmd <= WRST;
                        end else cmd <= extern_command;
                        CPU_busy <= 1;
                    end else CPU_busy <= 0;
                end
                WRST:
                begin
                    cmd <= cmd_mem[pc];
                    CPU_busy <= 1;
                end
                default:
                    begin
                        if (valid_in) begin
                           if (error) begin
                                current_error <= error;
                                cmd <= WRST;
                            end
                        end else begin
                            if (error) cmd <= WRST;
                            else cmd <= cmd_mem[pc];
                            pc <= pc + 1;
                        end
                        CPU_busy <= 1;
                        stage_counter <= 1;
                    end
            endcase
        end
        
        if (stage_counter == 1) begin
            case (cop)
                WRST:
                begin
                    case (current_error)
                        2'b01: //pc <= ???;  // Jump to wait reset sequence
                        2'b10: //pc <= ???;  // Jump to wait reset sequence
                        2'b11: //pc <= ???;  // Jump to wait reset sequence
                        default : /* default */;
                    endcase
                end
                ENDL: pc <= ???;// Jump to draw "Input PARAM" sequence
                ASCI: pc <= ???;// Jump to draw "Input SLEN NUM" sequence
                SLEN: string_len <= literal[4:0];
                CRX1: x1_coord <= literal;
                CRY1: y1_coord <= literal;
                CRX2: x2_coord <= literal;
                CRY2: y2_coord <= literal;
                CRX3: x3_coord <= literal;
                CRY3: y3_coord <= literal;
                CLRR: vgaRed   <= literal;
                CLRG: vgaGreen <= literal;
                CLRB: vgaBlue  <= literal;
                LIT:  litera   <= literal;
                SYMB: litera   <= literal;
                PIXL: command_flag <= 1;
                ASCI: command_flag <= 2;
                TRIG: command_flag <= 3;
                WRST:
            endcase
            stage_counter <= 2;
        end
        
        if (stage_counter == 2) begin
            case (cop)
                SYMB:
                begin
                    draw_symb <= 1;
                end
                ENDL:
                begin
                    endline <= 1;
                end
                LIT:
                begin
                    draw_symb <= 1;
                    write_char_en <= 1;
                end
            endcase
            stage_counter <= 0;
        end
    end
end

endmodule