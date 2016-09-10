`timescale 1ns / 1ps


module AXI_DDR2(
      // Common
      input         CLK,                // system clock
	  input         CLK_200MHZ,                // 200MHZ
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
  
      output          axi_bvalid,
      input           axi_bready,
  
      input           axi_arvalid,
      output          axi_arready,
      input  [32-1:0] axi_araddr,
      input  [3-1:0]  axi_arprot,
  
      output          axi_rvalid,
      input           axi_rready,
      output     [32-1:0] axi_rdata,
      
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
    
    wire mem_init_calib_complete;
	wire mem_ui_clk;
	
	wire axi_wready_int;
	wire axi_awready_int;
	wire axi_rvalid_int;
	wire axi_bvalid_int;
	wire axi_arready_int;
	
	assign axi_wready = mem_ui_rst?1'b0:(mem_init_calib_complete? axi_wready_int : 1'b0 );
	assign axi_awready = mem_ui_rst?1'b0:(mem_init_calib_complete? axi_awready_int : 1'b0);
	assign axi_rvalid = mem_ui_rst?1'b0:(mem_init_calib_complete? axi_rvalid_int : 1'b0);
	assign axi_bvalid = mem_ui_rst?1'b0:(mem_init_calib_complete? axi_bvalid_int : 1'b0);
	assign axi_arready = mem_ui_rst?1'b0:(mem_init_calib_complete? axi_arready_int : 1'b0);
    
    ddr_axi Inst_DDR_AXI (
      .ddr2_dq              (ddr2_dq),
      .ddr2_dqs_p           (ddr2_dqs_p),
      .ddr2_dqs_n           (ddr2_dqs_n),
      .ddr2_addr            (ddr2_addr),
      .ddr2_ba              (ddr2_ba),
      .ddr2_ras_n           (ddr2_ras_n),
      .ddr2_cas_n           (ddr2_cas_n),
      .ddr2_we_n            (ddr2_we_n),
      .ddr2_ck_p            (ddr2_ck_p),
      .ddr2_ck_n            (ddr2_ck_n),
      .ddr2_cke             (ddr2_cke),
      .ddr2_cs_n            (ddr2_cs_n),
      .ddr2_dm              (ddr2_dm),
      .ddr2_odt             (ddr2_odt),
      //-- Inputs
      .sys_clk_i            (CLK_200MHZ),
      .sys_rst              (RST),
      //-- user interface signals
      /*.app_addr             (mem_addr),
      .app_cmd              (mem_cmd),
      .app_en               (mem_en),
      .app_wdf_data         (mem_wdf_data),
      .app_wdf_end          (mem_wdf_end),
      .app_wdf_mask         (mem_wdf_mask),
      .app_wdf_wren         (mem_wdf_wren),
      .app_rd_data          (mem_rd_data),
      .app_rd_data_end      (mem_rd_data_end),
      .app_rd_data_valid    (mem_rd_data_valid),
      .app_rdy              (mem_rdy),
      .app_wdf_rdy          (mem_wdf_rdy),*/
      .app_sr_req           (1'b0),
      //.app_sr_active        (open),
      .app_ref_req          (1'b0),
     // .app_ref_ack          (open),
      .app_zq_req           (1'b0),
     // .app_zq_ack           (open),
      .ui_clk               (mem_ui_clk),
      .ui_clk_sync_rst      (mem_ui_rst),
      .device_temp_i        (12'b000000000000),
      .init_calib_complete  (mem_init_calib_complete),
		// .user .interface .signals
		//.mmcm_locked, // IDK
		.aresetn(RST),
		// .Slave .Interface .Write .Address .Ports
		.s_axi_awid(0),
		.s_axi_awaddr(axi_awaddr),
		.s_axi_awlen(0),
		.s_axi_awsize(2),
		.s_axi_awburst(0),
		.s_axi_awlock(0),
		.s_axi_awcache(0),
		.s_axi_awprot(axi_awprot),
		.s_axi_awqos(0),
		.s_axi_awvalid(axi_awvalid),
		.s_axi_awready(axi_awready_int),
		// .Slave .Interface .Write .Data .Ports
		.s_axi_wdata(axi_wdata),
		.s_axi_wstrb(axi_wstrb),
		.s_axi_wlast(1),
		.s_axi_wvalid(axi_wvalid),
		.s_axi_wready(axi_wready_int),
		// .Slave .Interface .Write .Response .Ports
		.s_axi_bready(axi_bready),
		//.s_axi_bid(0),
		//.s_axi_bresp(0),
		.s_axi_bvalid(axi_bvalid_int),
		// .Slave .Interface .Read .Address .Ports
		.s_axi_arid(0),
		.s_axi_araddr(axi_araddr),
		.s_axi_arlen(0),
		.s_axi_arsize(2),
		.s_axi_arburst(0),
		.s_axi_arlock(0),
		.s_axi_arcache(0),
		.s_axi_arprot(axi_arprot),
		.s_axi_arqos(0),
		.s_axi_arvalid(axi_arvalid),
		.s_axi_arready(axi_arready_int),
		// .Slave .Interface .Read .Data .Ports
		.s_axi_rready(axi_rready),
		//.s_axi_rid(0),
		.s_axi_rdata(axi_rdata),
		//.s_axi_rresp(0),
		//.s_axi_rlast(1),
		.s_axi_rvalid(axi_rvalid_int)); 
endmodule
