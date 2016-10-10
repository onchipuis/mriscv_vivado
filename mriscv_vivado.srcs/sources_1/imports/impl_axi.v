/*
mRISCV - picorv32 Artix-7 microcontroller version
MADE IN COLOMBIA

CKDUR inc. 2016. Copy as you wish.

This is a out-of-box version for Artix-7. Can be adaptable but
you need to re-adapt all the things.
*/

`timescale 1ns/1ns

module impl_axi( 
	// General
	input 			CLK_100MHZ,
	input 			RST,
	input 			RST_CLK,
	// Master 1 (picorv32_axi), trap thing, reset status
	output          trap,
	output PICORV_RST_ALL,
	output master_CEB,
	output master_SCLK,
	output master_DATA,
	output RST_N,
	// Master 2 (spi_axi_master), SPI Master Interface
	input 			spi_axi_master_CEB, 
	input 			spi_axi_master_SCLK, 
	input 			spi_axi_master_DATA, 
	output 			spi_axi_master_DOUT,
	// Slave 1 (AXI_SPI_ROM), S25FL128S SPI Interface
    output          ROM_CS,
	input           ROM_SDI,
	output          ROM_SDO,
	output          ROM_WP,
	output          ROM_HLD,
	//output          ROM_SCK,
    // Slave 2 (AXI_SRAM), DDR2 interface
    output [12:0]   ddr2_addr,
    output [2:0]    ddr2_ba,
    output          ddr2_ras_n,
    output          ddr2_cas_n,
    output          ddr2_we_n,
    output [0:0]    ddr2_ck_p,
    output [0:0]    ddr2_ck_n,
    output [0:0]    ddr2_cke,
    output [0:0]    ddr2_cs_n,
    output [1:0]    ddr2_dm,
    output [0:0]    ddr2_odt,
    inout  [15:0]   ddr2_dq,
    inout  [1:0]    ddr2_dqs_p,
    inout  [1:0]    ddr2_dqs_n,
	// Slave 3 (DAC_interface_AXI), DAC Interface
	output [11:0] 	DAC_data,
	// Slave 4 (ADC_interface_AXI), XADC Interface ANALOG pins
	//input           VP,
	//input           VN,
	//input [3:0]     VAUXP, 
    //input [3:0]     VAUXN,
	// Slave 5 (GPIO_interface_AXI), GPIO Control Pins, UART Hardware Control
	inout  [31:0] 	GPIO_pin,
	output 			UART_CTS,
	input 			UART_RTS,
	// Slave 6 (SEGMENT_interface_AXI), 7-segment full control pins
	output [7:0]    SEGMENT_AN,
	output [7:0]    SEGMENT_SEG,
	// Slave 7 (spi_axi_slave), SPI Slave Interface
	output 			spi_axi_slave_CEB, 
	output 			spi_axi_slave_SCLK, 
	output 			spi_axi_slave_DATA
	);
	
	wire CLK;
	wire CLK_64MHZ;
	wire CLK_200MHZ;
	assign CLK = CLK_64MHZ;
	wire RST_N;
	assign RST_N = ~RST;
	assign CLK_N = ~CLK;
	
	assign master_CEB = spi_axi_master_CEB;
	assign master_SCLK = spi_axi_master_SCLK;
	assign master_DATA = spi_axi_master_DATA;
	
    clk_wiz_0 clk_wiz_0_inst
     (
      // Clock in ports
      .clk_in1(CLK_100MHZ),
      // Clock out ports
      .clk_out1(CLK_200MHZ),
	  .clk_out2(CLK_64MHZ),
      // Status and control signals
      .reset(RST_CLK),
      .locked()
     );
	
	// Params
	localparam		GPIO_PINS = 32;				// How many pins exists?
	localparam		GPIO_PWM = 32;				// How many of the above support PWM?
	localparam		GPIO_IRQ = 8;				// How many of the above support IRQ?
	localparam		GPIO_TWO_PRESCALER = 1;		// Independent Prescaler PWM enabled?
	localparam		PWM_PRESCALER_BITS = 16;	// How many bits is the prescaler? (Main frequency divisor)
	localparam		PWM_BITS = 16;				// How many bits are the pwms?
	localparam		UART_RX_BUFFER_BITS = 10;	// How many buffer?
	
	// Internals
	wire PICORV_RST;				// Picorv RST
	wire PICORV_RST_ALL;
	assign PICORV_RST_ALL = PICORV_RST & RST;
	wire [31:0] irq;				// The IRQ
	wire [GPIO_IRQ-1:0] CORE_IRQ;	// IRQ from GPIO
	wire [GPIO_PINS-1:0] GPIO_PinIn;		// Pin in data
	wire [GPIO_PINS-1:0] GPIO_PinOut;		// Pin out data
	wire [GPIO_PINS-1:0] GPIO_Rx;			// Pin enabled for reciving
	wire [GPIO_PINS-1:0] GPIO_Tx;			// Pin enabled for transmitting
	wire [GPIO_PINS-1:0] GPIO_Strength;		// Pin strength?
	wire [GPIO_PINS-1:0] GPIO_Pulldown;		// Pin Pulldown resistor active
	wire [GPIO_PINS-1:0] GPIO_Pullup;		// Pin Pullup resistor active
	wire [31:0] PROGADDR_IRQ;
	genvar i;
	generate
		for(i = 0; i < GPIO_IRQ; i=i+1) begin : IRQ_ASSIGN_GPIO
			assign irq[i] = CORE_IRQ[i];
		end
		for(i = GPIO_IRQ; i < 32; i=i+1) begin : IRQ_ASSIGN_DUMMY
			assign irq[i] = 1'b0;
		end
	endgenerate
	
	// ALL-AXI and its distribution
	// MEMORY MAP SPEC
	
	// Information about slaves:
	// 0: AXI_SP32B1024. 4 MB (32MiB). 0x000003FF mask, 0x00000000 use. 0x00000000 - 0x000003FF
    // 1: SPI_ROM. 16 MB (128MiB). 0x00003FFF mask, 0x00010000 use. 0x00010000 - 0x00013FFF
	// 2: DDR2. 1GiB (8MB x 16 x 8 banks). Only supported 256MB. 0x7FFFFFFF mask, 0x80000000 use. 0x80000000 - 0xFFFFFFFF
	// 3: DAC. 4B (Just response by one dir). 0x00000001 mask, 0x00005000 use. 0x00005000 - 0x00005001
	// 4: XADC. 512B (7-bit lsh 2 dir). 0x000001FF mask, 0x00004000 use. 0x00004000 - 0x000041FF
	// 5: GPIO. 512B (PWM[32] + PWM[32] + 1 + 1 + 1 + 3 + 3 + 3 + 3 + 3 + 3 + 3 + 3 + 1 = 92. 128 << 2 = 512). 0x000001FF mask, 0x00004200 use. 0x00004200 - 0x000043FF
	// 6: SEGMENT. 32B (3-bit lsh 2 dir). 0x0000001F mask, 0x00004600 use. 0x00004600 - 0x0000461F
	// 7: SPIslave. 4B (Just response by one dir). 0x00000000 mask, 0x10000000 use. 0x10000000 - 0x10000000
	
	localparam sword = 32;
	localparam masters = 2;
	localparam slaves = 8;
	localparam [slaves*sword-1:0] addr_mask = {32'h00000000,32'h0000001F,32'h000001FF,32'h000001FF,32'h00000001,32'h7FFFFFFF,32'h00003FFF,32'h00000FFF};
	localparam [slaves*sword-1:0] addr_use  = {32'h10000000,32'h00004600,32'h00004200,32'h00004000,32'h00005000,32'h80000000,32'h00010000,32'h00000000};
	
	// AXI4-lite master memory interfaces

	wire [masters-1:0]       m_axi_awvalid;
	wire [masters-1:0]       m_axi_awready;
	wire [masters*sword-1:0] m_axi_awaddr;
	wire [masters*3-1:0]     m_axi_awprot;

	wire [masters-1:0]       m_axi_wvalid;
	wire [masters-1:0]       m_axi_wready;
	wire [masters*sword-1:0] m_axi_wdata;
	wire [masters*4-1:0]     m_axi_wstrb;

	wire [masters-1:0]       m_axi_bvalid;
	wire [masters-1:0]       m_axi_bready;

	wire [masters-1:0]       m_axi_arvalid;
	wire [masters-1:0]       m_axi_arready;
	wire [masters*sword-1:0] m_axi_araddr;
	wire [masters*3-1:0]     m_axi_arprot;

	wire [masters-1:0]       m_axi_rvalid;
	wire [masters-1:0]       m_axi_rready;
	wire [masters*sword-1:0] m_axi_rdata;

	// AXI4-lite slave memory interfaces

	wire [slaves-1:0]       s_axi_awvalid;
	wire [slaves-1:0]       s_axi_awready;
	wire [slaves*sword-1:0] s_axi_awaddr;
	wire [slaves*3-1:0]     s_axi_awprot;

	wire [slaves-1:0]       s_axi_wvalid;
	wire [slaves-1:0]       s_axi_wready;
	wire [slaves*sword-1:0] s_axi_wdata;
	wire [slaves*4-1:0]     s_axi_wstrb;

	wire [slaves-1:0]       s_axi_bvalid;
	wire [slaves-1:0]       s_axi_bready;

	wire [slaves-1:0]       s_axi_arvalid;
	wire [slaves-1:0]       s_axi_arready;
	wire [slaves*sword-1:0] s_axi_araddr;
	wire [slaves*3-1:0]     s_axi_arprot;

	wire [slaves-1:0]       s_axi_rvalid;
	wire [slaves-1:0]       s_axi_rready;
	wire [slaves*sword-1:0] s_axi_rdata;

	// THE CONCENTRATION

	wire [sword-1:0] m_axi_awaddr_o [0:masters-1];
	wire [3-1:0]     m_axi_awprot_o [0:masters-1];
	wire [sword-1:0] m_axi_wdata_o [0:masters-1];
	wire [4-1:0]     m_axi_wstrb_o [0:masters-1];
	wire [sword-1:0] m_axi_araddr_o [0:masters-1];
	wire [3-1:0]     m_axi_arprot_o [0:masters-1];
	wire [sword-1:0] m_axi_rdata_o [0:masters-1];
	wire [sword-1:0] s_axi_awaddr_o [0:slaves-1];
	wire [3-1:0]     s_axi_awprot_o [0:slaves-1];
	wire [sword-1:0] s_axi_wdata_o [0:slaves-1];
	wire [4-1:0]     s_axi_wstrb_o [0:slaves-1];
	wire [sword-1:0] s_axi_araddr_o [0:slaves-1];
	wire [3-1:0]     s_axi_arprot_o [0:slaves-1];
	wire [sword-1:0] s_axi_rdata_o [0:slaves-1];

	wire  [sword-1:0] addr_mask_o [0:slaves-1];
	wire  [sword-1:0] addr_use_o [0:slaves-1];
	genvar k;
	generate
		for(k = 0; k < masters; k=k+1) begin
			assign m_axi_awaddr[(k+1)*sword-1:k*sword] = m_axi_awaddr_o[k];
			assign m_axi_awprot[(k+1)*3-1:k*3] = m_axi_awprot_o[k];
			assign m_axi_wdata[(k+1)*sword-1:k*sword] = m_axi_wdata_o[k];
			assign m_axi_wstrb[(k+1)*4-1:k*4] = m_axi_wstrb_o[k];
			assign m_axi_araddr[(k+1)*sword-1:k*sword] = m_axi_araddr_o[k];
			assign m_axi_arprot[(k+1)*3-1:k*3] = m_axi_arprot_o[k];
			assign m_axi_rdata_o[k] = m_axi_rdata[(k+1)*sword-1:k*sword];
		end
		for(k = 0; k < slaves; k=k+1) begin
			assign s_axi_awaddr_o[k] = s_axi_awaddr[(k+1)*sword-1:k*sword];
			assign s_axi_awprot_o[k] = s_axi_awprot[(k+1)*3-1:k*3];
			assign s_axi_wdata_o[k] = s_axi_wdata[(k+1)*sword-1:k*sword];
			assign s_axi_wstrb_o[k] = s_axi_wstrb[(k+1)*4-1:k*4];
			assign s_axi_araddr_o[k] = s_axi_araddr[(k+1)*sword-1:k*sword];
			assign s_axi_arprot_o[k] = s_axi_arprot[(k+1)*3-1:k*3];
			assign addr_mask_o[k] = addr_mask[(k+1)*sword-1:k*sword];
			assign addr_use_o[k] = addr_use[(k+1)*sword-1:k*sword];
			assign s_axi_rdata[(k+1)*sword-1:k*sword] = s_axi_rdata_o[k];
		end
	endgenerate
	
	// Instances
	
	// AXI INTERCONNECT, axi4_interconnect
	axi4_interconnect inst_axi4_interconnect
	(
		.CLK		(CLK),
		.RST	(RST),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awprot(m_axi_awprot),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arprot(m_axi_arprot),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready),
		.m_axi_rdata(m_axi_rdata),
		.s_axi_awvalid(s_axi_awvalid),
		.s_axi_awready(s_axi_awready),
		.s_axi_awaddr(s_axi_awaddr),
		.s_axi_awprot(s_axi_awprot),
		.s_axi_wvalid(s_axi_wvalid),
		.s_axi_wready(s_axi_wready),
		.s_axi_wdata(s_axi_wdata),
		.s_axi_wstrb(s_axi_wstrb),
		.s_axi_bvalid(s_axi_bvalid),
		.s_axi_bready(s_axi_bready),
		.s_axi_arvalid(s_axi_arvalid),
		.s_axi_arready(s_axi_arready),
		.s_axi_araddr(s_axi_araddr),
		.s_axi_arprot(s_axi_arprot),
		.s_axi_rvalid(s_axi_rvalid),
		.s_axi_rready(s_axi_rready),
		.s_axi_rdata(s_axi_rdata)
	); 
	
	// Master 1, picorv32_axi
	picorv32_axi inst_picorv32_axi
	(
		.clk(CLK), 
		.resetn(PICORV_RST_ALL), 
		.trap(DUMMY),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.mem_axi_awvalid(m_axi_awvalid[0]),
		.mem_axi_awready(m_axi_awready[0]),
		.mem_axi_awaddr(m_axi_awaddr_o[0]),
		.mem_axi_awprot(m_axi_awprot_o[0]),
		.mem_axi_wvalid(m_axi_wvalid[0]),
		.mem_axi_wready(m_axi_wready[0]),
		.mem_axi_wdata(m_axi_wdata_o[0]),
		.mem_axi_wstrb(m_axi_wstrb_o[0]),
		.mem_axi_bvalid(m_axi_bvalid[0]),
		.mem_axi_bready(m_axi_bready[0]),
		.mem_axi_arvalid(m_axi_arvalid[0]),
		.mem_axi_arready(m_axi_arready[0]),
		.mem_axi_araddr(m_axi_araddr_o[0]),
		.mem_axi_arprot(m_axi_arprot_o[0]),
		.mem_axi_rvalid(m_axi_rvalid[0]),
		.mem_axi_rready(m_axi_rready[0]),
		.mem_axi_rdata(m_axi_rdata_o[0]),
		.irq(irq)
		//.eoi(DUMMY)
	);
	
	// Master 2, spi_axi_master
	spi_axi_master inst_spi_axi_master
	(
		.CEB(spi_axi_master_CEB), 
		.SCLK(spi_axi_master_SCLK), 
		.DATA(spi_axi_master_DATA), 
		.DOUT(spi_axi_master_DOUT), 
		.RST(RST), 
		.PICORV_RST(PICORV_RST), 
		.CLK(CLK), 
		.axi_awvalid(m_axi_awvalid[1]), 
		.axi_awready(m_axi_awready[1]), 
		.axi_awaddr(m_axi_awaddr_o[1]), 
		.axi_awprot(m_axi_awprot_o[1]), 
		.axi_wvalid(m_axi_wvalid[1]),
		.axi_wready(m_axi_wready[1]), 
		.axi_wdata(m_axi_wdata_o[1]), 
		.axi_wstrb(m_axi_wstrb_o[1]), 
		.axi_bvalid(m_axi_bvalid[1]), 
		.axi_bready(m_axi_bready[1]),
		.axi_arvalid(m_axi_arvalid[1]), 
		.axi_arready(m_axi_arready[1]), 
		.axi_araddr(m_axi_araddr_o[1]), 
		.axi_arprot(m_axi_arprot_o[1]), 
		.axi_rvalid(m_axi_rvalid[1]),
		.axi_rready(m_axi_rready[1]), 
		.axi_rdata(m_axi_rdata_o[1])
	);
	
	// Slave 1, AXI_SP32B1024
    wire  [31:0]     AXI_SP32B1024_D;
    wire  [31:0]     AXI_SP32B1024_Q;
    wire  [9:0]     AXI_SP32B1024_A;
    wire             AXI_SP32B1024_CEN;
    wire             AXI_SP32B1024_WEN;
    AXI_SP32B1024 inst_AXI_SP32B1024(
        .CLK(CLK),
        .RST(RST),
        .axi_awvalid(s_axi_awvalid[0]),
        .axi_awready(s_axi_awready[0]),
        .axi_awaddr(s_axi_awaddr_o[0]),
        .axi_awprot(s_axi_awprot_o[0]),
        .axi_wvalid(s_axi_wvalid[0]),
        .axi_wready(s_axi_wready[0]),
        .axi_wdata(s_axi_wdata_o[0]),
        .axi_wstrb(s_axi_wstrb_o[0]),
        .axi_bvalid(s_axi_bvalid[0]),
        .axi_bready(s_axi_bready[0]),
        .axi_arvalid(s_axi_arvalid[0]),
        .axi_arready(s_axi_arready[0]),
        .axi_araddr(s_axi_araddr_o[0]),
        .axi_arprot(s_axi_arprot_o[0]),
        .axi_rvalid(s_axi_rvalid[0]),
        .axi_rready(s_axi_rready[0]),
        .axi_rdata(s_axi_rdata_o[0]),
        .Q(AXI_SP32B1024_Q),
        .CEN(AXI_SP32B1024_CEN),
        .WEN(AXI_SP32B1024_WEN),
        .A(AXI_SP32B1024_A),
        .D(AXI_SP32B1024_D)
    );
    // THIS IS A STANDARD CELL! YOU IDIOT!
    SP32B1024 SP32B1024_INT(
    .Q        (AXI_SP32B1024_Q),
    .CLK    (CLK),
    .CEN    (AXI_SP32B1024_CEN),
    .WEN    (AXI_SP32B1024_WEN),
    .A        (AXI_SP32B1024_A),
    .D        (AXI_SP32B1024_D)
    );
	
	// Slave 1, AXI_SPI_ROM
	AXI_SPI_ROM inst_AXI_SPI_ROM(
		.CLK(CLK),
		.RST(RST),
		.axi_awvalid(s_axi_awvalid[1]),
		.axi_awready(s_axi_awready[1]),
		.axi_awaddr(s_axi_awaddr_o[1]),
		.axi_awprot(s_axi_awprot_o[1]),
		.axi_wvalid(s_axi_wvalid[1]),
		.axi_wready(s_axi_wready[1]),
		.axi_wdata(s_axi_wdata_o[1]),
		.axi_wstrb(s_axi_wstrb_o[1]),
		.axi_bvalid(s_axi_bvalid[1]),
		.axi_bready(s_axi_bready[1]),
		.axi_arvalid(s_axi_arvalid[1]),
		.axi_arready(s_axi_arready[1]),
		.axi_araddr(s_axi_araddr_o[1]),
		.axi_arprot(s_axi_arprot_o[1]),
		.axi_rvalid(s_axi_rvalid[1]),
		.axi_rready(s_axi_rready[1]),
		.axi_rdata(s_axi_rdata_o[1]),
		.ROM_CS(ROM_CS),
		.ROM_SDI(ROM_SDI),
		.ROM_SDO(ROM_SDO),
		.ROM_WP(ROM_WP),
		.ROM_HLD(ROM_HLD)//,
		//.ROM_SCK(ROM_SCK)
	);
	
	// Slave 2, AXI_SRAM
	AXI_DDR2_MIG inst_AXI_DDR2_MIG(
		.CLK(CLK),
		.CLK_200MHZ(CLK_200MHZ),
		.RST(RST),
		.axi_awvalid(s_axi_awvalid[2]),
		.axi_awready(s_axi_awready[2]),
		.axi_awaddr(s_axi_awaddr_o[2]),
		.axi_awprot(s_axi_awprot_o[2]),
		.axi_wvalid(s_axi_wvalid[2]),
		.axi_wready(s_axi_wready[2]),
		.axi_wdata(s_axi_wdata_o[2]),
		.axi_wstrb(s_axi_wstrb_o[2]),
		.axi_bvalid(s_axi_bvalid[2]),
		.axi_bready(s_axi_bready[2]),
		.axi_arvalid(s_axi_arvalid[2]),
		.axi_arready(s_axi_arready[2]),
		.axi_araddr(s_axi_araddr_o[2]),
		.axi_arprot(s_axi_arprot_o[2]),
		.axi_rvalid(s_axi_rvalid[2]),
		.axi_rready(s_axi_rready[2]),
		.axi_rdata(s_axi_rdata_o[2]),
        .ddr2_cas_n          (ddr2_cas_n),       
        .ddr2_ras_n          (ddr2_ras_n),       
        .ddr2_we_n           (ddr2_we_n), 
        .ddr2_addr           (ddr2_addr[12:0]),  
        .ddr2_ba             (ddr2_ba[2:0]),     
        .ddr2_ck_n           (ddr2_ck_n[0:0]),   
        .ddr2_ck_p           (ddr2_ck_p[0:0]),   
        .ddr2_cke            (ddr2_cke[0:0]),    
        .ddr2_cs_n           (ddr2_cs_n[0:0]),   
        .ddr2_dm             (ddr2_dm[1:0]),     
        .ddr2_odt            (ddr2_odt[0:0]),  
        .ddr2_dq             (ddr2_dq[15:0]),    
        .ddr2_dqs_n          (ddr2_dqs_n[1:0]),  
        .ddr2_dqs_p          (ddr2_dqs_p[1:0]) 
	);
	
	// Slave 3, DAC_interface_AXI
	DAC_interface_AXI inst_DAC_interface_AXI(
		.CLK(CLK),
		.RST(RST),
		.AWVALID(s_axi_awvalid[3]),
		.WVALID(s_axi_wvalid[3]),
		.BREADY(s_axi_bready[3]),
		.AWADDR(s_axi_awaddr_o[3]),
		.WDATA(s_axi_wdata_o[3]),
		.WSTRB(s_axi_wstrb_o[3]),
		.AWREADY(s_axi_awready[3]),
		.WREADY(s_axi_wready[3]),
		.BVALID(s_axi_bvalid[3]),
		.ARVALID(s_axi_arvalid[3]),
		.RREADY(s_axi_rready[3]),
		.ARREADY(s_axi_arready[3]),
		.RVALID(s_axi_rvalid[3]),
		.RDATA(s_axi_rdata_o[3]),
		.DATA(DAC_data)
	);
	
	//Slave 4, ADC_interface_AXI
	ADC_interface_AXI inst_ADC_interface_AXI(
		.CLK(CLK),
		.RST(RST),
		.axi_awvalid(s_axi_awvalid[4]),
		.axi_awready(s_axi_awready[4]),
		.axi_awaddr(s_axi_awaddr_o[4]),
		.axi_awprot(s_axi_awprot_o[4]),
		.axi_wvalid(s_axi_wvalid[4]),
		.axi_wready(s_axi_wready[4]),
		.axi_wdata(s_axi_wdata_o[4]),
		.axi_wstrb(s_axi_wstrb_o[4]),
		.axi_bvalid(s_axi_bvalid[4]),
		.axi_bready(s_axi_bready[4]),
		.axi_arvalid(s_axi_arvalid[4]),
		.axi_arready(s_axi_arready[4]),
		.axi_araddr(s_axi_araddr_o[4]),
		.axi_arprot(s_axi_arprot_o[4]),
		.axi_rvalid(s_axi_rvalid[4]),
		.axi_rready(s_axi_rready[4]),
		.axi_rdata(s_axi_rdata_o[4])/*,
        .VP(0), 
        .VN(0),
        .VAUXN (VAUXN),
        .VAUXP (VAUXP)*/
	);
	
	//Slave 5, completogpio
	GPIO_interface_AXI inst_GPIO_interface_AXI (
		.CLK(CLK),
		.RST(RST),
		.axi_awvalid(s_axi_awvalid[5]),
		.axi_awready(s_axi_awready[5]),
		.axi_awaddr(s_axi_awaddr_o[5]),
		.axi_awprot(s_axi_awprot_o[5]),
		.axi_wvalid(s_axi_wvalid[5]),
		.axi_wready(s_axi_wready[5]),
		.axi_wdata(s_axi_wdata_o[5]),
		.axi_wstrb(s_axi_wstrb_o[5]),
		.axi_bvalid(s_axi_bvalid[5]),
		.axi_bready(s_axi_bready[5]),
		.axi_arvalid(s_axi_arvalid[5]),
		.axi_arready(s_axi_arready[5]),
		.axi_araddr(s_axi_araddr_o[5]),
		.axi_arprot(s_axi_arprot_o[5]),
		.axi_rvalid(s_axi_rvalid[5]),
		.axi_rready(s_axi_rready[5]),
		.axi_rdata(s_axi_rdata_o[5]),
		.GPIO_PinIn(GPIO_PinIn),
		.GPIO_PinOut(GPIO_PinOut),
		.GPIO_Rx(GPIO_Rx),
		.GPIO_Tx(GPIO_Tx),
		.GPIO_Strength(GPIO_Strength),
		.GPIO_Pulldown(GPIO_Pulldown),
		.GPIO_Pullup(GPIO_Pullup),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.CORE_IRQ(CORE_IRQ)
	);
	
	SEGMENT_interface_AXI inst_SEGMENT_interface_AXI
	(
		.CLK(CLK),
		.RST(RST),
		.axi_awvalid(s_axi_awvalid[6]),
		.axi_awready(s_axi_awready[6]),
		.axi_awaddr(s_axi_awaddr_o[6]),
		.axi_awprot(s_axi_awprot_o[6]),
		.axi_wvalid(s_axi_wvalid[6]),
		.axi_wready(s_axi_wready[6]),
		.axi_wdata(s_axi_wdata_o[6]),
		.axi_wstrb(s_axi_wstrb_o[6]),
		.axi_bvalid(s_axi_bvalid[6]),
		.axi_bready(s_axi_bready[6]),
		.axi_arvalid(s_axi_arvalid[6]),
		.axi_arready(s_axi_arready[6]),
		.axi_araddr(s_axi_araddr_o[6]),
		.axi_arprot(s_axi_arprot_o[6]),
		.axi_rvalid(s_axi_rvalid[6]),
		.axi_rready(s_axi_rready[6]),
		.axi_rdata(s_axi_rdata_o[6]),
		.SEGMENT_AN(SEGMENT_AN), 
		.SEGMENT_SEG(SEGMENT_SEG)
	);
	
	// Slave 7, spi_axi_slave
	spi_axi_slave inst_spi_axi_slave
	(
		.CEB(spi_axi_slave_CEB), 
		.SCLK(spi_axi_slave_SCLK), 
		.DATA(spi_axi_slave_DATA), 
		.RST(RST), 
		.CLK(CLK), 
		.axi_awvalid(s_axi_awvalid[7]), 
		.axi_awready(s_axi_awready[7]), 
		.axi_awaddr(s_axi_awaddr_o[7]), 
		.axi_awprot(s_axi_awprot_o[7]), 
		.axi_wvalid(s_axi_wvalid[7]),
		.axi_wready(s_axi_wready[7]), 
		.axi_wdata(s_axi_wdata_o[7]), 
		.axi_wstrb(s_axi_wstrb_o[7]), 
		.axi_bvalid(s_axi_bvalid[7]), 
		.axi_bready(s_axi_bready[7]),
		.axi_arvalid(s_axi_arvalid[7]), 
		.axi_arready(s_axi_arready[7]), 
		.axi_araddr(s_axi_araddr_o[7]), 
		.axi_arprot(s_axi_arprot_o[7]), 
		.axi_rvalid(s_axi_rvalid[7]),
		.axi_rready(s_axi_rready[7]), 
		.axi_rdata(s_axi_rdata_o[7])
	);
	
	// FPGA
	assign UART_CTS = UART_RTS;
	
	GPIO_FPGA inst_GPIO_FPGA
	(
		.GPIO_PinIn(GPIO_PinIn),
		.GPIO_PinOut(GPIO_PinOut),
		.GPIO_Rx(GPIO_Rx),
		.GPIO_Tx(GPIO_Tx),
		.GPIO_Strength(GPIO_Strength),
		.GPIO_Pulldown(GPIO_Pulldown),
		.GPIO_Pullup(GPIO_Pullup),
		.GPIO_pin(GPIO_pin)
	);
	
	/*ila_0 ila_0_inst (
    .clk(CLK),
	.probe0(m_axi_awvalid[0]),
	.probe1(m_axi_awready[0]),
	.probe2(m_axi_awaddr_o[0]),
	.probe3(m_axi_awprot_o[0]),
	.probe4(m_axi_wvalid[0]),
	.probe5(m_axi_wready[0]),
	.probe6(m_axi_wdata_o[0]),
	.probe7(m_axi_wstrb_o[0]),
	.probe8(m_axi_bvalid[0]),
	.probe9(m_axi_bready[0]),
	.probe10(m_axi_arvalid[0]),
	.probe11(m_axi_arready[0]),
	.probe12(m_axi_araddr_o[0]),
	.probe13(m_axi_arprot_o[0]),
	.probe14(m_axi_rvalid[0]),
	.probe15(m_axi_rready[0]),
	.probe16(m_axi_rdata_o[0]),
	.probe17(m_axi_awvalid[1]), 
	.probe18(m_axi_awready[1]), 
	.probe19(m_axi_awaddr_o[1]), 
	.probe20(m_axi_awprot_o[1]), 
	.probe21(m_axi_wvalid[1]),
	.probe22(m_axi_wready[1]), 
	.probe23(m_axi_wdata_o[1]), 
	.probe24(m_axi_wstrb_o[1]), 
	.probe25(m_axi_bvalid[1]), 
	.probe26(m_axi_bready[1]),
	.probe27(m_axi_arvalid[1]), 
	.probe28(m_axi_arready[1]), 
	.probe29(m_axi_araddr_o[1]), 
	.probe30(m_axi_arprot_o[1]), 
	.probe31(m_axi_rvalid[1]),
	.probe32(m_axi_rready[1]), 
	.probe33(m_axi_rdata_o[1]),
	.probe34(RST),
	.probe35(GPIO_PinIn),		// Pin in data
	.probe36(GPIO_PinOut),		// Pin out data
	.probe37(GPIO_Rx),			// Pin enabled for reciving
	.probe38(GPIO_Tx),			// Pin enabled for transmitting
	.probe39(GPIO_Strength),		// Pin strength?
	.probe40(GPIO_Pulldown),		// Pin Pulldown resistor active
	.probe41(GPIO_Pullup),		// Pin Pullup resistor active
	.probe42(PROGADDR_IRQ)
    );*/
	
endmodule
