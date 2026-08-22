-makelib xcelium_lib/xpm -sv \
  "E:/Xilinx_Windows_2022/Vivado/2022.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "E:/Xilinx_Windows_2022/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_4_5 \
  "../../../ipstatic/simulation/blk_mem_gen_v8_4.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../UART_cpu_VGA_controller.gen/sources_1/ip/BRAM_mem_gen_12x307200/sim/BRAM_mem_gen_12x307200.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

