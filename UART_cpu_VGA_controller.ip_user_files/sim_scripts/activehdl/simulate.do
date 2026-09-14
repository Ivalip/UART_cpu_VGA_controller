transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+VGA_Manager_tb  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.VGA_Manager_tb xil_defaultlib.glbl

do {VGA_Manager_tb.udo}

run 1000ns

endsim

quit -force
