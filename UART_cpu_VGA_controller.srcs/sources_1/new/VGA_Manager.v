`timescale 1ns / 1ps

`define CHAR_WIDTH  9           // Ширина буквы (в пикселях)
`define CHAR_HEIGHT 12          // Высота буквы (в пикселях)

`define ALPHABET_SIZE   25      // Размер алфавита

`define MAX_STRING_SIZE 15      // Максимальный размер строки (в количестве символов)

module VGA_Manager
(
    input  clk                                      ,
    input  reset                                    ,
    /*------------------------------------------------------------------------------
    --  FLAGS FOR EXECUTING
    ------------------------------------------------------------------------------*/
    input  draw_symb                                ,
    input  draw_all                                 ,
    input  write_char_en                            ,
    
    input  start_draw                               ,
    input  cpu_cmd_ready                            ,
    input  [2:0] command_flag                       ,
    /*------------------------------------------------------------------------------
    --  MAIN PARAMETERS FOR DRAW
    ------------------------------------------------------------------------------*/
    input  [23:0] command                           ,
    input  [9:0]  litera                            ,
    input  [$clog2(`MAX_STRING_SIZE)-1:0] sys_string_len ,
    input  [$clog2(`MAX_STRING_SIZE)-1:0] user_string_len,
    input  [9:0] x1_coord                           ,
    input  [9:0] y1_coord                           ,
    input  [9:0] x2_coord                           ,
    input  [9:0] y2_coord                           ,
    input  [9:0] x3_coord                           ,
    input  [9:0] y3_coord                           ,
    /*------------------------------------------------------------------------------
    --  OUTPUTS FOR DRAWING
    ------------------------------------------------------------------------------*/
    output reg [18:0] vram_address                  ,
    output reg VGA_input_busy                       ,
    output reg VGA_exec_busy                        ,
    output reg write_enable
);

parameter WIDTH = 640, HEIGHT = 480;

parameter MAX_PIXEL_COUNT = WIDTH * HEIGHT; // Общее количество пикселей на экране

/*------------------------------------------------------------------------------
--  PREVIOUS/CURRENT VALUES FOR SAVING FRAME INFO
------------------------------------------------------------------------------*/
reg [9:0]  x_coord      ;
reg [9:0]  y_coord      ;
reg [11:0] current_color;
reg [23:0] draw_command ;

integer i, j, k;                                                                   // 32-разрядные регистры для хранения переменных
/*------------------------------------------------------------------------------
--  STRING/CHAR REGISTERS FOR DRAW
------------------------------------------------------------------------------*/
reg [$clog2(`MAX_STRING_SIZE)-1:0] 	char_counter                      ;                               // Счётчик символов в строке
reg [0:$clog2(`ALPHABET_SIZE)-1] 	string_reg [0:`MAX_STRING_SIZE-1] ;			// Регистр для хранения размещаемой в памяти строки в виде адресов символов алфавита
reg [$clog2(`MAX_STRING_SIZE)-1:0] 	string_size                       ;								// Регистр для хранения размера текущей размещаемой строки
reg [0:`CHAR_WIDTH-1] char_reg [0:`CHAR_HEIGHT-1]                     ;                              // Регистр для хранения текущего размещаемого символа
reg [0:`CHAR_WIDTH-1] alphabet [0:`CHAR_HEIGHT-1] [0:`ALPHABET_SIZE-1];         // Регистр для хранения всех символов, из которых может состоять строка для отображения

/*------------------------------------------------------------------------------
--  REGISTERS FOR STORAGE X/Y COORDS FOR CURRENT CHAR
------------------------------------------------------------------------------*/
reg [3:0] x_char, y_char;

localparam  STATES = 9,
            STATE_SIZE = $clog2(STATES);
localparam WAIT_COMMAND         = 4'd0,
           DELAY                = 4'd1,
           WAIT_PARAMETER       = 4'd2,
           WAIT_START_FLAG      = 4'd3,
           START_DRAW           = 4'd4,
           DRAW_ASCII_SEQUENCE  = 4'd5,
           DRAW_SYMBOLS         = 4'd6,
           DRAW_ONE_SYMBOL      = 4'd7,
           END_EXEC             = 4'd8;

reg [STATE_SIZE-1:0] state;

initial begin
    state <= WAIT_COMMAND;
    VGA_input_busy <= 1'd0;
    VGA_exec_busy  <= 1'd0;
    write_enable   <= 1'd0;
    $readmemb("alphabet.mem", alphabet);
    for (i = 0; i < `MAX_STRING_SIZE; i = i + 1)
		begin
			string_reg[i] <= 0;
		end
    // Сброс памяти для символа	(char_reg)
	for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
		char_reg[j] <= 0;
    i <= 0;
	j <= 0;
	k <= 0;
end

always @(posedge clk)
begin

    WAIT_COMMAND: begin
        VGA_exec_busy <= 1'b0;
        write_enable  <= 1'b0;
        
        // ЛОГИКА ДЛЯ ОДНОГО СИМВОЛА
        if (draw_symb) begin
            x_coord       <= x1_coord;
            y_coord       <= y1_coord;
            char_counter  <= 0;
            string_size   <= 1;      // Рисуем только один символ
            string_reg[0] <= litera; // Записываем текущую литеру
            
            VGA_exec_busy <= 1'b1;
            state         <= DRAW_SYMBOLS; // Входим в твой готовый цикл
        end else if (command_flag && command == ASCI) begin
            x_coord       <= x1_coord;
            y_coord       <= y1_coord;
            char_counter  <= 0;
            string_size   <= string_len; // Берем длину всей строки
            // Здесь предполагается, что string_reg уже заполнен через write_char_en
            VGA_exec_busy <= 1'b1;
            state         <= DRAW_SYMBOLS;
        end
    end

    DRAW_SYMBOLS: begin
        // ТВОЙ КОД БЕЗ ИЗМЕНЕНИЙ
        write_enable <= 1'd0;
        if (char_counter == string_size) begin
            state <= END_EXEC; 
        end else begin
            for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                char_reg[i] <= alphabet[i][string_reg[char_counter]];
            x_char <= 0;
            y_char <= 0;
            vram_address <= y_coord * WIDTH + x_coord;
            state <= DRAW_ONE_SYMBOL;
        end
    end

    DRAW_ONE_SYMBOL: begin
        // ТВОЙ КОД БЕЗ ИЗМЕНЕНИЙ
        // ... (вся твоя логика с x_char, y_char и vram_address + 1)
    end


    if (reset) begin
        VGA_input_busy <= 1'd0;
        VGA_exec_busy  <= 1'd0;
        write_enable   <= 1'd0;
        for (i = 0; i < `MAX_STRING_SIZE; i = i + 1)
        begin
            string_reg[i] <= 0;
        end
        // Сброс памяти для символа	(char_reg)
        for (j = 0; j < `CHAR_HEIGHT; j = j + 1)
            char_reg[j] <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
    end else begin
        case (state)
        
            WAIT_COMMAND:
                begin
                    if (command_flag)
                    begin
                        draw_command <= command;
                        state <= WAIT_START_FLAG;
                    end
                end

            WAIT_START_FLAG:
                begin
                    if (start_draw)
                    begin
                        VGA_exec_busy <= 1'd1;
                        state <= START_DRAW;
                    end
                end

            START_DRAW:
                begin
                    case(draw_command)
                        PIXL:
                        begin
                            vram_address <= y1_coord * WIDTH + x1_coord;
                            write_enable <= 1'd1;
                            state <= END_EXEC;
                        end

                        ASCI:
                        begin
                            y_coord <= y1_coord;
                            x_coord <= x1_coord;
                            char_counter <= 0;
                            y_char <= 0;
                            x_char <= 0;
                            string_size <= string_len;  // !!!!!ДОДЕЛАТЬ ПОЛУЧЕНИЕ РАЗМЕРА СТРОКИ!!!!!!!
                            state <= DRAW_SYMBOLS;
                        end
                        TRIG:
                        begin
                        
                        end
                    endcase
                end
            // ЦИКЛИЧЕСКОЕ СОСТОЯНИЕ ДЛЯ ОТРИСОВКИ СИМВОЛОВ
            DRAW_SYMBOLS:
                begin
                    write_enable <= 1'd0;
                    // Если все символы строки были размещены в памяти кадра
                    if (char_counter == string_size)
                    begin
                        y_coord <= y_coord + `CHAR_HEIGHT; // подсчёт новой координаты по оси ординат для следующей строки
                        state <= END_EXEC;
                        // ПОКА НЕ ОСОБО ВАЖНО, НО МОЖЕТ ПРИГОДИТСЯ
                    end else begin
                        // Для символа формируется его очертание (из алфавита)
                        for (i = 0; i < `CHAR_HEIGHT; i = i + 1)
                            char_reg[i] <= alphabet[i][string_reg[char_counter]];
                        // Сброс координат пикселей внутри символа в ноль
                        x_char <= 0;
                        y_char <= 0;
                        // Счётчик пикселей определяется порядковым номером стартового пикселя текущего символа
                        vram_address <= y_coord * WIDTH + x_coord;
                        // Переходим к отрисовке одного символа
                        state <= DRAW_ONE_SYMBOL;
                    end
                end
            
            // СОСТОЯНИЕ ОТРИСОВКИ ОДНОГО СИМВОЛА
            DRAW_ONE_SYMBOL:
                begin
                    if (y_char == `CHAR_HEIGHT)
                    begin
                        char_counter <= char_counter + 1;     // Увеличение счётчика символов в строке на единицу
                        x_coord <= x_coord + `CHAR_WIDTH;     // Определение новой координаты по оси абсцисс для следующего символа
                        write_enable <= 1'd0;
                        state <= DRAW_SYMBOLS;
                    end
                    // Символ ещё не полностью размещён в памяти
                    else if (x_char == `CHAR_WIDTH)
                    begin
                        write_enable <= 1'd0;
                        y_char <= y_char + 1;                                  // Переход к следующей строке пикселей в текущем символе
                        x_char <= 0;                                           // Координата по оси абсцисс в рамках символа сбрасывается в ноль
                        vram_address <= vram_address + WIDTH - `CHAR_WIDTH;    // Расчёт координаты следующей ячейки памяти для заполнения
                        state <= DRAW_ONE_SYMBOL;
                    end 
                    // Первый пиксель в строке символа - специальная обработка
                    else if (x_char == 0)
                    begin
                        // Обрабатываем первый пиксель строки
                        if(char_reg[y_char][0])
                        begin
                            write_enable <= 1'd1;
                        end else begin
                            write_enable <= 1'd0;
                        end
                        // Адрес НЕ увеличиваем - запись произойдет по текущему адресу на следующем такте
                        x_char <= 1;  // Готовимся к следующему пикселю
                        state <= DRAW_ONE_SYMBOL;  // Остаемся в том же состоянии
                    end
                    else
                    begin
                        // Обрабатываем все остальные пиксели (со 2-го до последнего)
                        if(char_reg[y_char][x_char])
                        begin
                            write_enable <= 1'd1;
                        end else begin
                            write_enable <= 1'd0;
                        end
                        // Переход к следующему пикселю в текущей строке символа
                        x_char <= x_char + 1;             // Переход к следующему пикселю в текущей строке
                        vram_address <= vram_address + 1; // Расчёт следующего адреса в памяти для записи
                    end
                end
            END_EXEC:
                begin
                    write_enable <= 1'd0;
                    state <= WAIT_COMMAND;
                end
        endcase
    end
end

endmodule