`timescale 1ns / 1ps


module AXI_SRAM(
      // Common
      input         CLK,                // system clock
      input         RST,              // active high system reset
      
      // AXI-4 SLAVE Interface
      input           axi_awvalid,
      output          axi_awready,
      input  [32-1:0] axi_awaddr,
      input  [3-1:0]  axi_awprot,
  
      input           axi_wvalid,
      output          axi_wready,
      input  [32-1:0] axi_wdata,
      input  [4-1:0]  axi_wstrb,
  
      output reg      axi_bvalid,
      input           axi_bready,
  
      input           axi_arvalid,
      output          axi_arready,
      input  [32-1:0] axi_araddr,
      input  [3-1:0]  axi_arprot,
  
      output reg      axi_rvalid,
      input           axi_rready,
      output reg [32-1:0] axi_rdata,
      
      // DDR2 interface
      output [12:0] ddr2_addr,
      output [2:0]  ddr2_ba,
      output        ddr2_ras_n,
      output        ddr2_cas_n,
      output        ddr2_we_n,
      output [0:0]  ddr2_ck_p,
      output [0:0]  ddr2_ck_n,
      output [0:0]  ddr2_cke,
      output [0:0]  ddr2_cs_n,
      output [1:0]  ddr2_dm,
      output [0:0]  ddr2_odt,
      inout  [15:0] ddr2_dq,
      inout  [1:0]  ddr2_dqs_p,
      inout  [1:0]  ddr2_dqs_n

    );
    
    // Misc 
    wire rst_i;
    assign rst_i = ~RST;
    wire clk_200MHz_i;
    assign clk_200MHz_i = CLK;
    
    // RAM interface
    wire  [26:0] ram_a;
    wire  [15:0] ram_dq_i;
    wire  [15:0] ram_dq_o;
    reg          ram_cen;	// Controlled by state machine
    reg          ram_oen;	// Controlled by state machine	
    reg          ram_wen;	// Controlled by state machine
    wire         ram_ub;
    wire         ram_lb;
	wire		 ddr2_ready;
    
    // AXI-4 Auxiliar
    reg [31:0] waddr, raddr;
    reg [31:0] wdata;
    reg [1:0] wassert;
    reg rassert;
	
	// AXI-4 immediate responses
    assign axi_awready = 1'b1;
    assign axi_arready = 1'b1;
    assign axi_wready = 1'b1;
    
    // Single shot response and saving
    always @(posedge CLK)
    begin : SINGLE_SHOT
        if(RST == 1'b0) begin
            waddr <= 0;
            raddr <= 0;
            wdata <= 0;
            wassert <= 2'b00;
            rassert <= 1'b0;
        end else begin
            if(axi_bvalid) begin	// bvalid indicates wterm sig
                waddr <= waddr;
                wassert[0] <= 1'b0;
            end else if(axi_awvalid) begin
                waddr <= axi_awaddr;
                wassert[0] <= 1'b1;
            end else begin
                waddr <= waddr;
                wassert[0] <= wassert[0];
            end
            
            if(axi_bvalid) begin	// bvalid indicates wterm sig
                wdata <= wdata;
                wassert[1] <= 1'b0;
            end else if(axi_wvalid) begin
                wdata <= axi_wdata;
                wassert[1] <= 1'b1;
            end else begin
                wdata <= wdata;
                wassert[1] <= wassert[1];
            end
            
            if(axi_rvalid) begin	// rvalid indicates rterm sig
                raddr <= raddr;
                rassert <= 1'b0;
            end else if(axi_arvalid) begin
                raddr <= axi_araddr;
                rassert <= 1'b1;
            end else begin
                raddr <= raddr;
                rassert <= rassert;
            end
        end
    end
		
	// MAIN STATE-MACHINE
	
	reg [3:0] state;
	
	parameter st0_idle = 0, st1_waitrready = 1, st2_waitbready = 2;
	
	always @(posedge CLK)
	if (RST == 1'b0) begin
		state <= st0_idle;
		for(idx = 0; idx < 8; idx = idx + 1)
			regs[idx] <= 0;
		axi_bvalid <= 1'b0;
		axi_rvalid <= 1'b0;
		axi_rdata <= 0;
	end	else case (state)
	st0_idle :
		if (rassert) begin
			axi_rdata <= {24'd0, regs[raddr[4:2]]};
			state <= st1_waitrready;
			axi_rvalid <= 1'b1;
		end	else if(wassert == 2'b11) begin
			if(waddr[4:2] == 3'h0 && wdata[7:0] == 8'h0A)
				flag_erase <= 1'b1;
			else if(waddr[4:2] == 3'h0 && wdata[7:0] >= 8'd32) begin
				if(flag_erase) begin
					flag_erase <= 1'b0;
					for(idx = 0; idx < 8; idx = idx + 1)
						regs[idx] <= 0;
				end else begin
					regs[0] <= wdata[7:0];
					for(idx = 0; idx < 7; idx = idx + 1)
						regs[idx+1] <= regs[idx];
				end
			end else begin 
				regs[waddr[4:2]] <= wdata[7:0];
			end
			state <= st2_waitbready;
			axi_bvalid <= 1'b1;
		end else begin
			state <= state;
		end
	st1_waitrready :
		if (axi_rready ==1) begin
			axi_rvalid <= 1'b0;
			state <= st0_idle;
		end	else begin
			state <= state;
		end
	st2_waitbready :
		if (axi_bready ==1) begin
			axi_bvalid <= 1'b0;
			state <= st0_idle;
		end	else begin
			state <= state;
		end
	default: begin
		state <= st0_idle; end
	endcase
    
    // Memory implementation. 
	reg [32-1:0] MEM [0:(2**24)-1];
	reg [32-1:0] Q;
	always @(posedge CLK)
	if (RST == 1'b0) begin
		Q <= 0;
	end	else begin
		if(uart_mem_cen) begin
			Q <= MEM[uart_mem_addr];
			if(uart_mem_wen) MEM[uart_mem_addr] <= uart_mem_d;
		end
	end
	assign uart_mem_q = Q;
	
endmodule
