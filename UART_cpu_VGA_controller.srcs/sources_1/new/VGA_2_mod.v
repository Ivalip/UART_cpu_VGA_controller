`timescale 1ns / 1ps

`define WIDTH 640 				// Ширина видимой области экрана в пикселях
`define H_FRONT_PORCH 16 		// Число тактов FRONT PORCH по горизонтали
`define H_BACK_PORCH 48 		// Число тактов BACK PORCH по горизонтали
`define H_SYNC 96 				// Число тактов импульса синхронизации (строба) по горизонтали

`define HEIGHT 480 				// Высота видимой области экрана в пикселях
`define V_FRONT_PORCH 10 		// Число строк FRONT PORCH по вертикали
`define V_BACK_PORCH 33 		// Число строк BACK PORCH по вертикали
`define V_SYNC 2                // Число строк импульса синхронизации (строба) по вертикали

`define RESET 				4'd0
`define HOR_PERIOD			4'd1
`define H_NOT_ACTIVE_PERIOD 4'd2
`define V_NOT_ACTIVE_PERIOD 4'd3

`define COLOR_BIT_SIZE 12		// Число бит, требуемых для кодирования цвета 

module VGA_2_mod (
	input clk, // Синхросигнал
	
	input [`COLOR_BIT_SIZE-1:0] mem_data,				// Цвет текущего пикселя, который приходит из памяти
	output reg [$clog2(`WIDTH * `HEIGHT)-1:0] mem_addr, // Адрес для взятия пикселя из памяти
	
	output [3:0] vgaRed,	// Глубина красного цвета, закодированного четырьмя битами
	output [3:0] vgaGreen,  // Глубина зелёного цвета, закодированного четырьмя битами
	output [3:0] vgaBlue,	// Глубина синего цвета, закодированного четырьмя битами
	
	output reg Hsync,	// Выход для сигнала горизонтальной синхронизации
	output reg Vsync,	// Выход для сигнала вертикальной синхронизации		

	output reg vgaBegin, // Сигнал о начале отрисовки кадра
	output reg vgaEnd	 // Сигнал об окончании отрисовки кадра
);
reg [`COLOR_BIT_SIZE-1:0] vgaColor;	// Цвет, считанный из памяти

// Блок перевода однобитного цвета в четырёхбитный
assign   vgaRed = vgaColor[11:8];
assign vgaGreen = vgaColor[7:4] ;
assign  vgaBlue = vgaColor[3:0] ;

reg vga_clk; // Синхросигнал VGA

reg [$clog2(`WIDTH + `H_FRONT_PORCH + `H_SYNC + `H_BACK_PORCH)-1:0] H_counter; // Счётчик сигнала синхронизации по горизонтали
reg [$clog2(`HEIGHT + `V_FRONT_PORCH + `V_SYNC + `V_BACK_PORCH)-1:0] V_counter; // Счётчик сигнала синхронизации по вертикали

reg [1:0] state; // Регистр состояния
	
// T-триггер, осуществляющий деление частоты синхросигнала	
always@(posedge clk)
begin
	vga_clk <= ~vga_clk;
end
// Блок инициализации
initial 
begin
	vga_clk <= 0;
	vgaColor <= 0;
	state <= `RESET;
end
// Основной блок
always@(posedge vga_clk)
begin
	case(state)
		// Сброс автомата в ноль
		`RESET: 
				begin
					mem_addr <= 0;
					V_counter <= 0;
					H_counter <= 0;	
					vgaBegin <= 1; 
					vgaEnd <= 0;
					vgaColor <= 0;
					
					state <= `HOR_PERIOD;
				end
		// Состояние, отвечающее за Display период по горизонтали 
		`HOR_PERIOD: 
			begin
				// Если счётчик по горизонтали дошёл до ширины экрана
				if (H_counter == `WIDTH)
					begin
						vgaColor <= 0;// Цвет пикселя на выходе устанавливается в чёрный
						state <= `H_NOT_ACTIVE_PERIOD;// переход в состояния отсчёта неактивного периода по горизонтали
					end
				// Иначе (процесс отрисовки пикселей в одной строке не окончен)
				else
					begin
						//Проверка того, что текущий по вертикали - Display
						if (V_counter < `HEIGHT)
							begin
								vgaColor <= mem_data;//установка цвета пикселя, как цвет, считанный из памяти
								//пока не дойдем до конца памяти  
								if (mem_addr < `WIDTH * `HEIGHT-1)
									mem_addr <= mem_addr + 1; //переход к следующему пикселю (его адресу)
								//иначе
								else
									mem_addr <= 0;//адрес устанавливается в ноль, т.е. считывание кадра начинается с самого начала
							end
						H_counter <= H_counter + 1;// счётчик по горизонтали увеличивается на 1
					end
				vgaBegin <= 0;	// сигнал о начале отрисовки кадра сбрасывается в ноль, чтобы он держался ровно 1 такт	
			end
		
		// Состояние неактивного периода по горизонтали
		`H_NOT_ACTIVE_PERIOD:
			//Если по горизонтали наступил момент начала или окончания импульса синхронизации
			if (H_counter == `WIDTH + `H_FRONT_PORCH - 1 || H_counter == `WIDTH + `H_FRONT_PORCH + `H_SYNC - 1)
				begin
					Hsync <= ~Hsync;//сигнал синхронизации по горизонтали сменяется на противоположный
					H_counter <= H_counter + 1;// счётчик по горизонтали увеличивается на 1
				end
			else 
			//Если по горизонтали наступил момент окончания цикла сигнала синхронизации
			if (H_counter == `WIDTH + `H_FRONT_PORCH + `H_SYNC + `H_BACK_PORCH - 1)
				state <= `V_NOT_ACTIVE_PERIOD;//переход в состояние неактивного периода по вертикали
			//Иначе продолжается отсчёт по горизонтали
			else
				H_counter <= H_counter + 1;
			
		// Состояние неактивного периода по вертикали			
		`V_NOT_ACTIVE_PERIOD:
			// Если по вертикали наступил момент окончания цикла сигнала синхронизации
			if (V_counter == `HEIGHT + `V_FRONT_PORCH + `V_SYNC + `V_BACK_PORCH - 1)
				begin
					state <= `RESET;//переход в состояние сброса
					vgaEnd <= 1; //сигнал о конце отрисовки кадра устанавливается в 1
				end
			//Если окончание цикла сигнала синхронизации ещё не наступило
			else
				begin
					//Если по вертикали наступил момент начала или окончания импульса синхронизации
					if (V_counter == `HEIGHT + `V_FRONT_PORCH - 1 || V_counter == `HEIGHT + `V_FRONT_PORCH + `V_SYNC - 1)
						Vsync <= ~Vsync;//сигнал синхронизации по вертикали сменяется на противоположный
					H_counter <= 0;	//Счётчик по горизонтали начинает отсчёт заново (новая строка пикселей)
					V_counter <= V_counter + 1;// счётчик по вертикали увеличивается на 1
					state <= `HOR_PERIOD;// Следующее состояние - отсчёт цикла по горизонтали
				end			
	endcase
end
endmodule