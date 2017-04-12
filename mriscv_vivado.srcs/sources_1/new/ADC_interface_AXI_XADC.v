`timescale 1ns / 1ps

module ADC_interface_AXI_XADC (
//----general--input----
	input CLK,
	input RST,
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
//----Ignorable data----
	output [7:0] ALM,
	output OT,
	output XADC_EOC,
	output XADC_EOS/*,
// ANALOG data
    input [3:0] VAUXP, 
	input [3:0] VAUXN,
	input VP, 
	input VN*/);
	
	wire EOS, EOC;
	wire busy;
	wire [4:0] CHANNEL;
	wire drdy;
	reg [6:0] daddr;
	reg [15:0] di_drp;
	wire [15:0] do_drp;
	//reg [15:0] vauxp_active;
	//reg [15:0] vauxn_active;
	reg [1:0] den_reg;
	reg [1:0] dwe_reg;
	wire RESET_IN;
	assign RESET_IN = ~RST;
	
	// AXI-4 Auxiliar
    reg [31:0] waddr, raddr;
    reg [31:0] wdata;
	reg [3:0] wstrb;
    reg [1:0] wassert;
    reg rassert;
	
	// AXI-4 immediate responses
    assign axi_awready = 1'b1;
    assign axi_arready = 1'b1;
    assign axi_wready = 1'b1;
	
	// AXI-4 Single shot response and saving
    always @(posedge CLK)
    begin : SINGLE_SHOT
        if(RST == 1'b0) begin
            waddr <= 0;
            raddr <= 0;
            wdata <= 0;
			wstrb <= 0;
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
				wstrb <= wstrb;
                wassert[1] <= 1'b0;
            end else if(axi_wvalid) begin
                wdata <= axi_wdata;
				wstrb <= axi_wstrb;
                wassert[1] <= 1'b1;
            end else begin
                wdata <= wdata;
				wstrb <= wstrb;
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

	parameter 	init_read = 8'h00,
				read_waitdrdy = 8'h01,
				write_waitdrdy = 8'h03,
				st_idle = 8'h04,
				read_reg = 8'h05,
				rreg_waitdrdy = 8'h06,
				write_reg = 8'h07,
				wreg_waitdrdy = 8'h08,
				axi_waitrready = 8'h09,
				axi_waitbready = 8'h0A;
	reg [7:0] state;
	//reg [7:0] ret_state;
	
	always @(posedge CLK)
	if (RST == 1'b0) begin
		state <= init_read;
		den_reg <= 2'h0;
		dwe_reg <= 2'h0;
		di_drp <= 16'h0000;
		daddr <= 0;
		//vauxp_active <= 0;
		//vauxn_active <= 0;
		axi_rdata <= 0;
		axi_bvalid <= 1'b0;
		axi_rvalid <= 1'b0;
	end	else case (state)
	init_read : begin
		daddr <= 7'h40;		// READ CONFIG REGISTER 1
		den_reg <= 2'h2;    // performing read
		if (busy == 0 ) state <= read_waitdrdy;
		end
	read_waitdrdy :
		if (drdy ==1) begin
			di_drp <= do_drp & 16'h03_FF; //Clearing AVG bits for Configreg0
			daddr <= 7'h40;
			den_reg <= 2'h2;
			dwe_reg <= 2'h2; // performing write
			state <= write_waitdrdy;
		end	else begin
			den_reg <= { 1'b0, den_reg[1] } ;
			dwe_reg <= { 1'b0, dwe_reg[1] } ;
			state <= state;
		end
	write_waitdrdy :
		if (drdy ==1) begin
			state <= st_idle;
		end	else begin
			den_reg = { 1'b0, den_reg[1] } ;
			dwe_reg = { 1'b0, dwe_reg[1] } ;
			state <= state;
		end
	st_idle :
		if (rassert) begin
			state <= read_reg;
		end	else if(wassert == 2'b11) begin
			/*if(waddr[8:2] == 7'h00) begin	// This registers cannot be written, but we can use it
				vauxn_active <= wdata[15:0];
				axi_bvalid <= 1'b1;
				state <= wreg_waitdrdy;
			end else if (waddr[8:2] == 7'h01) begin 
				vauxp_active <= wdata[15:0];
				axi_bvalid <= 1'b1;
				state <= wreg_waitdrdy;
			end else begin */
				state <= write_reg;
			//end
		end else begin
			state <= state;
		end
	read_reg : begin
		daddr = raddr[8:2];
		den_reg = 2'h2; // performing read
		if (EOC == 1) state <=rreg_waitdrdy;
		end
	rreg_waitdrdy :
		if (drdy ==1) begin
			axi_rdata <= {15'd0, do_drp};
			axi_rvalid <= 1'b1;
			state <= axi_waitrready;
		end	else begin
			den_reg = { 1'b0, den_reg[1] } ;
			dwe_reg = { 1'b0, dwe_reg[1] } ;
			state <= state;
		end
	axi_waitrready :
		if (axi_rready ==1) begin
			axi_rvalid <= 1'b0;
			state <= st_idle;
		end	else begin
			state <= state;
		end
	write_reg : begin
		di_drp <= wdata[15:0];
		daddr <= waddr[8:2];
		den_reg <= 2'h2;
		dwe_reg <= 2'h2; // performing write
		state <= wreg_waitdrdy;
		end
	wreg_waitdrdy :
		if (drdy ==1) begin
			axi_bvalid <= 1'b1;
			state <= axi_waitbready;
		end	else begin
			den_reg <= { 1'b0, den_reg[1] } ;
			dwe_reg <= { 1'b0, dwe_reg[1] } ;
			state <= state;
		end
	axi_waitbready :
		if (axi_bready ==1) begin
			axi_bvalid <= 1'b0;
			state <= st_idle;
		end	else begin
			state <= state;
		end
	default: begin
		state <= init_read; end
	endcase
    
    
    wire [15:0] vauxp_active;
    wire [15:0] vauxn_active;
    assign vauxp_active = 16'h0000;//= {12'h000, VAUXP[3:0]};
    assign vauxn_active = 16'h0000;//= {12'h000, VAUXN[3:0]};
    
    XADC #(
    .INIT_40(16'h9000),// averaging of 16 selected for external CHANNELs
	.INIT_41(16'h2ef0),// Continuous Seq Mode, Disable unused ALMs, Enable calibration
	.INIT_42(16'h0400),// Set DCLK divides
	.INIT_48(16'h4701),// CHSEL1 - enable Temp VCCINT, VCCAUX, VCCBRAM, and calibration
	.INIT_49(16'h000f),// CHSEL2 - enable aux analog CHANNELs 0 - 3
	.INIT_4A(16'h0000),// SEQAVG1 disabled
	.INIT_4B(16'h0000),// SEQAVG2 disabled
	.INIT_4C(16'h0000),// SEQINMODE0
	.INIT_4D(16'h0000),// SEQINMODE1
	.INIT_4E(16'h0000),// SEQACQ0
	.INIT_4F(16'h0000),// SEQACQ1
	.INIT_50(16'hb5ed),// Temp upper alarm trigger 85°C
	.INIT_51(16'h5999),// Vccint upper alarm limit 1.05V
	.INIT_52(16'hA147),// Vccaux upper alarm limit 1.89V
	.INIT_53(16'hdddd),// OT upper alarm limit 125°C - see Thermal Management
	.INIT_54(16'ha93a),// Temp lower alarm reset 60°C
	.INIT_55(16'h5111),// Vccint lower alarm limit 0.95V
	.INIT_56(16'h91Eb),// Vccaux lower alarm limit 1.71V
	.INIT_57(16'hae4e),// OT lower alarm reset 70°C - see Thermal Management
	.INIT_58(16'h5999),// VCCBRAM upper alarm limit 1.05V
	.SIM_MONITOR_FILE("design.txt")// Analog Stimulus file for simulation
    )
    XADC_INST ( // Connect up instance IO. See UG480 for port descriptions
		// General ports
		.RESET(RESET_IN),
		.DCLK(CLK),
		// DRP (Dynamic Reconfiguration Port)
		.DADDR (daddr),
		.DEN (den_reg[0]),
		.DI (di_drp),
		.DWE (dwe_reg[0]),
		.DO (do_drp),
		.DRDY (drdy),
		
        .VAUXN (vauxn_active ),
        .VAUXP (vauxp_active ),
		.ALM (ALM),
		.BUSY (busy),
		.CHANNEL(CHANNEL),
		.EOC (EOC),
		.EOS (EOS),
		// JTAG Arbritator (Not used)
		.JTAGBUSY (),// not used
		.JTAGLOCKED (),// not used
		.JTAGMODIFIED (),// not used
		.OT (OT),
		.MUXADDR (),// not used
		.VP (VP),
		.VN (VN)
    );
	assign XADC_EOC = EOC;
	assign XADC_EOS = EOS;
endmodule
