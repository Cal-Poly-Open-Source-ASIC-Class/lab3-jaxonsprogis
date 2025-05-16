`timescale 1ns/1ps

module tb_dualportram;

	logic clk;
	logic rst;

	// Port A signals
	logic pA_wb_stb, pA_wb_we;
	logic [3:0] pA_wb_sel;
	logic [10:0] pA_wb_addr;
	logic [31:0] pA_wb_data_in;
	logic [31:0] pA_wb_data_out;
	logic pA_wb_ack;
	logic pA_wb_stall;

	// Port B signals
	logic pB_wb_stb, pB_wb_we;
	logic [3:0] pB_wb_sel;
	logic [10:0] pB_wb_addr;
	logic [31:0] pB_wb_data_in;
	logic [31:0] pB_wb_data_out;
	logic pB_wb_ack;
	logic pB_wb_stall;

	`ifdef USE_POWER_PINS
		wire VPWR;
		wire VGND;
		assign VPWR = 1;
		assign VGND = 0;

	`endif

	// Instantiate DUT
	dualportram dut (
		.clk_i(clk),
		.rst_i(rst),
		.pA_wb_stb_i(pA_wb_stb),
		.pA_wb_we_i(pA_wb_we),
		.pA_wb_sel_i(pA_wb_sel),
		.pA_wb_addr_i(pA_wb_addr),
		.pA_wb_data_i(pA_wb_data_in),
		.pA_wb_data_o(pA_wb_data_out),
		.pA_wb_ack_o(pA_wb_ack),
		.pA_wb_stall_o(pA_wb_stall),
		.pB_wb_stb_i(pB_wb_stb),
		.pB_wb_we_i(pB_wb_we),
		.pB_wb_sel_i(pB_wb_sel),
		.pB_wb_addr_i(pB_wb_addr),
		.pB_wb_data_i(pB_wb_data_in),
		.pB_wb_data_o(pB_wb_data_out),
		.pB_wb_ack_o(pB_wb_ack),
		.pB_wb_stall_o(pB_wb_stall)
		`ifdef USE_POWER_PINS
			, .VPWR(VPWR),
			.VGND(VGND)
		`endif
	);

	localparam CLK_PERIOD = 10;
	always begin
	#(CLK_PERIOD/2) 
	clk<=~clk;
	end

	initial begin
	// Name as needed
	$dumpfile("tb_dualportram.vcd");
	$dumpvars(2,tb_dualportram);
	end

	initial #100000 $error("Timeout");

	task reset();
		rst = 1;
		pA_wb_stb = 0;
		pA_wb_we = 0;
		pA_wb_sel = 4'b1111;
		pA_wb_addr = 0;
		pA_wb_data_in = 0;

		pB_wb_stb = 0;
		pB_wb_we = 0;
		pB_wb_sel = 4'b1111;
		pB_wb_addr = 0;
		pB_wb_data_in = 0;

		#20;
		rst = 0;
		#20;
	endtask

	task write_A(input [10:0] addr, input [31:0] data);
		@(posedge clk);
		pA_wb_stb = 1;
		pA_wb_we = 1;
		pA_wb_addr = addr;
		pA_wb_data_in = data;
		pA_wb_sel = 4'b1111;
		@(posedge clk);
		pA_wb_stb = 0;
		pA_wb_we = 0;
	endtask

	task write_B(input [10:0] addr, input [31:0] data);
		@(posedge clk);
		pB_wb_stb = 1;
		pB_wb_we = 1;
		pB_wb_addr = addr;
		pB_wb_data_in = data;
		pB_wb_sel = 4'b1111;
		@(posedge clk);
		pB_wb_stb = 0;
		pB_wb_we = 0;
	endtask

	task read_A(input [10:0] addr);
		pA_wb_stb = 1;
		pA_wb_we = 0;
		pA_wb_addr = addr;
		pA_wb_sel = 4'b1111;
		@(posedge clk);
		pA_wb_stb = 0;
	endtask

	task read_B(input [10:0] addr);
		pB_wb_stb = 1;
		pB_wb_we = 0;
		pB_wb_addr = addr;
		pB_wb_sel = 4'b1111;
		@(posedge clk);
		pB_wb_stb = 0;
	endtask

	initial begin
		clk = 0;
		reset();

		// concurrent writes to different RAMs (should succeed)
		fork
			write_A(11'b00000000100, 32'hAAAA_BBBB);  // RAM0
			write_B(11'b10000001000, 32'hCCCC_DDDD);  // RAM1
		join

		// read back both
		read_A(11'b00000000100);
		read_B(11'b10000001000);

		// concurrent writes to SAME RAM (should stall one)
		fork
			write_A(11'b00000000100, 32'h1111_2222); 
			write_B(11'b00000001000, 32'h3333_4444);  
		join

		// read back both
		read_A(11'b00000000100); 
		read_B(11'b00000001000); 

		@(posedge clk)
		@(posedge clk)
		@(posedge clk)
		@(posedge clk)
		$finish;
	end

endmodule
