`timescale 1ns / 1ps

module VGA_Manager_tb;

    // Входные сигналы для тестируемого модуля
    reg clk;
    reg reset;
    reg cpu_cmd_ready;
    reg [2:0] cpu_command;
    reg usr_symb_rdy;
    reg [5:0] usr_symb;
    reg cpu_char_rdy;
    reg write_char_en;
    reg [5:0] sys_char;
    reg [11:0] color;
    reg [4:0] sys_string_len;
    reg [4:0] user_string_len;
    reg [9:0] x1_coord, y1_coord;
    reg [9:0] x2_coord, y2_coord;
    reg [9:0] x3_coord, y3_coord;

    // Выходные сигналы
    wire [18:0] vram_address;
    wire VGA_busy;
    wire write_enable;
    wire [11:0] current_color;

    // Параметры для сверки адресации (соответствуют WIDTH = 640)
    localparam WIDTH = 640;

    // Инстанцируем тестируемый модуль (UUT)
    VGA_Manager #(
        .WIDTH(WIDTH),
        .HEIGHT(480)
    ) uut (
        .clk(clk),
        .reset(reset),
        .cpu_cmd_ready(cpu_cmd_ready),
        .cpu_command(cpu_command),
        .usr_symb_rdy(usr_symb_rdy),
        .usr_symb(usr_symb),
        .cpu_char_rdy(cpu_char_rdy),
        .write_char_en(write_char_en),
        .sys_char(sys_char),
        .color(color),
        .sys_string_len(sys_string_len),
        .user_string_len(user_string_len),
        .x1_coord(x1_coord), .y1_coord(y1_coord),
        .x2_coord(x2_coord), .y2_coord(y2_coord),
        .x3_coord(x3_coord), .y3_coord(y3_coord),
        .vram_address(vram_address),
        .VGA_busy(VGA_busy),
        .write_enable(write_enable),
        .current_color(current_color)
    );

    // Генератор тактовой частоты (50 МГц, период 20 нс)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Основной сценарий тестирования
    initial begin
        // --- 1. Инициализация входов ---
        reset = 1;
        cpu_cmd_ready = 0;
        cpu_command = 3'b0;
        usr_symb_rdy = 0;
        usr_symb = 6'b0;
        cpu_char_rdy = 0;
        write_char_en = 0;
        sys_char = 6'b0;
        color = 12'hFFF; // Белый по умолчанию
        sys_string_len = 5'd3;   // Имитируем строку из 3-х символов
        user_string_len = 5'd0;
        x1_coord = 10; y1_coord = 20; // Точка для PIXL
        x2_coord = 0;  y2_coord = 0;
        x3_coord = 0;  y3_coord = 0;

        #40;
        reset = 0; // Снимаем сброс
        #20;

        // --- 2. Тест: Накопление символов системной строки ---
        $display("[TB] --- Stage 1: Filling System String Buffer ---");
        
        // Посылаем символ 'I' (код 18)
        sys_char = 6'd18; cpu_char_rdy = 1; #20;
        // Посылаем символ 'N' (код 23)
        sys_char = 6'd23; cpu_char_rdy = 1; #20;
        // Посылаем символ 'P' (код 25)
        sys_char = 6'd25; cpu_char_rdy = 1; #20;
        
        cpu_char_rdy = 0; sys_char = 6'b0;
        #40;

        // --- 3. Тест: Запуск отрисовки накопленной строки (CSTR) ---
        $display("[TB] --- Stage 2: Executing CSTR (Draw String) ---");
        // Задаем начальные координаты каретки, имитируя предыдущие команды процессора
        uut.x_coord = 10;
        uut.y_coord = 15;
        
        cpu_command = 3'd4; cpu_cmd_ready = 1; #20; // Импульс команды CSTR
        cpu_cmd_ready = 0;
        
        // Мониторим переход автомата в состояние DRAW_CPU_STRING и подъем VGA_busy
        #20;
        if (VGA_busy) 
            $display("[TB] Success: VGA is busy rendering CPU string.");
        else 
            $display("[TB] Error: VGA ignored CSTR command!");

        // Даем автомату время покрутиться в циклах генерации пикселей букв
        // 3 символа * 12 строк * 9 пикселей = примерно 324 такта. Ждем 7000 нс.
        #7000; 

        // --- 4. Тест: Запись типа фигуры (PIXL) и запуск рендера кадра (DRAW) ---
        $display("[TB] --- Stage 3: Executing PIXL configuration then DRAW ---");
        
        // Шаг А: Передаем тип фигуры PIXL (3'd1)
        cpu_command = 3'd1; cpu_cmd_ready = 1; #20;
        cpu_cmd_ready = 0;
        #4500000; // Ждем завершения очистки кадра (640*480 тактов)

        // Ждем возврата в режим ожидания команд
        wait(VGA_busy == 0);
        #40;

        $display("[TB] --- Module Testing Completed ---");
        $finish;
    end

    // Автоматический мониторинг важных событий симуляции в консоли Vivado
    initial begin
        $monitor("Time=%0dns | State=%0d | VGA_busy=%b | VRAM_Addr=%0d | WE=%b | Color=%h", 
                 $time, uut.state, VGA_busy, vram_address, write_enable, current_color);
    end

endmodule