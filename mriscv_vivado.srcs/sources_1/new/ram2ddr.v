`timescale 1ns / 1ps
//-------------------------------------------------------------------------------
//--                                                                 
//--  COPYRIGHT (C) 2014, Digilent RO. All rights reserved
//--                                                                  
//-------------------------------------------------------------------------------
//-- FILE NAME      : ram2ddr.vhd
//-- MODULE NAME    : RAM to DDR2 Interface Converter without internal XADC
//--                  instantiation
//-- AUTHOR         : Mihaita Nagy
//-- AUTHOR'S EMAIL : mihaita.nagy@digilent.ro
//-------------------------------------------------------------------------------
//-- REVISION HISTORY
//-- VERSION  DATE         AUTHOR         DESCRIPTION
//-- 1.0      2014-02-04   Mihaita Nagy   Created
//-------------------------------------------------------------------------------
//-- DESCRIPTION    : This module implements a simple Static RAM to DDR2 interface
//--                  converter designed to be used with Digilent Nexys4-DDR board
//-------------------------------------------------------------------------------

// ADAPTED TO VERILOG BY: CKDUR

module ram2ddr(
      // Common
	  input			CLK,
      input         clk_200MHz_i,       // 200 MHz system clock
      input         rst_i,              // active high system reset
      input  [11:0] device_temp_i,
      
      // RAM interface
      input  [26:0] ram_a,
      input  [15:0] ram_dq_i,
      output [15:0] ram_dq_o,
      input         ram_cen,
      input         ram_oen,
      input         ram_wen,
      input         ram_ub,
      input         ram_lb,
	  
	  // RAM APP aditional
	  output 		mem_init_calib_complete,
	  output 		mem_rdy,
	  output 		mem_wdf_rdy,
	  output reg 	rd_vld,
	  output reg 	rd_end,
	  output 		ddr2_ready,
      
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
 
 
//    ------------------------------------------------------------------------
//    -- Local Type Declarations
//    ------------------------------------------------------------------------
//    -- FSM
    localparam [3:0] stIdle    = 4'b0000;
    localparam [3:0] stSetCmd   = 4'b0001;
    localparam [3:0] stCheckRdy = 4'b0010;
    localparam [3:0] stWaitRdy  = 4'b0011;
    localparam [3:0] stWaitCen  = 4'b0100; 
//    ------------------------------------------------------------------------
//    -- Constant Declarations
//    ------------------------------------------------------------------------
//    -- ddr commands
    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;
    
//    ------------------------------------------------------------------------
//    -- Signal Declarations
//    ------------------------------------------------------------------------
//    -- state machine
    reg [3:0] cState, nState;

//    -- global signals
    
    wire mem_ui_clk;
    wire mem_ui_rst;
    wire rst;
    wire rstn;
    
//    -- ram internal signals
    /*reg [26:0] ram_a_int;
    reg [15:0] ram_dq_i_int;
    reg ram_cen_int;
    reg ram_oen_int;
    reg ram_wen_int;
    reg ram_ub_int;
    reg ram_lb_int;*/
	wire [26:0] ram_a_int;
    wire [15:0] ram_dq_i_int;
    wire ram_cen_int;
    wire ram_oen_int;
    wire ram_wen_int;
    wire ram_ub_int;
    wire ram_lb_int;
	reg [15:0] ram_dq_o_int;
    
//    -- ddr user interface signals
//    -- address for current request
    reg [26:0]  mem_addr; 
//    -- command for current request
    reg [2:0]  mem_cmd; 
//    -- active-high strobe for 'cmd' and 'addr'
    reg mem_en; 
    //wire mem_rdy;
//    -- write data FIFO is ready to receive data (wdf_rdy = 1 & wdf_wren = 1)
    //wire mem_wdf_rdy; 
    reg [63:0] mem_wdf_data;
//    -- active-high last 'wdf_data'
    reg mem_wdf_end; 
    reg [7:0] mem_wdf_mask;
    reg mem_wdf_wren;
    wire [63:0] mem_rd_data;
//    -- active-high last 'rd_data'
    wire mem_rd_data_end; 
//    -- active-high 'rd_data' valid
    wire mem_rd_data_valid; 
//    -- active-high calibration complete
    //wire mem_init_calib_complete; 
//    -- delayed valid
    //reg rd_vld; 
//    -- delayed end
    //reg rd_end; 
//    -- delayed data
    reg [63:0] rd_data_1, rd_data_2;
    
//    ------------------------------------------------------------------------
//    -- Signal attributes (debugging)
//    ------------------------------------------------------------------------
//    --attribute KEEP                            : string;
//    --attribute KEEP of mem_addr                : signal is "TRUE";
//    --attribute KEEP of mem_cmd                 : signal is "TRUE";
//    --attribute KEEP of mem_en                  : signal is "TRUE";
//    --attribute KEEP of mem_wdf_data            : signal is "TRUE";
//    --attribute KEEP of mem_wdf_end             : signal is "TRUE";
//    --attribute KEEP of mem_wdf_mask            : signal is "TRUE";
//    --attribute KEEP of mem_wdf_wren            : signal is "TRUE";
//    --attribute KEEP of mem_rd_data             : signal is "TRUE";
//    --attribute KEEP of mem_rd_data_end         : signal is "TRUE";
//    --attribute KEEP of mem_rd_data_valid       : signal is "TRUE";
//    --attribute KEEP of mem_rdy                 : signal is "TRUE";
//    --attribute KEEP of mem_wdf_rdy             : signal is "TRUE";
//    --attribute KEEP of mem_init_calib_complete : signal is "TRUE";
//    --attribute KEEP of temp                    : signal is "TRUE";

//------------------------------------------------------------------------
//-- Module Implementation
//------------------------------------------------------------------------

//    ------------------------------------------------------------------------
//    -- Registering all inputs (BUS INTERFACING)
//    ------------------------------------------------------------------------

bus_sync_sf #(.impl(2), .sword(27+16+5)) registering_inputs(.CLK1(CLK), .CLK2(mem_ui_clk), .RST(rstn), 
	.data_in({ram_a,ram_dq_i,ram_cen,ram_oen,ram_wen,ram_ub,ram_lb}), 
	.data_out({ram_a_int,ram_dq_i_int,ram_cen_int,ram_oen_int,ram_wen_int,ram_ub_int,ram_lb_int}));
    /*always @(posedge mem_ui_clk) 
    begin : REG_IN
        ram_a_int <= ram_a;
        ram_dq_i_int <= ram_dq_i;
        ram_cen_int <= ram_cen;
        ram_oen_int <= ram_oen;
        ram_wen_int <= ram_wen;
        ram_ub_int <= ram_ub;
        ram_lb_int <= ram_lb;
    end*/
    
//    ------------------------------------------------------------------------
//    -- DDR controller instance
//    ------------------------------------------------------------------------
    ddr Inst_DDR (
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
      .sys_clk_i            (clk_200MHz_i),
      .sys_rst              (rstn),
      //-- user interface signals
      .app_addr             (mem_addr),
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
      .app_wdf_rdy          (mem_wdf_rdy),
      .app_sr_req           (1'b0),
      //.app_sr_active        (open),
      .app_ref_req          (1'b0),
      //.app_ref_ack          (open),
      .app_zq_req           (1'b0),
     // .app_zq_ack           (open),
      .ui_clk               (mem_ui_clk),
      .ui_clk_sync_rst      (mem_ui_rst),
      .device_temp_i        (device_temp_i),
      .init_calib_complete  (mem_init_calib_complete)); 
    assign rstn = ~rst_i;
    assign rst = rst_i | mem_ui_rst;
	
	// ------------------------------------------------------------------------
	// -- State Machine
	// ------------------------------------------------------------------------
	// -- Synchronous process
	always @ (posedge mem_ui_clk)
	begin : SYNC_PROCESS
	 if (rst)
		cState <= stIdle;
	 else
		cState <= nState;
	end
	
	// -- State machine transitions
	always @ (cState, mem_init_calib_complete, mem_rdy, 
	mem_wdf_rdy, ram_cen_int, ram_oen_int, ram_wen_int)
	begin : NEXT_STATE_DECODE
	  nState <= cState;
	  case(cState)
		 stIdle: begin
			if(mem_init_calib_complete == 1'b1) //-- memory initialized
			   if(mem_rdy == 1'b1) //-- check for memory ready
				  if(mem_wdf_rdy == 1'b1) //-- write ready
					 if(ram_cen_int == 1'b0 && 
					 (ram_oen_int == 1'b0 || ram_wen_int == 1'b0))
						nState <= stSetCmd;
		 end 
		 stSetCmd: begin
			nState <= stCheckRdy;
			end
		 stCheckRdy: begin //-- check for memory ready
			if(mem_rdy == 1'b0)
			   nState <= stWaitRdy;
			else
			   nState <= stWaitCen;
			end
		 stWaitRdy: begin
			if(mem_rdy == 1'b1) //-- wait for memory ready
			   nState <= stWaitCen;
			end
		 stWaitCen: begin
			if(ram_cen_int == 1'b1)
			   nState <= stIdle;
			end 
		 default: begin
			nState <= stIdle;
			end
	  endcase    
	end
	
//------------------------------------------------------------------------
//-- Memory control signals
//------------------------------------------------------------------------
   always @ (posedge mem_ui_clk)
   begin : MEM_CTL
		 if(rst) begin
			mem_wdf_wren <= 1'b0;
            mem_wdf_end <= 1'b0;
            mem_en <= 1'b0;
			mem_cmd <= 0;
         end else if(cState == stIdle || cState == stWaitCen) begin
            mem_wdf_wren <= 1'b0;
            mem_wdf_end <= 1'b0;
            mem_en <= 1'b0;
         end else if(cState == stSetCmd) begin
            //-- ui command
            if(ram_wen_int == 1'b0) begin //-- write
               mem_cmd <= CMD_WRITE;
               mem_wdf_wren <= 1'b1;
               mem_wdf_end <= 1'b1;
               mem_en <= 1'b1;
            end else if(ram_oen_int == 1'b0) begin //-- read
               mem_cmd <= CMD_READ;
               mem_en <= 1'b1;
            end
         end
   end
   
//------------------------------------------------------------------------
//-- Address decoder that forms the data mask
//------------------------------------------------------------------------
   always @ (posedge mem_ui_clk)
   begin : WR_DATA_MSK
		 if(rst) begin
			mem_wdf_mask <= 0;
         end else if(cState == stCheckRdy) begin
            case(ram_a_int[2:1])
               2'b00: begin
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     mem_wdf_mask <= 8'b11111101;
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     mem_wdf_mask <= 8'b11111110;
                  else //-- 16-bit
                     mem_wdf_mask <= 8'b11111100;
                  end
               2'b01: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     mem_wdf_mask <= 8'b11110111;
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     mem_wdf_mask <= 8'b11111011;
                  else //-- 16-bit
                     mem_wdf_mask <= 8'b11110011;
                  end
               2'b10: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     mem_wdf_mask <= 8'b11011111;
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     mem_wdf_mask <= 8'b11101111;
                  else //-- 16-bit
                     mem_wdf_mask <= 8'b11001111;
                  end
               2'b11: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     mem_wdf_mask <= 8'b01111111;
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     mem_wdf_mask <= 8'b10111111;
                  else //-- 16-bit
                     mem_wdf_mask <= 8'b00111111;
                  end
               default: begin end
            endcase
         end
   end
   
//------------------------------------------------------------------------
//-- Write data && address
//------------------------------------------------------------------------
   always @ (posedge mem_ui_clk)
   begin : WR_DATA_ADDR
		 if(rst) begin
			mem_wdf_data <= 0;
            mem_addr <= 0;
         end else if(cState == stCheckRdy) begin
            mem_wdf_data <= {ram_dq_i_int, ram_dq_i_int, 
                            ram_dq_i_int, ram_dq_i_int};
            mem_addr <= {ram_a_int[26:3], 3'b000};
         end 
   end

//------------------------------------------------------------------------
//-- Mask the data output
//------------------------------------------------------------------------
//-- delay stage for the valid && end signals (for an even better 
//-- synchronization)
   always @ (posedge mem_ui_clk)
   begin
         rd_vld <= mem_rd_data_valid;
         rd_end <= mem_rd_data_end;
         rd_data_1 <= mem_rd_data;
         rd_data_2 <= rd_data_1;
   end

   always @ (posedge mem_ui_clk)
   begin
         if(rst == 1'b1) begin
            ram_dq_o_int <= 0;
         end else if(cState == stWaitCen && rd_vld == 1'b1 && rd_end == 1'b1) begin
            case(ram_a_int[2:1])
               2'b00: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     ram_dq_o_int <= {rd_data_2[15:8], 
                                 rd_data_2[15:8]};
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     ram_dq_o_int <= {rd_data_2[7:0], 
                                 rd_data_2[7:0]};
                  else //-- 16-bit
                     ram_dq_o_int <= rd_data_2[15:0];
                  end 
               2'b01: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     ram_dq_o_int <= {rd_data_2[31:24], 
                                 rd_data_2[31:24]};
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     ram_dq_o_int <= {rd_data_2[23:16],
                                 rd_data_2[23:16]};
                  else //-- 16-bit
                     ram_dq_o_int <= rd_data_2[31:16];
                  end 
               2'b10: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     ram_dq_o_int <= {rd_data_2[47:40], 
                                 rd_data_2[47:40]};
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     ram_dq_o_int <= {rd_data_2[39:32], 
                                 rd_data_2[39:32]};
                  else //-- 16-bit
                     ram_dq_o_int <= rd_data_2[47:32];
                  end
               2'b11: begin 
                  if(ram_ub_int == 1'b0 && ram_lb_int == 1'b1) //-- UB
                     ram_dq_o_int <= {rd_data_2[63:56], 
                                 rd_data_2[63:56]};
                  else if(ram_ub_int == 1'b1 && ram_lb_int == 1'b0) //-- LB
                     ram_dq_o_int <= {rd_data_2[55:48], 
                                 rd_data_2[55:48]};
                  else //-- 16-bit
                     ram_dq_o_int <= rd_data_2[63:48];
                  end 
               default: begin end
            endcase
         end 
   end
   
   bus_sync_sf #(.impl(2), .sword(16)) registering_outputs(.CLK1(mem_ui_clk), .CLK2(CLK), .RST(rstn), 
	.data_in(ram_dq_o_int), 
	.data_out(ram_dq_o));
   
   // DDR ready determination
   assign ddr2_ready = (mem_init_calib_complete && mem_rdy && mem_wdf_rdy);
	   
endmodule
