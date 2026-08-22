module CMD_Handler #(
	parameter DIGIT_RANK = 6,
	parameter CMD_COUNT = 45,
	parameter LIT_SIZE = 10,
	parameter CMD_SIZE  = $clog2(CMD_COUNT),
	parameter BUS_WIDTH = CMD_SIZE + LIT_SIZE
)(
	input clk,
	input rst_n,

	input [5:0] symb,
	input symb_ready,

	input CPU_ready,
	input end_command,
    
	output [BUS_WIDTH-1:0] cpu_command,
	output command_ready
);

reg [47:0] RES_CMD;

wire Translator_busy;
reg button_pending, end_command_pending;

reg error;
reg [1:0] error_code;
reg [1:0] cmd_code;
reg [3:0] param_counter;

localparam STATES = 23;
localparam ST_IDLE            = 0  ,
           PI                 = 1  ,
           PIX                = 2  ,
           PIXL               = 3  ,
           AS                 = 4  ,
           ASC                = 5  ,
           ASCI               = 6  ,
           TR                 = 7  ,
           TRI                = 8  ,
           TRIG               = 9  ,
           ST_FORM_ERROR      = 10 ,
           INPUT_GREEN_CLR    = 11 ,
           INPUT_RED_CLR      = 12 ,
           INPUT_BLUE_CLR     = 13 ,
           INPUT_X1_COORD     = 14 ,
           INPUT_Y1_COORD     = 15 ,
           INPUT_X2_COORD     = 16 ,
           INPUT_Y2_COORD     = 17 ,
           INPUT_X3_COORD     = 18 ,
           INPUT_Y3_COORD     = 19 ,
           INPUT_STRING_LEN   = 20 ,
           INPUT_STRING       = 21 ,
           WAIT_CPU_EXECUTION = 22 ,
           ST_RESET           = 23 ;

reg [$clog2(STATES) - 1 : 0] state;

initial begin
    
end

CMD_Translator command_translator #(
	.DIGIT_RANK (DIGIT_RANK),
	.CMD_COUNT  (CMD_COUNT),
	.LIT_SIZE   (LIT_SIZE)
)(
	.clk			  (clk),
	.rst_n			  (rst_n),

	.UART_command     (RES_CMD),
	.end_command 	  (end_command_pending),

    .CPU_ready        (CPU_ready  ),
	.cpu_command	  (cpu_command),
	.command_ready 	  (command_ready),

	.Translator_busy  (Translator_busy)
);

always @(posedge clk or posedge rst) begin
	if(rst) begin
		<= 0;
	end else begin
        if (symbol_ready) begin
            button_pending <= 1'b1; // Кнопка была нажата
        end

        if (end_command) begin
            end_command_pending <= 1'b1; // Команда завершена
        end

        case(state)
            ST_IDLE: begin
            	if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
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
                            error_code <= 1;
                            state <= ST_FORM_ERROR;
                        end
                    endcase
            	end
            end

            PI: begin
            	if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd18) begin      // I
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= PIX;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
            	end
            end

            PIX: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd33) begin      // X
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= PIXL;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
            end

            PIXL: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd21) begin      // L
                        RES_CMD <= { {6{1'b0}}, RES_CMD[17:0], symbol, {18{1'b0}} };
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    end_command_pending <= 0;
                    cmd_code <= 1;
                    state <= INPUT_GREEN_CLR;
                end
            end

            AS: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd28) begin      // S
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= ASC;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
            end
            ASC: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd12) begin      // C
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= ASCI;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
            end

            ASCI: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd18) begin      // I
                        RES_CMD <= { {6{1'b0}}, RES_CMD[17:0], symbol, {18{1'b0}} };
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    end_command_pending <= 0;
                    cmd_code <= 2;
                    state <= INPUT_STRING_LEN;
                end
            end

            TR: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd27) begin      // R
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= TRI;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
            end

            TRI: begin
                if (button_pending && !Translator_busy) begin
                    if (symbol == 6'd18) begin      // I
                        RES_CMD <= { RES_CMD[41:0], symbol };
                        state <= TRIG;
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
            end

            TRIG: begin
                if (button_pending && !Translator_busy) begin-
                    if (symbol == 6'd16) begin      // G
                        RES_CMD <= { {6{1'b0}}, RES_CMD[17:0], symbol, {18{1'b0}} };
                    end else begin
                        error_code <= 1;
                        state <= ST_FORM_ERROR;
                    end
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    end_command_pending <= 0;
                    cmd_code <= 3;
                    state <= INPUT_X1_COORD;
                end
            end

            ST_FORM_ERROR: begin
                if (!Translator_busy) begin
                    state <= ST_RESET;
                    case (error_code)
                        2'h0: begin
                            RES_CMD <= { {6{1'b0}}, NULL, {16{1'b0}}, error_code };
                            state <= ????????????;
                        end
                        2'h1: begin // Неверная команда
                            RES_CMD <= { {6{1'b0}}, EROR, {16{1'b0}}, error_code };
                            // Придумать для вывода сообщения
                        end
                        2'h2: begin // Неверный параметр
                            RES_CMD <= { {6{1'b0}}, EROR, {16{1'b0}}, error_code };
                        end
                        2'h3: begin
                            RES_CMD <= { {6{1'b0}}, EROR, {16{1'b0}}, error_code };
                        end
                    endcase
                end
            end

            INPUT_GREEN_CLR: begin
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CLRG, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_RED_CLR;
                end
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
            end

            INPUT_RED_CLR: begin
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CLRR, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_BLUE_CLR;
                end
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
            end

            INPUT_BLUE_CLR: begin
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CLRB, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_X1_COORD;
                end
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
            end

            INPUT_X1_COORD: begin
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CRX1, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_Y1_COORD;
                end
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
            end

            INPUT_Y1_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    end_command_pending <= 0;
                    RES_CMD <= { {6{1'b0}}, CRY1, RES_CMD[17:0] };
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
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CRX2, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_Y2_COORD;
                end
            end

            INPUT_Y2_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CRY2, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_X3_COORD;
                end
            end

            INPUT_X3_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CRX3, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_Y3_COORD;
                end
            end

            INPUT_Y3_COORD: begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CRY3, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= WAIT_CPU_EXECUTION;
                end
            end

            INPUT_STRING_LEN:
            begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { RES_CMD[41:0], symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, SLEN, RES_CMD[17:0] };
                    end_command_pending <= 0;
                    state <= INPUT_STRING;
                end
            end

            INPUT_STRING:
            begin
                if (button_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, CHAR, {12{1'b0}}, symbol };
                    button_pending <= 1'b0;
                end
                if (end_command_pending && !Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, ENDL, RES_CMD[17:0] };
                    state <= WAIT_CPU_EXECUTION;
                    end_command_pending <= 0;
                end
            end
            
            WAIT_CPU_EXECUTION:
            begin
                if (!Translator_busy) begin
                    state <= ST_RESET;
                end
            end

            ST_RESET:
            begin
                // ПОДУМАЕМ чуть позже
                if (!Translator_busy) begin
                    RES_CMD <= { {6{1'b0}}, RSTN, {12{1'b0}}, symbol };
                end
                if (error) begin
                    error <= 0;
                end
            end
        endcase
    end
end
endmodule