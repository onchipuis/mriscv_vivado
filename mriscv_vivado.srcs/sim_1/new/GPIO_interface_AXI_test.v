`timescale 1ps / 1ps

module GPIO_interface_AXI_test (
);

// HELPER
function integer clogb2;
	input integer value;
	integer     i;
	begin
		clogb2 = 0;
		for(i = 0; 2**i < value; i = i + 1)
		clogb2 = i + 1;
	end
endfunction

localparam    tries = 4;
localparam    sword = 32;

localparam    impl = 0;
localparam    syncing = 0;

localparam		GPIO_PINS = 32;				// How many pins exists?
localparam		GPIO_PWM = 32;				// How many of the above support PWM?
localparam		GPIO_IRQ = 8;				// How many of the above support IRQ?
localparam		GPIO_TWO_PRESCALER = 1;		// Independent Prescaler PWM enabled?
localparam		PWM_PRESCALER_BITS = 16;	// How many bits is the prescaler? (Main frequency divisor)
localparam		PWM_BITS = 16;				// How many bits are the pwms?
localparam		UART_RX_BUFFER_BITS = 10;	// How many buffer?

// Autogen localparams

reg        CLK = 1'b0;
reg        RST;

reg [GPIO_PINS-1:0] GPIO_PinIn;		// Pin in data
wire [GPIO_PINS-1:0] GPIO_PinOut;		// Pin out data
wire [GPIO_PINS-1:0] GPIO_Rx;			// Pin enabled for reciving
wire [GPIO_PINS-1:0] GPIO_Tx;			// Pin enabled for transmitting
wire [GPIO_PINS-1:0] GPIO_Strength;		// Pin strength?
wire [GPIO_PINS-1:0] GPIO_Pulldown;		// Pin Pulldown resistor active
wire [GPIO_PINS-1:0] GPIO_Pullup;		// Pin Pullup resistor active
wire [GPIO_IRQ-1:0]  CORE_IRQ;

// AXI4-lite master memory interfaces

reg         	axi_awvalid;
wire        	axi_awready;
reg [sword-1:0] axi_awaddr;
reg [3-1:0]     axi_awprot;

reg         	axi_wvalid;
wire        	axi_wready;
reg [sword-1:0] axi_wdata;
reg [4-1:0]     axi_wstrb;

wire        	axi_bvalid;
reg         	axi_bready;

reg         	axi_arvalid;
wire        	axi_arready;
reg [sword-1:0] axi_araddr;
reg [3-1:0]     axi_arprot;

wire        	axi_rvalid;
reg         	axi_rready;
wire [sword-1:0] axi_rdata;
        
//integer     fd1, tmp1, ifstop;
integer PERIOD = 5000 ;
integer i, j, error;

GPIO_interface_AXI
inst_GPIO_interface_AXI (
	.CLK(CLK),
	.RST(RST),
	.axi_awvalid(axi_awvalid),
	.axi_awready(axi_awready),
	.axi_awaddr(axi_awaddr),
	.axi_awprot(axi_awprot),
	.axi_wvalid(axi_wvalid),
	.axi_wready(axi_wready),
	.axi_wdata(axi_wdata),
	.axi_wstrb(axi_wstrb),
	.axi_bvalid(axi_bvalid),
	.axi_bready(axi_bready),
	.axi_arvalid(axi_arvalid),
	.axi_arready(axi_arready),
	.axi_araddr(axi_araddr),
	.axi_arprot(axi_arprot),
	.axi_rvalid(axi_rvalid),
	.axi_rready(axi_rready),
	.axi_rdata(axi_rdata),
	.GPIO_PinIn(GPIO_PinIn),
	.GPIO_PinOut(GPIO_PinOut),
	.GPIO_Rx(GPIO_Rx),
	.GPIO_Tx(GPIO_Tx),
	.GPIO_Strength(GPIO_Strength),
	.GPIO_Pulldown(GPIO_Pulldown),
	.GPIO_Pullup(GPIO_Pullup),
	.CORE_IRQ(CORE_IRQ)
);

always
begin #(PERIOD/2) CLK = ~CLK; end 

task aexpect;
	input [sword-1:0] av, e;
	begin
	 if (av == e)
		$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. MATCH!", av, e);
	 else
	  begin
		$display ("TIME=%t." , $time, " Actual value of trans=%b, expected is %b. ERROR!", av, e);
		error = error + 1;
	  end
	end
endtask

reg [63:0] xorshift64_state = 64'd88172645463325252;

task xorshift64_next;
	begin
		// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
		xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
		xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
		xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
	end
endtask

task axi_write;
	input [sword-1:0] waddr, wdata;
	begin
		#(PERIOD*8);
		// WRITTING TEST
		axi_awvalid = 1'b1;
		axi_awaddr = waddr;
		#PERIOD;
		while(!axi_awready) begin
			#PERIOD; 
		end
		axi_awvalid = 1'b0;
		axi_wvalid = 1'b1;
		axi_wdata = wdata;
		#PERIOD;
		while(!axi_wready) begin
			#PERIOD; 
		end
		axi_wvalid = 1'b0;
		while(!axi_bvalid) begin
			#PERIOD; 
		end
		//axi_bready = 1'b1;
		#PERIOD; 
		axi_awvalid = 1'b0;
		axi_wvalid = 1'b0;
		//axi_bready = 1'b0;
	end
endtask

task axi_read;
	input [sword-1:0] raddr;
	begin
		// READING TEST
		#(PERIOD*8);
		axi_arvalid = 1'b1;
		axi_araddr = raddr;
		#PERIOD;
		while(!axi_arready) begin
			#PERIOD; 
		end
		axi_arvalid = 1'b0;
		while(!axi_rvalid) begin
			#PERIOD; 
		end
		//axi_rready = 1'b1;
		#PERIOD; 
		axi_arvalid = 1'b0;
		//axi_rready = 1'b0;
	end
endtask


initial begin
	//$sdf_annotate("AXI_SRAM.sdf",AXI_SRAM);
	CLK     = 1'b0;
	RST     = 1'b0;
	error = 0;
	axi_awvalid = 1'b0;
	axi_wvalid = 1'b0;
	axi_bready = 1'b1;
	axi_arvalid = 1'b0;
	axi_rready = 1'b1;
	axi_awaddr = {sword{1'b0}};
	axi_awprot = {3{1'b0}};
	axi_wdata = {sword{1'b0}};
	axi_wstrb = 4'b1111;
	axi_araddr = {sword{1'b0}};
	axi_arprot = {3{1'b0}};
	GPIO_PinIn = 0;
	GPIO_PinIn[1] = 1'b1;							// Uart Rx on 1
	#101000;
	RST     = 1'b1;
	
	axi_write((2*GPIO_PWM+ 1) << 2, 32'h00000000);		// Deactivate UART
	axi_write((2*GPIO_PWM+ 3) << 2, 32'h00000000);		// Deactivate PWMs
	
	
	// General GPIO tests
	for(i = 0; i < tries; i = i+1) begin
		// General GPIO Pullup test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+10) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_Pullup, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO Pulldown test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+ 9) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_Pulldown, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO Strength test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+ 8) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_Strength, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO Tx test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+ 7) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_Tx, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO Rx test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+ 6) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_Rx, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO Out test
		// What I write is what i get
		xorshift64_next;
		axi_write((2*GPIO_PWM+ 5) << 2, xorshift64_state[31:0]);
		aexpect(GPIO_PinOut, xorshift64_state[GPIO_PINS-1:0]);
		
		// General GPIO In test
		// What I get is what i put
		xorshift64_next;
		GPIO_PinIn = xorshift64_state[GPIO_PINS-1:0];
		axi_read((2*GPIO_PWM+ 2) << 2);
		aexpect(axi_rdata[GPIO_PINS-1:0], xorshift64_state[GPIO_PINS-1:0]);
	end
	
	// General UART test
	GPIO_PinIn[1] = 1'b1;							// Uart Rx on 1
	axi_write((2*GPIO_PWM+ 1) << 2, 32'h00000001);	// Activate UART, 9600 BPS
	axi_write((2*GPIO_PWM+ 6) << 2, 32'h00000002);	// Rx Pin 1 must be 1
	axi_write((2*GPIO_PWM+ 7) << 2, 32'h00000001);	// Tx Pin 0 must be 1
	
	for(i = 0; i < tries; i = i+1) begin
		// General GPIO Out test
		xorshift64_next;
		axi_write((2*GPIO_PWM+11) << 2, {24'd0, xorshift64_state[7:0]});
		
		// 104166667=1000000000000/9600
		for(j=0; j < (104166667/PERIOD*(12)); j = j+1) begin
			GPIO_PinIn[1] = GPIO_PinOut[0];
			#PERIOD;
		end
		
		axi_read((2*GPIO_PWM+11) << 2);
		aexpect(axi_rdata[7:0], xorshift64_state[7:0]);
	end
	
	// PWMs (Graphical)
	axi_write((2*GPIO_PWM+ 3) << 2, 32'hFFFFFFFF);	// Activate PWMs
	axi_write((2*GPIO_PWM+ 1) << 2, 32'h00000000);	// Deactivate UART
	axi_write((2*GPIO_PWM+ 6) << 2, 32'h00000000);	// Rx must be 0
	axi_write((2*GPIO_PWM+ 7) << 2, 32'hFFFFFFFF);	// Tx must be 1
	axi_write((2*GPIO_PWM+ 0) << 2, 32'h00000000);	// Main prescaler is 0
	for(i = 0; i < GPIO_PWM; i = i+1) begin
		xorshift64_next;
		axi_write(i << 2, {16'd0, xorshift64_state[15:0]});	// Partial prescaler is 0
		axi_write((GPIO_PWM+ i) << 2, 32'h00000000);	// Partial prescaler is 0
	end
	
	// Time for PWMs
	#(PERIOD*300000);
	
	$timeformat(-9,0,"ns",7);
	#(PERIOD*8); 
	if (error == 0)
		$display("All match");
	else
		$display("Mismatches = %d", error);
	
	$finish;
end
endmodule
