`timescale 1ns / 1ps


module AXI_SRAM(
      // Common
      input         CLK,                // system clock
	  input			CLK_200MHZ,
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
	assign clk_200MHz_i = CLK_200MHZ;
    //assign clk_200MHz_i = CLK;
    
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
	reg [3:0] wstrb;
    reg [1:0] wassert;
    reg rassert;
    
    // State-machine datapath logic control
	reg second;	// Writting second bit?
	reg [1:0] operation;	// 2 for intermediate step, 1 if writting, 0 if reading
	reg oper;		// Operation enabled
    
	// BEHAVIORAL
	
	// UB/LB assign
	assign ram_ub = ~(second?wstrb[3]:wstrb[1]);
	assign ram_lb = ~(second?wstrb[2]:wstrb[0]);
	
	// Mux for dq_i
	assign ram_dq_i = second?wdata[31:16]:wdata[15:0];
	
	// Demux for dq_o to rdata
	always @(posedge CLK)
    begin : DEMUX_DQ
        if(RST == 1'b0) begin
            axi_rdata <= 0;
        end else begin
			if(second && oper && operation == 2'b00)
				axi_rdata[31:16] <= ram_dq_o;
			
			if(!second && oper && operation == 2'b00)
				axi_rdata[15:0] <= ram_dq_o;
		end
	end
	
	// Address assign 
	assign ram_a = (operation[0]?({waddr[24:0],second, 1'b0}):({raddr[24:0],second, 1'b0}));
	
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
			wstrb <= 0;
            wassert <= 2'b00;
            rassert <= 1'b0;
        end else begin
            if(axi_bvalid) begin	// bvalid indicates wterm sig
                waddr <= waddr;
				wstrb <= wstrb;
                wassert[0] <= 1'b0;
            end else if(axi_awvalid) begin
                waddr <= axi_awaddr;
				wstrb <= axi_wstrb;
                wassert[0] <= 1'b1;
            end else begin
                waddr <= waddr;
				wstrb <= wstrb;
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
	
	// Operation-counter
	// Read operations are on 210ns, Write on 260ns
	// At 12Mhz (12.5ns) are Time/12.5 on limit
	localparam ROP = (12000/162) - 1;
	localparam WOP = 16'hFFFF;//(13000/162) - 1;
	localparam SOP = 8;
	reg [15:0] count;
	wire [15:0] limit;
	assign limit = operation[1]?SOP:(operation[0]?WOP:ROP);
	wire operend;
	assign operend = count>=limit?1'b1:1'b0;
	always @(posedge CLK)
    begin : OPER_COUNTER
        if(RST == 1'b0) begin
            count <= 0;
        end else begin
            if(oper) begin	// rvalid indicates rterm sig
                if(operend)
					count <= 0;
				else
					count <= count+1;
            end else begin
				count <= 0;
            end
        end
    end
	
	// MAIN STATE-MACHINE
	
	// Declare states
	parameter st0_nothing = 0, st1_wwait = 1, st2_rwait = 2, st3_wwait2 = 3, st4_rwait2 = 4, st5_wready = 5, st6_rready = 6, st7_winter = 7, st8_rinter = 8;
	
	reg [3:0] state;
	
	// Output depends only on the state
	always @ (state) begin
		case (state)
			st0_nothing: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b00;
				oper = 1'b0; 
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
			st1_wwait: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b01;
				oper = 1'b1;  
				ram_cen = 1'b0;	
				ram_oen = 1'b1;		
				ram_wen = 1'b0;	end
			st2_rwait: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b00;
				oper = 1'b1;  
				ram_cen = 1'b0;	
				ram_oen = 1'b0;		
				ram_wen = 1'b1;	end
			st3_wwait2: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b1;
				operation = 2'b01;
				oper = 1'b1;  
				ram_cen = 1'b0;	
				ram_oen = 1'b1;		
				ram_wen = 1'b0;	end
			st4_rwait2: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b1;
				operation = 2'b00;
				oper = 1'b1;  
				ram_cen = 1'b0;	
				ram_oen = 1'b0;		
				ram_wen = 1'b1;	end
			st5_wready: begin
				axi_bvalid = 1'b1;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b00;
				oper = 1'b0;  
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
			st6_rready: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b1;
				second = 1'b0;
				operation = 2'b00;
				oper = 1'b0;  
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
			st7_winter: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b10;
				oper = 1'b1;  
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
			st8_rinter: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b10;
				oper = 1'b1;  
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
			default: begin
				axi_bvalid = 1'b0;
				axi_rvalid = 1'b0;
				second = 1'b0;
				operation = 2'b00;
				oper = 1'b0;  
				ram_cen = 1'b1;	
				ram_oen = 1'b1;		
				ram_wen = 1'b1;	end
		endcase
	end
	
	// Determine the next state
	// TODO: Maybe we'll need to create mid-states because deactivating the enables for a short time
	always @ (posedge CLK) begin
		if (RST == 1'b0)
			state <= st0_nothing;
		else
			case (state)
				st0_nothing:
					if(wassert == 2'b11 && ddr2_ready)
						state <= st1_wwait;
					else if(rassert == 1'b1 && ddr2_ready)
						state <= st2_rwait;
					else
						state <= st0_nothing;
				st1_wwait:
					if (operend)
						state <= st7_winter;
					else
						state <= st1_wwait;
				st7_winter:
					if (ddr2_ready && operend)
						state <= st3_wwait2;
					else
						state <= st7_winter;
				st3_wwait2:
					if (operend)
						state <= st5_wready;
					else
						state <= st3_wwait2;
				st5_wready:
					if (axi_bready)
						state <= st0_nothing;
					else
						state <= st5_wready;
				st2_rwait:
					if (operend)
						state <= st8_rinter;
					else
						state <= st2_rwait;
				st8_rinter:
					if (ddr2_ready && operend)
						state <= st4_rwait2;
					else
						state <= st8_rinter;
				st4_rwait2:
					if (operend)
						state <= st6_rready;
					else
						state <= st4_rwait2;
				st6_rready:
					if (axi_rready)
						state <= st0_nothing;
					else
						state <= st6_rready;
				default:
					state <= st0_nothing;
			endcase
	end
    
    // RAM2DDR implementation
    ram2ddr ram2ddr_inst (
       // Input Ports - Single Bit
       .clk_200MHz_i        (clk_200MHz_i),     
	   .CLK					(CLK),
       .ram_cen             (ram_cen),          
       .ram_lb              (ram_lb),           
       .ram_oen             (ram_oen),          
       .ram_ub              (ram_ub),           
       .ram_wen             (ram_wen),          
       .rst_i               (rst_i),            
       // Input Ports - Busses
       .device_temp_i       (12'b000000000000),
       .ram_a               (ram_a[26:0]),      
       .ram_dq_i            (ram_dq_i[15:0]),  
	   .ddr2_ready			(ddr2_ready),
       // Output Ports - Single Bit
       .ddr2_cas_n          (ddr2_cas_n),       
       .ddr2_ras_n          (ddr2_ras_n),       
       .ddr2_we_n           (ddr2_we_n),        
       // Output Ports - Busses
       .ddr2_addr           (ddr2_addr[12:0]),  
       .ddr2_ba             (ddr2_ba[2:0]),     
       .ddr2_ck_n           (ddr2_ck_n[0:0]),   
       .ddr2_ck_p           (ddr2_ck_p[0:0]),   
       .ddr2_cke            (ddr2_cke[0:0]),    
       .ddr2_cs_n           (ddr2_cs_n[0:0]),   
       .ddr2_dm             (ddr2_dm[1:0]),     
       .ddr2_odt            (ddr2_odt[0:0]),    
       .ram_dq_o            (ram_dq_o[15:0]),   
       // InOut Ports - Single Bit
       // InOut Ports - Busses
       .ddr2_dq             (ddr2_dq[15:0]),    
       .ddr2_dqs_n          (ddr2_dqs_n[1:0]),  
       .ddr2_dqs_p          (ddr2_dqs_p[1:0])  
    );
endmodule
