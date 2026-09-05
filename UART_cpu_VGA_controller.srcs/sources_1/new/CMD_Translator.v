module CMD_Translator #(
	parameter DIGIT_RANK = 6,
	parameter CMD_COUNT = 45,
	parameter LIT_SIZE = 10,
	parameter CMD_SIZE  = $clog2(CMD_COUNT),
	parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
	input  clk,
	input  rst_n,

	input  [41:0] UART_command,
	input  end_command        ,

	input  CPU_ready          ,
	output [BUS_WIDTH - 1 : 0] cpu_command,
	output reg command_ready  ,

	output reg Translator_busy
);

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

reg [41:0] command;
reg [CMD_SIZE-1:0] cmd_code;
reg [LIT_SIZE-1:0] literal;

assign cpu_command = { cmd_code, literal };

localparam ST_IDLE           = 2'd0,
           ST_TRANSLATE_CMD  = 2'd1,
           ST_CHECK_COMMAND  = 2'd2,
           SEND_COMMAND      = 2'd3;

reg [1:0] state_r;
reg [1:0] j;

initial begin
    state_r         <= ST_IDLE;
    j               <= 0;
    command_ready   <= 0;
    Translator_busy <= 0;
    command         <= 0;
    cmd_code        <= 0;
    literal         <= 0;
end

always @(posedge clk or posedge rst_n) begin
	if(rst_n) begin
		state_r         <= ST_IDLE;
		j               <= 0;
        command_ready   <= 0;
        Translator_busy <= 0;
        command         <= 0;
        cmd_code        <= 0;
        literal         <= 0;
	end else begin
		case (state_r)
			ST_IDLE: begin
				if (end_command) begin
					Translator_busy <= 1'b1;
                    command         <= UART_command;
                    cmd_code        <= 0;
                    literal         <= 0;
                    state_r         <= ST_TRANSLATE_CMD;
				end
			end

            ST_TRANSLATE_CMD: begin
                if (j == 2'd3) begin
                    j              <= 2'd0;
                    command[33:10] <= command[41:18];
                    state_r        <= ST_CHECK_COMMAND;
                end else begin
                    case (j)
                        2'd0: begin
                            j            <= j + 2'd1;
                        end
                        2'd1: begin
                            command[9:0] <= command[5:0] + ({command[9:6], 3'd0} + {command[9:6], 1'd0});
                            j            <= j + 2'd1;
                        end
                        2'd2: begin
                            command[9:0] <= command[9:0] + ({command[15:12], 6'd0} + {command[15:12], 5'd0} + {command[15:12], 2'd0});
                            j            <= j + 2'd1;
                        end
                        default: j <= 2'd0;
                    endcase
                end
            end

            ST_CHECK_COMMAND: begin
                state_r       <= SEND_COMMAND;
                command_ready <= 1'b1;
                
                case (command[33:10])
                    SLEN:    cmd_code <= 5'd1;
                    CHAR:    cmd_code <= 5'd2;
                    CLRR:    cmd_code <= 5'd3;
                    CLRG:    cmd_code <= 5'd4;
                    CLRB:    cmd_code <= 5'd5;
                    CRX1:    cmd_code <= 5'd6;
                    CRX2:    cmd_code <= 5'd7;
                    CRX3:    cmd_code <= 5'd8;
                    CRY1:    cmd_code <= 5'd9;
                    CRY2:    cmd_code <= 5'd10;
                    CRY3:    cmd_code <= 5'd11;
                    PIXL:    cmd_code <= 5'd12;
                    ASCI:    cmd_code <= 5'd13;
                    TRIG:    cmd_code <= 5'd14;
                    EROR:    cmd_code <= 5'd15;
                    RSTN:    cmd_code <= 5'd16;
                    ENDL:    cmd_code <= 5'd17;
                    default: cmd_code <= 5'd15;
                endcase
                
                case (command[33:10])
                    SLEN, CLRR, CLRG, CLRB: begin
                        if (command[9:0] > 15) begin
                            cmd_code <= 5'd15;
                            literal  <= 10'd2;
                        end else begin
                            literal  <= command[9:0];
                        end
                    end
                    
                    CRX1, CRX2, CRX3: begin
                        if (command[9:0] > 639) begin
                            cmd_code <= 5'd15;
                            literal  <= 10'd3; 
                        end else begin
                            literal  <= command[9:0];
                        end
                    end 
                    
                    CRY1, CRY2, CRY3: begin
                        if (command[9:0] > 479) begin
                            cmd_code <= 5'd15;
                            literal  <= 10'd4;
                        end else begin
                            literal  <= command[9:0];
                        end
                    end
                    
                    PIXL, ASCI, TRIG, RSTN, ENDL: begin
                        if (command[9:0] != 0) begin 
                            cmd_code <= 5'd15;
                            literal  <= 10'd5;
                        end else begin
                            literal  <= command[9:0];
                        end
                    end

                    CHAR: begin
                        literal <= command[9:0];
                    end

                    EROR: begin
                        cmd_code <= 5'd15;
                        literal  <= command[9:0];
                    end

                    default: begin
                        cmd_code <= 5'd15;
                        literal  <= 10'd1;
                    end
                endcase
            end

            SEND_COMMAND: begin
                if (CPU_ready) begin
                    command_ready   <= 1'b0;
                    Translator_busy <= 1'b0;
                    state_r         <= ST_IDLE;
                end
            end
		endcase
	end
end

endmodule