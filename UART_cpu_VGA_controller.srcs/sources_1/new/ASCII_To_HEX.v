`timescale 1ns / 1ps

module ASCII_To_HEX (
    input  wire [7:0] ascii_in,
    output reg  [5:0] hex_out  // 6 бит для 36 значений
);

always @(*)
begin
    case (ascii_in)
        // Цифры 0-9
        8'h30: hex_out = 6'd0;
        8'h31: hex_out = 6'd1;
        8'h32: hex_out = 6'd2;
        8'h33: hex_out = 6'd3;
        8'h34: hex_out = 6'd4;
        8'h35: hex_out = 6'd5;
        8'h36: hex_out = 6'd6;
        8'h37: hex_out = 6'd7;
        8'h38: hex_out = 6'd8;
        8'h39: hex_out = 6'd9;
               
        // Заглавные буквы A-Z
        8'h41: hex_out = 6'd10;   //A
        8'h42: hex_out = 6'd11;   //B
        8'h43: hex_out = 6'd12;   //C
        8'h44: hex_out = 6'd13;   //D
        8'h45: hex_out = 6'd14;   //E
        8'h46: hex_out = 6'd15;   //F
        8'h47: hex_out = 6'd16;   //G
        8'h48: hex_out = 6'd17;   //H
        8'h49: hex_out = 6'd18;   //I
        8'h4A: hex_out = 6'd19;   //J
        8'h4B: hex_out = 6'd20;   //K
        8'h4C: hex_out = 6'd21;   //L
        8'h4D: hex_out = 6'd22;   //M
        8'h4E: hex_out = 6'd23;   //N
        8'h4F: hex_out = 6'd24;   //O
        8'h50: hex_out = 6'd25;   //P
        8'h51: hex_out = 6'd26;   //Q
        8'h52: hex_out = 6'd27;   //R
        8'h53: hex_out = 6'd28;   //S
        8'h54: hex_out = 6'd29;   //T
        8'h55: hex_out = 6'd30;   //U
        8'h56: hex_out = 6'd31;   //V
        8'h57: hex_out = 6'd32;   //W
        8'h58: hex_out = 6'd33;   //X
        8'h59: hex_out = 6'd34;   //Y
        8'h5A: hex_out = 6'd35;   //Z
               
        // Строчные буквы a-z
        8'h61: hex_out = 6'd10;   //A
        8'h62: hex_out = 6'd11;   //B
        8'h63: hex_out = 6'd12;   //C
        8'h64: hex_out = 6'd13;   //D
        8'h65: hex_out = 6'd14;   //E
        8'h66: hex_out = 6'd15;   //F
        8'h67: hex_out = 6'd16;   //G
        8'h68: hex_out = 6'd17;   //H
        8'h69: hex_out = 6'd18;   //I
        8'h6A: hex_out = 6'd19;   //J
        8'h6B: hex_out = 6'd20;   //J
        8'h6C: hex_out = 6'd21;   //L
        8'h6D: hex_out = 6'd22;   //M
        8'h6E: hex_out = 6'd23;   //N
        8'h6F: hex_out = 6'd24;   //O
        8'h70: hex_out = 6'd25;   //P
        8'h71: hex_out = 6'd26;   //Q
        8'h72: hex_out = 6'd27;   //R
        8'h73: hex_out = 6'd28;   //S
        8'h74: hex_out = 6'd29;   //T
        8'h75: hex_out = 6'd30;   //U
        8'h76: hex_out = 6'd31;   //V
        8'h77: hex_out = 6'd32;   //W
        8'h78: hex_out = 6'd33;   //X
        8'h79: hex_out = 6'd34;   //Y
        8'h7A: hex_out = 6'd35;   //Z

        // Неизвестный символ
        default: hex_out = 6'd0;
    endcase
end

endmodule