
`timescale 1ns/1ps
module dualportram (
	input  logic         clk_i,
    input  logic         rst_i,
    input  logic         pA_wb_stb_i,
    input  logic         pA_wb_we_i,
    input  logic [3:0]   pA_wb_sel_i,
    input  logic [10:0]   pA_wb_addr_i,
    input  logic [31:0]  pA_wb_data_i,
    input  logic         pB_wb_stb_i,
    input  logic         pB_wb_we_i,
    input  logic [3:0]   pB_wb_sel_i,
    input  logic [10:0]   pB_wb_addr_i,
    input  logic [31:0]  pB_wb_data_i,
    output logic [31:0]  pA_wb_data_o,
    output logic         pA_wb_ack_o,
    output logic         pA_wb_stall_o,
    output logic [31:0]  pB_wb_data_o,
    output logic         pB_wb_ack_o,
    output logic         pB_wb_stall_o
    `ifdef USE_POWER_PINS
	, input logic VPWR,
	input logic VGND
    `endif
    
);

    logic pA_pending;
    logic pB_pending;
    logic [10:0] pA_addr_q; 
    logic [10:0] pB_addr_q;
    logic [31:0] pA_data_q; 
    logic [31:0] pB_data_q;
    logic [3:0] pA_sel_q; 
    logic [3:0] pB_sel_q;
    logic pA_we_q;
    logic pB_we_q;

    logic turn;
  
    logic ram0_en;
    logic ram1_en;
    logic [7:0] ram0_addr;
    logic [7:0] ram1_addr;
    logic [31:0] ram0_data_in;
    logic [31:0] ram1_data_in; 
    logic [3:0] ram0_we;
    logic [3:0] ram1_we;
    logic [31:0] ram0_data_out;
    logic [31:0] ram1_data_out;

    logic ram_A_sel;
    logic ram_B_sel;
    logic ram_conflict;
    logic grant_A;
    logic grant_B;
    logic grant_A_reg;
    logic grant_B_reg;
    logic A_sel_reg;
    logic B_sel_reg;
    logic [10:0] addrA;
    logic [31:0] dataA;
	logic [3:0] selA;
	logic weA;
	logic [10:0] addrB;
	logic [31:0] dataB;
	logic [3:0] selB;
	logic weB;

	assign addrA = pA_pending ? pA_addr_q : pA_wb_addr_i;
	assign dataA = pA_pending ? pA_data_q : pA_wb_data_i;
	assign selA  = pA_pending ? pA_sel_q  : pA_wb_sel_i;
	assign weA   = pA_pending ? pA_we_q   : pA_wb_we_i;

	assign addrB = pB_pending ? pB_addr_q : pB_wb_addr_i;
	assign dataB = pB_pending ? pB_data_q : pB_wb_data_i;
	assign selB = pB_pending ? pB_sel_q  : pB_wb_sel_i;
	assign weB = pB_pending ? pB_we_q   : pB_wb_we_i;


	always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i)
            turn <= 0;
        else if (pA_wb_stb_i && pB_wb_stb_i)
            turn <= ~turn;
    end



    always_ff @(posedge clk_i or posedge rst_i) begin
	    if (rst_i) begin
	        pA_pending <= 0;
	        pB_pending <= 0;
	        pA_wb_ack_o <= 0;
	        pB_wb_ack_o <= 0;
			grant_A_reg <= 0;
			grant_B_reg <= 0;
			A_sel_reg <= 0;
			B_sel_reg <= 0;
	    end else begin
	        pA_wb_ack_o <= 0;
	        pB_wb_ack_o <= 0;
			grant_A_reg <= 0;
			grant_B_reg <= 0;
			A_sel_reg <= 0;
			B_sel_reg <= 0;
			if (pA_wb_stall_o) begin
	            pA_addr_q <= pA_wb_addr_i;
	            pA_data_q <= pA_wb_data_i;
	            pA_sel_q  <= pA_wb_sel_i;
	            pA_we_q   <= pA_wb_we_i;
	            pA_pending <= 1;
	        end 
			if (pB_wb_stall_o) begin
	            pB_addr_q <= pB_wb_addr_i;
	            pB_data_q <= pB_wb_data_i;
	            pB_sel_q <= pB_wb_sel_i;
	            pB_we_q <= pB_wb_we_i;
	            pB_pending <= 1;
	        end 
	        if (grant_A) begin
		        if (pA_pending) begin
		            pA_addr_q <= pA_wb_addr_i;
		       	    pA_data_q <= pA_wb_data_i;
		     	    pA_sel_q <= pA_wb_sel_i;
		            pA_we_q <= pA_wb_we_i;
		            pA_pending <= 1;
		        end
	            pA_wb_ack_o <= 1; 
				grant_A_reg <= grant_A;
				A_sel_reg <= ram_A_sel;
	        end else if (pA_pending) begin
	            pA_wb_ack_o <= 1;
	            pA_pending <= 0;
	        end
			if (grant_B) begin
	            if (pB_pending) begin
	                pB_addr_q <= pB_wb_addr_i;
	           	    pB_data_q <= pB_wb_data_i;
	         	    pB_sel_q <= pB_wb_sel_i;
	                pB_we_q <= pB_wb_we_i;
	                pB_pending <= 1;
	            end
	            pB_wb_ack_o <= 1;
				grant_B_reg <= grant_B;
				B_sel_reg <= ram_B_sel;
	        end else if (pB_pending) begin
	            pB_wb_ack_o <= 1;
	            pB_pending <= 0;
	        end
		end
	end





    assign ram_A_sel = addrA[10];
    assign ram_B_sel = addrB[10];

    assign ram_conflict = (pA_wb_stb_i || pA_pending) && (pB_wb_stb_i || pB_pending) && (ram_A_sel == ram_B_sel);

    assign grant_A = (pA_wb_stb_i && (!ram_conflict || !turn)); // when turn is 0
    assign grant_B = (pB_wb_stb_i && (!ram_conflict ||  turn)); //when turn is 1

    assign pA_wb_stall_o = pA_wb_stb_i && ram_conflict && turn;
    assign pB_wb_stall_o = pB_wb_stb_i && ram_conflict && !turn;

// ram 0
    assign ram0_en = ((pA_pending && !A_sel_reg) || (grant_A && !ram_A_sel)) || ((pB_pending && !B_sel_reg) || (grant_B && !ram_B_sel));
    assign ram0_addr = ((pA_pending && !A_sel_reg) || (grant_A && !ram_A_sel)) ? addrA[9:2] : addrB[9:2];
    assign ram0_data_in = ((pA_pending && !A_sel_reg) || (grant_A && !ram_A_sel)) ? dataA : dataB;
    assign ram0_we = ((pA_pending && !A_sel_reg) || (grant_A && !ram_A_sel)) ? (weA ? selA : 4'b0000) : (weB ? selB : 4'b0000);

//ram 1

    assign ram1_en = ((pA_pending && A_sel_reg) || (grant_A && ram_A_sel)) || ((pB_pending && B_sel_reg) || (grant_B && ram_B_sel));
    assign ram1_addr = ((pA_pending && A_sel_reg) || (grant_A && ram_A_sel)) ? addrA[9:2] : addrB[9:2];
    assign ram1_data_in = ((pA_pending && A_sel_reg) || (grant_A && ram_A_sel)) ? dataA : dataB;
    assign ram1_we = ((pA_pending && A_sel_reg) || (grant_A && ram_A_sel)) ? (weA ? selA : 4'b0000) : (weB ? selB : 4'b0000);

    // RAM Instantiations

    DFFRAM256x32 mem0 (
        .CLK(clk_i),
        .WE0(ram0_we),
        .EN0(ram0_en),
        .A0(ram0_addr),
        .Di0(ram0_data_in),
        .Do0(ram0_data_out)
    );

    DFFRAM256x32 mem1 (
        .CLK(clk_i),
        .WE0(ram1_we),
        .EN0(ram1_en),
        .A0(ram1_addr),
        .Di0(ram1_data_in),
        .Do0(ram1_data_out)
    );

    assign pA_wb_data_o = (A_sel_reg ? ram1_data_out : ram0_data_out);
    assign pB_wb_data_o = (B_sel_reg ? ram1_data_out : ram0_data_out);


endmodule
