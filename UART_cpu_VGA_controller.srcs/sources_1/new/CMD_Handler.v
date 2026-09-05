module CMD_Handler #(
	parameter DIGIT_RANK = 6,
	parameter CMD_COUNT = 45,
	parameter LIT_SIZE = 10,
	parameter CMD_SIZE  = $clog2(CMD_COUNT),
	parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
	input clk,
	input rst_n,

	input [5:0] symbol,
	input symb_ready,

	input CPU_ready,
	input end_command,
    
	output [BUS_WIDTH-1:0] cpu_command,
	output command_ready
);

reg [41:0] RES_CMD;

wire Translator_busy;
reg button_pending, end_command_pending;
reg start_tx_pulse;

reg [1:0] cmd_code;

localparam STATES = 23;
localparam ST_IDLE            = 0  ,
           PI                 = 1  ,
           PIX                = 2  ,
           ST_PIXL               = 3  ,
           AS                 = 4  ,
           ASC                = 5  ,
           ST_ASCI               = 6  ,
           TR                 = 7  ,
           TRI                = 8  ,
           ST_TRIG               = 9  ,
           INPUT_GREEN_CLR    = 10 ,
           INPUT_RED_CLR      = 11 ,
           INPUT_BLUE_CLR     = 12 ,
           INPUT_X1_COORD     = 13 ,
           INPUT_Y1_COORD     = 14 ,
           INPUT_X2_COORD     = 15 ,
           INPUT_Y2_COORD     = 16 ,
           INPUT_X3_COORD     = 17 ,
           INPUT_Y3_COORD     = 18 ,
           INPUT_STRING_LEN   = 19 ,
           INPUT_STRING       = 20 ,
           WAIT_CPU_EXECUTION = 21 ,
           ST_RESET           = 22 ;

reg [$clog2(STATES) - 1 : 0] state;

// Кодирование 4-буквенных команд
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

CMD_Translator #(
	.DIGIT_RANK (DIGIT_RANK),
	.CMD_COUNT  (CMD_COUNT),
	.LIT_SIZE   (LIT_SIZE)
) translator (
	.clk			  (clk),
	.rst_n			  (rst_n),

	.UART_command     (RES_CMD),
	.end_command 	  (start_tx_pulse),

    .CPU_ready        (CPU_ready  ),
	.cpu_command	  (cpu_command),
	.command_ready 	  (command_ready),

	.Translator_busy  (Translator_busy)
);

initial begin
    state <= ST_IDLE;
    RES_CMD <= 0;
    button_pending <= 0;
    end_command_pending <= 0;
    start_tx_pulse <= 0;
    cmd_code <= 0;
end

always @(posedge clk or posedge rst_n) begin
	if(rst_n) begin
        state <= ST_IDLE;
        RES_CMD <= 0;
        button_pending <= 0;
        end_command_pending <= 0;
        start_tx_pulse <= 0;
        cmd_code <= 0;
	end else begin
        if (end_command) begin
            end_command_pending <= 1'b1; 
        end

        if (symb_ready) begin
            button_pending <= 1'b1; 
        end
        
        if (RES_CMD[41:18] != 24'd0 && !start_tx_pulse && !Translator_busy) begin
            start_tx_pulse <= 1'b1;
        end 
        
        else if (start_tx_pulse && Translator_busy) begin
            start_tx_pulse      <= 1'b0;
            end_command_pending <= 1'b0;
            RES_CMD             <= 42'd0;
        end

        case(state)
            ST_IDLE: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    case (symbol)
                    	6'd25: begin      // P
                    		state <= PI;
                    	end
                    	6'd10: begin      // A
                    		state <= AS;
                    	end
                    	6'd29: begin      // T
                    		state <= TR;
                    	end
                    	default : begin
                            RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                            state   <= ST_RESET;
                        end
                    endcase
            	end
            end

            PI: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd18) begin      // I
                        state <= PIX;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            PIX: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd33) begin      // X
                        state <= ST_PIXL;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            ST_PIXL: begin
                if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd21) begin
                        RES_CMD <= { PIXL, {18{1'b0}} };
                        cmd_code <= 1;
                        state   <= INPUT_GREEN_CLR;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
                end
            end

            AS: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd28) begin      // S
                        state <= ASC;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            ASC: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd12) begin      // C
                        state <= ST_ASCI;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            ST_ASCI: begin
                if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd18) begin
                        RES_CMD <= { ASCI, {18{1'b0}} };
                        cmd_code <= 2;
                        state   <= INPUT_GREEN_CLR;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
                end
            end

            TR: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd27) begin      // R
                        state <= TRI;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            TRI: begin
            	if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd18) begin      // I
                        state <= ST_TRIG;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
            	end
            end

            ST_TRIG: begin
                if (button_pending && !Translator_busy) begin
                    button_pending <= 1'b0;
                    if (symbol == 6'd16) begin
                        RES_CMD <= { TRIG, {18{1'b0}} };
                        cmd_code <= 3;
                        state   <= INPUT_GREEN_CLR;
                    end else begin
                        RES_CMD <= { EROR, {16{1'b0}}, 2'd1 };
                        state   <= ST_RESET;
                    end
                end
            end

            INPUT_GREEN_CLR: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CLRG, RES_CMD[17:0] }; 
                    state   <= INPUT_RED_CLR;
                end
            end

            INPUT_RED_CLR: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CLRR, RES_CMD[17:0] }; 
                    state   <= INPUT_BLUE_CLR;
                end
            end

            INPUT_BLUE_CLR: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CLRB, RES_CMD[17:0] }; 
                    state   <= INPUT_X1_COORD;
                end
            end

            INPUT_X1_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRX1, RES_CMD[17:0] }; 
                    state   <= INPUT_Y1_COORD;
                end
            end

            INPUT_Y1_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRY1, RES_CMD[17:0] };
                    case (cmd_code)
                        1: begin
                            state <= WAIT_CPU_EXECUTION;
                        end
                        2: begin
                            state <= INPUT_STRING_LEN;
                        end
                        3: begin
                            state <= INPUT_X2_COORD;
                        end
                    endcase
                end
            end

            INPUT_X2_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRX2, RES_CMD[17:0] }; 
                    state   <= INPUT_Y2_COORD;
                end
            end

            INPUT_Y2_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRY2, RES_CMD[17:0] }; 
                    state   <= INPUT_X3_COORD;
                end
            end

            INPUT_X3_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRX3, RES_CMD[17:0] }; 
                    state   <= INPUT_Y3_COORD;
                end
            end

            INPUT_Y3_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD        <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { CRY3, RES_CMD[17:0] }; 
                    state   <= WAIT_CPU_EXECUTION;
                end
            end

            INPUT_STRING_LEN: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[35:0], symbol };
                    button_pending <= 1'b0;
                end

                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { SLEN, RES_CMD[17:0] };
                    state <= INPUT_STRING;
                end
            end

            INPUT_STRING: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { CHAR, {12{1'b0}}, symbol };
                    button_pending <= 1'b0;
                end

                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { ENDL, {18{1'b0}} };
                    state <= WAIT_CPU_EXECUTION;
                end
            end

            WAIT_CPU_EXECUTION: begin
                if (!Translator_busy) begin
                    state <= ST_RESET;
                end
            end

            ST_RESET: begin
                end_command_pending <= 0;
                RES_CMD <= 0;
                state <= ST_IDLE;
            end
        endcase
    end
end
endmodule