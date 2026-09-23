`timescale 1ns / 1ps

module UART_Input_Manager #
(
	CLOCK_RATE = 100_000_000,      // ������� ���� XC7A100T-1CSG324C ��������� Artix-7 (� ��)
    BAUD_RATE = 480000,		       // �������� �������� ������ �� UART (� ���)
	DIGIT_RANK = 6                 // ����������� �������� ������
)
(
	input clk, 					   // ������������
	input reset,                   // ������ ������
	input RsRx,
	
	output reg [DIGIT_RANK - 1 : 0] out,      // �������� �������������� DIGIT_RANK-��������� �����
	output reg ready_out,					  // ������ � ���, ��� �������������� ����� ������������
	output reg end_command
);

// UART_RX-�����������
wire UART_RX_Ready_Out;		  // ������ � ���, ��� UART_RX ��� ������ ���� ����� ������
wire [7:0] UART_RX_Data_Out;  // �������� ����� ������ ��������� �� ������ UART_RX

localparam RX_DATA_SIZE = 8;

// �������, ������������ ������ ������ �� UART
UART_RX #(.CLOCK_RATE(CLOCK_RATE), .BAUD_RATE(BAUD_RATE)) uart_rx
(
	.clk(clk), 								// ����: ������������
	.rx(RsRx), 								// ���� ��� ����� ���������� ���� ������ � UART
	.UART_RX_Ready_Out(UART_RX_Ready_Out),  // �����: ������ � ���, ��� ����������� ����� �������� ������
	.UART_RX_Data_Out(UART_RX_Data_Out)		// �����: �������������� ����� �� ������� ������
);

localparam FIFO_MEM_SIZE = 2;
localparam FIFO_DATA_SIZE = RX_DATA_SIZE;

wire FIFO_write_mode;		// ������� ������� ������ ������ � ����� FIFO
assign FIFO_write_mode = UART_RX_Ready_Out;
wire [FIFO_DATA_SIZE-1:0] FIFO_data_in;    // ������� ���� ������ FIFO 
assign FIFO_data_in = UART_RX_Data_Out;

reg  FIFO_read_mode;         // ������� ������� ������ ������ �� ������ FIFO
wire [FIFO_DATA_SIZE-1:0] FIFO_data_out;    // �������� ���� ������ FIFO

wire FIFO_empty;			// ������ � ������ FIFO � ���, ��� ����� ����
wire FIFO_full; 			// ������ � ������ FIFO � ���, ��� ����� �����
wire FIFO_valid;            // ������ � ������ FIFO � ���, ��� �������� �� ������ �������

// ����� FIFO
SimpleFIFO #(
	.MEM_SIZE(FIFO_MEM_SIZE),	
    .DATA_SIZE(FIFO_DATA_SIZE)
) 
simpleFIFO(
    .reset(reset),
    .clk(clk),
    .enable(1'b1),
    .read_mode(FIFO_read_mode),
    .write_mode(FIFO_write_mode),
    .data_in(FIFO_data_in),
    .data_out(FIFO_data_out),
    .full(FIFO_full),
    .empty(FIFO_empty),
    .valid(FIFO_valid)
);

// ����������, ������������� ASCII ��� � ������������ RX_DATA_SIZE � DIGIT_RANK-��������� �����
localparam ASCII_SIZE = RX_DATA_SIZE;
wire [ASCII_SIZE-1:0] ASCII_in = FIFO_data_out;
wire [DIGIT_RANK-1:0] HEX_out;
ASCII_To_HEX a1(ASCII_in, HEX_out);

// �������
// reg state; // ������� �������� ��������� ��������
localparam RESET = 0, READ_FIFO = 1;
localparam CR = 8'h0D;

// ��������� ������������� ��������
initial 
begin
    end_command <= 0;
    FIFO_read_mode <= 1;
	out <= 0;
	ready_out <= 0;
end

// ���� ��������� �������� ���������
always@(posedge clk) begin
    if (FIFO_valid) begin
        if (FIFO_data_out == CR) begin
            end_command <= 1'b1;
        end else if (FIFO_data_out == 8'h0A) begin
            end_command <= 1'b0;
            ready_out <= 1'b0;
        end else begin
            ready_out <= 1'b1;
            out <= HEX_out;
            end_command <= 1'b0;
        end
    end else begin
        end_command <= 1'b0;
        ready_out <= 1'b0;
    end      
end

endmodule