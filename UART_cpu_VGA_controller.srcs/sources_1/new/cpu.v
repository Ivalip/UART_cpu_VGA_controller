`timescale 1ns / 1ps

module cpu #(
    parameter CMD_COUNT = 45,
    parameter LIT_SIZE = 10,
    parameter CMD_SIZE  = $clog2(CMD_COUNT),
    parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
    input clk,
    input rst_n,

    input extern_command_ready,
    input [BUS_WIDTH - 1 : 0] extern_command,
    output reg CPU_ready,

    input VGA_ready,
    output reg endline,
    output reg [2:0] command_flag,
    output reg cmd_ready,
    output reg start_draw,

    output reg [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len,
    output reg [$clog2(`MAX_STRING_SIZE)-1:0] sys_string_len,
    output reg [5:0] char,
    output reg write_char_en,

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

localparam CMD_MEM_SIZE = 32, ////////////////////////// РАСШИРИТЬ //////////////////////////
           ADDR_CMD_MEM_SIZE = $clog2(CMD_MEM_SIZE),
           CMD_SIZE = ??, ////////////////////////// РАСШИРИТЬ //////////////////////////
           LIT_SIZE = 10,
           COP_SIZE = ??; ////////////////////////// РАСШИРИТЬ //////////////////////////

localparam PIXL = 24'b011001_010010_100001_010101, // P(25) I(18) X(33) L(21)
           ASCI = 24'b001010_011100_001100_010010, // A(10) S(28) C(12) I(18)
           TRIG = 24'b011101_011011_010010_010000, // T(29) R(27) I(18) G(16)
           
           SLEN = 24'b011100_010101_001110_010111, // S(28) L(21) E(14) N(23)
           CHAR = 24'b001100_010001_001010_011011, // C(12) H(17) A(10) R(27)
           
           CLRR = 24'b001100_010101_011011_011011, // C(12) L(21) R(27) R(27)
           CLRG = 24'b001100_010101_011011_010000, // C(12) L(21) R(27) G(16)
           CLRB = 24'b001100_010101_011011_001011, // C(12) L(21) R(27) B(11)
           
           CRX1 = 24'b001100_011011_100001_000001, // C(12) R(27) X(33) 1(1)
           CRX2 = 24'b001100_011011_100001_000010, // C(12) R(27) X(33) 2(2)
           CRX3 = 24'b001100_011011_100001_000011, // C(12) R(27) X(33) 3(3)
           
           CRY1 = 24'b001100_011011_100010_000001, // C(12) R(27) Y(34) 1(1)
           CRY2 = 24'b001100_011011_100010_000010, // C(12) R(27) Y(34) 2(2)
           CRY3 = 24'b001100_011011_100010_000011, // C(12) R(27) Y(34) 3(3)
           
           EROR = 24'b001110_011011_011000_011011, // E(14) R(27) O(24) R(27)
           RSTN = 24'b011011_011100_011101_010111, // R(27) S(28) T(29) N(23)
           ENDL = 24'b001110_010111_010100_010101; // E(14) N(23) D(13) L(21)

reg [CMD_SIZE - 1 : 0] cmd_mem [0 : CMD_MEM_SIZE - 1];
reg [CMD_SIZE - 1 : 0] cmd;                 // Current command
// reg [CMD_SIZE - 1 : 0] prev_extern_command; // Previous extern command

reg [ADDR_CMD_MEM_SIZE - 1 : 0] pc;         // Program counter
reg [1:0] stage_counter;

wire [COP_SIZE - 1 : 0] cop = cmd [CMD_SIZE - 1 -: COP_SIZE];
wire [LIT_SIZE - 1 : 0] literal =  cmd [CMD_SIZE - 1 - COP_SIZE -: LIT_SIZE];

initial begin
    CPU_ready <= 0;

    endline       <= 0;

    string_len    <= 0;
    char <= 0;
    write_char_en <= 0;

    vgaX <= 0;
    vgaY <= 0;

    vgaRed   <= 0;
    vgaGreen <= 0;
    vgaBlue  <= 0;

    command_flag  <= 0;
    start_draw <= 0;

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
    if (rst_n) begin
        CPU_ready <= 0;

        endline       <= 0;

        string_len    <= 0;
        char <= 0;
        write_char_en <= 0;

        vgaX <= 0;
        vgaY <= 0;

        vgaRed   <= 0;
        vgaGreen <= 0;
        vgaBlue  <= 0;

        command_flag  <= 0;
        start_draw <= 0;

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
            case (cop)
                DRAW: begin
                    if (VGA_ready) begin
                        start_draw <= 1;
                    end
                end
                EROR: begin
                    case (literal)
                        2'b01: //pc <= ???;  // Jump to wait reset sequence (in cpu_mem.mem) after incorrect cmd
                        2'b10: //pc <= ???;  // Jump to wait reset sequence (in cpu_mem.mem) after incorrect value
                    endcase
                end
                ENDL: begin
                    endline <= 1;
                end
                CHAR: begin
                    char <= literal[5:0];
                    write_char_en <= 1;
                end
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
                PIXL: command_flag <= 1;
                ASCI: command_flag <= 2;
                TRIG: command_flag <= 3;

            endcase
            stage_counter <= 2;
        end
        
        if (stage_counter == 2) begin
            case (cop)
                ENDL: begin
                    endline <= 0;
                    pc <= pc + 1;
                end
                CHAR: begin
                    write_char_en <= 0;
                    pc <= pc + 1;
                end
                DRAW: begin
                    if (!VGA_ready) begin
                        start_draw <= 0;
                        pc <= pc + 1;
                    end
                end
                ENDL, ASCI, TRIG, SLEN, CRX1, CRY1, CRX2, 
                CRY2, CRX3, CRY3, CLRR, CLRG, CLRB, PIXL, 
                WRST: begin
                    pc <= pc + 1;
                end
            endcase
            stage_counter <= 0;
        end
    end
end

endmodule