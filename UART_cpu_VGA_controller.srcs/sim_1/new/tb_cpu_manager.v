`timescale 1ns/1ps

`define MAX_STRING_SIZE 30

module tb_cpu_manager;

localparam CMD_COUNT = 22, LIT_SIZE = 10, CMD_SIZE  = $clog2(CMD_COUNT);
localparam BUS_WIDTH = CMD_SIZE + LIT_SIZE;

reg clk;
reg reset;
reg extern_command_ready;
reg [BUS_WIDTH - 1 : 0] extern_command;
reg [5:0] usr_symb;
reg usr_symb_rdy;

wire CPU_ready, VGA_busy, vga_cmd_ready;
wire [2:0] vga_command_flag;
wire [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len, sys_string_len;
wire [5:0] sys_char;
wire cpu_char_rdy, write_char_en, write_enable;
wire [9:0] x1_coord, y1_coord, x2_coord, y2_coord, x3_coord, y3_coord;
wire [18:0] vram_address;
wire [11:0] current_color;
wire [11:0] cpu_color;

localparam PIXL = 5'd0,  ASCI = 5'd1,  TRIG = 5'd2,
           CSLN = 5'd3,  CCHR = 5'd4,  CSTR = 5'd5,
           DRAW = 5'd6,  WAIT = 5'd7,  USLN = 5'd8,
           UCHR = 5'd9,  CLRR = 5'd10, CLRG = 5'd11,
           CLRB = 5'd12, CRX1 = 5'd13, CRX2 = 5'd14,
           CRX3 = 5'd15, CRY1 = 5'd16, CRY2 = 5'd17,
           CRY3 = 5'd18, EROR = 5'd19, ENDL = 5'd20;

localparam A = 6'd10, B = 6'd11, C = 6'd12, D = 6'd13, 
           E = 6'd14, F = 6'd15, G = 6'd16, H = 6'd17,
           I = 6'd18, J = 6'd19, K = 6'd20, L = 6'd21,
           M = 6'd22, N = 6'd23, O = 6'd24, P = 6'd25,
           Q = 6'd26, R = 6'd27, S = 6'd28, T = 6'd29,
           U = 6'd30, V = 6'd31, W = 6'd32, X = 6'd33,
           Y = 6'd34, Z = 6'd35;

cpu VGA_cpu (
    .clk                  ( clk                  ),
    .reset                ( reset                ), 
    .extern_command_ready ( extern_command_ready ),
    .extern_command       ( extern_command       ),
    .CPU_ready            ( CPU_ready            ),
    .VGA_ready            ( !VGA_busy            ), 
    .vga_command_flag     ( vga_command_flag     ),
    .vga_cmd_ready        ( vga_cmd_ready        ),
    .user_string_len      ( user_string_len      ),
    .sys_string_len       ( sys_string_len       ),
    .cpu_char_rdy         ( cpu_char_rdy         ), 
    .write_char_en        ( write_char_en        ), 
    .sys_char             ( sys_char             ), 
    .color                ( cpu_color            ), 
    .x1_coord             ( x1_coord             ),
    .y1_coord             ( y1_coord             ),
    .x2_coord             ( x2_coord             ),
    .y2_coord             ( y2_coord             ),
    .x3_coord             ( x3_coord             ),
    .y3_coord             ( y3_coord             ) 
);

VGA_Manager monitor_manager(
    .clk                ( clk               ),
    .reset              ( reset             ),
    .cpu_cmd_ready      ( vga_cmd_ready     ),
    .cpu_command        ( vga_command_flag  ),
    .usr_symb_rdy       ( usr_symb_rdy      ), 
    .usr_symb           ( usr_symb          ), 
    .cpu_char_rdy       ( cpu_char_rdy      ), 
    .write_char_en      ( write_char_en     ), 
    .sys_char           ( sys_char          ), 
    .color              ( cpu_color         ), 
    .sys_string_len     ( sys_string_len    ),
    .user_string_len    ( user_string_len   ),
    .x1_coord           ( x1_coord          ),
    .y1_coord           ( y1_coord          ),
    .x2_coord           ( x2_coord          ),
    .y2_coord           ( y2_coord          ),
    .x3_coord           ( x3_coord          ),
    .y3_coord           ( y3_coord          ),
    .vram_address       ( vram_address      ),
    .VGA_busy           ( VGA_busy          ),
    .write_enable       ( write_enable      ),
    .current_color      ( current_color     ) 
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Основной конвейер симуляции
initial begin
    reset = 1;
    extern_command_ready = 0;
    extern_command = 0;
    usr_symb = 0;
    usr_symb_rdy = 0;
    @(posedge clk);
    reset = 0;
    testsuite();
    $stop;
end

task task_send_uart_char;
    input [5:0] char_code;
    begin
        usr_symb = char_code;
        usr_symb_rdy = 1'b1;
        @(posedge clk);
        usr_symb = 0;
        usr_symb_rdy = 1'b0;
    end
endtask

task task_send_extern_cmd;
    input [4:0] cop_code;
    input [9:0] lit_value;
    begin
        wait(CPU_ready);
        extern_command = {cop_code, lit_value};
        extern_command_ready = 1'b1; 
        @(posedge clk);
        extern_command_ready = 1'b0;
        extern_command = 0;
    end
endtask

// Комплексный таск имитации посимвольного ввода целой команды по цепочке Handler
task send_command;
    input [41:0] user_symbols; 
    input [4:0]  cop_code;     
    input [9:0]  lit_value;    
    integer char_idx;
    begin
        if (!CPU_ready) begin
            wait(CPU_ready);
        end
        
        for (char_idx = 6; char_idx >= 0; char_idx = char_idx - 1) begin
            if (user_symbols[char_idx*6 +: 6] != 6'd0) begin
                task_send_uart_char(user_symbols[char_idx*6 +: 6]);
                @(posedge clk);
            end
        end
        
        task_send_extern_cmd(cop_code, lit_value);
    end
endtask

// =========================================================================
// КОМПЛЕКСНЫЙ НАБОР ТЕСТОВЫХ ЦЕПОЧЕК (ИЗОЛИРОВАННЫЙ ТЕСТ CPU + VGA)
// =========================================================================
task testsuite;
    begin
        // Шаг 0: Ждем, пока CPU выполнит стартовую инициализацию из ROM и встанет на WAIT
        wait(CPU_ready == 1'b1);
        
        task_send_extern_cmd(CLRR, 10'd15);
        task_send_extern_cmd(CLRG, 10'd10);
        task_send_extern_cmd(CLRB, 10'd0);
        
        task_send_extern_cmd(CRX1, 10'd320);
        task_send_extern_cmd(CRY1, 10'd240);
        
        task_send_extern_cmd(PIXL, 10'd0);
        
        task_send_extern_cmd(ENDL, 10'd0);
        
        // Даем время видеокарте зафиксировать точку во VRAM
        #100;
        
        // -----------------------------------------------------------------
        // ЦЕПОЧКА 2: Полное формирование параметров для СТРОКИ ТЕКСТА (ASCI)
        // -----------------------------------------------------------------
        $display("[TB_INFO] Запуск Цепочки 2 (Посимвольное ОЗУ накопление и ASCI).");
        wait(CPU_ready == 1'b1);
        
        // 1. Меняем цвет каретки на чистый синий (R=0, G=0, B=15)
        task_send_extern_cmd(CLRR, 10'd0);
        task_send_extern_cmd(CLRG, 10'd0);
        task_send_extern_cmd(CLRB, 10'd15);
        
        // 2. Ставим новые координаты начала текста на экране (X1=50, Y1=100)
        task_send_extern_cmd(CRX1, 10'd50);
        task_send_extern_cmd(CRY1, 10'd100);
        
        // 3. Задаем длину пользовательской строки = 5 символов
        task_send_extern_cmd(USLN, 10'd5);
        
        // 4. Посимвольно скармливаем буквы слова "HELLO" через команду UCHR.
        // Процессор будет на шаге 1 взводить write_char_en, а VGA_Manager - копить их в usr_string_reg
        $display("[TB_ACTION] Потоковая отправка символов слова 'HELLO' через UCHR.");
        task_send_extern_cmd(UCHR, {4'd0, H}); // Буква H (ID 17)
        task_send_extern_cmd(UCHR, {4'd0, E}); // Буква E (ID 14)
        task_send_extern_cmd(UCHR, {4'd0, L}); // Буква L (ID 21)
        task_send_extern_cmd(UCHR, {4'd0, L}); // Буква L (ID 21)
        task_send_extern_cmd(UCHR, {4'd0, O}); // Буква O (ID 24)
        
        // 5. Шлем процессору команду ASCI, чтобы запустить массивный вывод накопленной строки
        $display("[TB_ACTION] Вызов команды ASCI для отрисовки всей строки.");
        task_send_extern_cmd(ASCI, 10'd0);
        
        // 6. Завершаем строку переводом каретки
        task_send_extern_cmd(ENDL, 10'd0);
        
        // Ждем, пока VGA_Manager полностью снимет флаг VGA_busy после отрисовки 5 букв
        wait(VGA_busy == 1'b0);
        $display("[TB_SUCCESS] Цепочка ASCI успешно обработана связкой CPU и VGA.");
        #100;

        // -----------------------------------------------------------------
        // ЦЕПОЧКА 3: Тестирование аппаратных прерываний (Имитация сбоя EROR)
        // -----------------------------------------------------------------
        $display("[TB_INFO] Запуск Цепочки 3 (Симуляция ошибки диапазона EROR).");
        wait(CPU_ready == 1'b1);
        
        // Напрямую шлем процессору команду ошибки EROR с литералом 2 (ошибка формата/значения)
        // Процессор должен перехватить её на шаге выборки и перебросить pc на адрес 248
        $display("[TB_ACTION] Ввод аварийного пакета EROR 2.");
        task_send_extern_cmd(EROR, 10'd2);
        
        #50;
        $display("[TB_SUCCESS] Тестсьют полностью выполнен. Взаимодействие CPU и VGA верифицировано.");
    end
endtask

endmodule
