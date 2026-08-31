
`timescale 1ns/1ps
module tb_cpu_manager (); /* this is automatically generated */

	`ifdef VERILATOR
		`define vdelay	#0.1;
	`else
		`define vdelay
	`endif

	// clock
	logic clk;
	initial begin
		clk = '0;
		forever #(0.5) clk = ~clk;
	end

	// synchronous reset
	logic srstb;
	initial begin
		srstb <= '0;
		repeat(5)@(posedge clk);
		srstb <= '1;
	end

	// (*NOTE*) replace reset, clock, others
	logic  clk_en;
	logic  rst_n;

	tb_cpu_manager inst_tb_cpu_manager (.clk(clk), .clk_en(clk_en), .rst_n(rst_n));

	task init();
		`vdelay
		clk_en <= '0;
		rst_n  <= '0;
	endtask

	task drive(int iter);
		for(int it = 0; it < iter; it++) begin
			`vdelay
			clk_en <= '0;
			rst_n  <= '0;
			@(posedge clk);
		end
	endtask

	initial begin
		// do something

		init();
		repeat(10)@(posedge clk);

		drive(20);

		repeat(10)@(posedge clk);
		$finish;
	end

	// dump wave
	initial begin
		$display("random seed : %0d", $unsigned($get_initial_random_seed()));
		if ( $test$plusargs("fsdb") ) begin
		`ifndef VERILATOR
			$fsdbDumpfile("tb_tb_cpu_manager.fsdb");
			$fsdbDumpvars(0, "tb_tb_cpu_manager", "+mda", "+functions");
		`else
			$dumpfile("tb_tb_cpu_manager.vcd");
			$dumpvars(0, "tb_tb_cpu_manager");
		`endif
		end
	end

endmodule
