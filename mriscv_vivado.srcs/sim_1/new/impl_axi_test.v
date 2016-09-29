`timescale 1ps/1ps

module impl_axi_test();

// HELPER
	function integer clogb2;
		input integer value;
		integer 	i;
		begin
			clogb2 = 0;
			for(i = 0; 2**i < value; i = i + 1)
			clogb2 = i + 1;
		end
	endfunction
	
localparam	tries = 10;
localparam  sword = 32;	
localparam  masters = 2;
localparam  slaves = 7;

localparam	impl = 0;
localparam	syncing = 0;
localparam	max_wait = 1000000;

localparam  SIZE_FIRMWARE = 4194304;

localparam		GPIO_PINS = 32;				// How many pins exists?
localparam		GPIO_PWM = 32;				// How many of the above support PWM?
localparam		GPIO_IRQ = 8;				// How many of the above support IRQ?
localparam		GPIO_TWO_PRESCALER = 1;		// Independent Prescaler PWM enabled?
localparam		PWM_PRESCALER_BITS = 16;	// How many bits is the prescaler? (Main frequency divisor)
localparam		PWM_BITS = 16;				// How many bits are the pwms?
localparam		UART_RX_BUFFER_BITS = 10;	// How many buffer?

// Autogen localparams

reg 	CLK = 1'b0;
reg 	SCLK = 1'b0;
reg	 	RST;

reg  DATA;
wire DOUT;
reg  CEB;
wire [11:0] 	DAC_interface_AXI_DATA;
// DDR2 interface
wire          ROM_CS;
wire          ROM_SDI;
wire          ROM_SDO;
wire          ROM_WP;
wire          ROM_HLD;
wire          ROM_SCK;
// DDR2 interface
wire [12:0] ddr2_addr;
wire [2:0]  ddr2_ba;
wire        ddr2_ras_n;
wire        ddr2_cas_n;
wire        ddr2_we_n;
wire [0:0]  ddr2_ck_p;
wire [0:0]  ddr2_ck_n;
wire [0:0]  ddr2_cke;
wire [0:0]  ddr2_cs_n;
wire [1:0]  ddr2_dm;
wire [0:0]  ddr2_odt;
wire [15:0] ddr2_dq;
wire [1:0]  ddr2_dqs_p;
wire [1:0]  ddr2_dqs_n;
// GPIO
wire [GPIO_PINS-1:0]  GPIO_pin;
reg [GPIO_PINS-1:0]   GPIO_pin_act;
reg [GPIO_PINS-1:0]   GPIO_pins;
// 7-seg 
wire [7:0] SEGMENT_AN;
wire [7:0] SEGMENT_SEG;
// SPI slave
wire 			spi_axi_slave_CEB; 
wire 			spi_axi_slave_SCLK; 
wire 			spi_axi_slave_DATA;

localparam numbit_instr = 2;			// Nop (00), Read(01), Write(10)
localparam numbit_address = sword;
localparam numbit_handshake = numbit_instr+numbit_address+sword;

reg [numbit_handshake-1:0] handshake;
reg [sword-1:0] result;

// Data per capturing
reg [sword-1:0] cap;

reg stat;
reg stats;
reg is_o, is_ok;
reg waiting_ok;
integer waiting;
	
integer fd1, tmp1, ifstop;
integer PERIOD = 5000 ;
integer SPERIOD = 20000 ;
integer i, j, error, l;
	
	// Device under test
	impl_axi inst_impl_axi(
		// General
		.CLK(CLK),
		.RST(RST),
		.spi_axi_master_CEB(CEB), 
		.spi_axi_master_SCLK(SCLK), 
		.spi_axi_master_DATA(DATA), 
		.spi_axi_master_DOUT(DOUT),
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
		.ddr2_dqs_p          (ddr2_dqs_p[1:0]),
		.DAC_data			 (DAC_interface_AXI_DATA),
		.VP(0), 
		.VN(1),
		.GPIO_pin(GPIO_pin),
		.SEGMENT_AN(SEGMENT_AN), 
		.SEGMENT_SEG(SEGMENT_SEG),
		.spi_axi_slave_CEB(spi_axi_slave_CEB), 
		.spi_axi_slave_SCLK(spi_axi_slave_SCLK), 
		.spi_axi_slave_DATA(spi_axi_slave_DATA)
	);
	
	ddr2 inst_ddr2
	(
		.ck(ddr2_ck_p),
		.ck_n(ddr2_ck_n),
		.cke(ddr2_cke),
		.cs_n(ddr2_cs_n),
		.ras_n(ddr2_ras_n),
		.cas_n(ddr2_cas_n),
		.we_n(ddr2_we_n),
		.dm_rdqs(ddr2_dm),
		.ba(ddr2_ba),
		.addr(ddr2_addr),
		.dq(ddr2_dq),
		.dqs(ddr2_dqs_p),
		.dqs_n(ddr2_dqs_n),
		//.rdqs_n(open),
		.odt(ddr2_odt)
	);
	
	always
	begin #(SPERIOD/2) SCLK = ~SCLK; end 
	always
	begin #(PERIOD/2) CLK = ~CLK; end 
	
	task spi_write;
		input [sword-1:0] waddr, wdata;
		begin
			CEB = 1'b0;
			handshake = {2'b10,waddr,wdata};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#(SPERIOD*4);
			stat = 1'b1;
			// Wait the axi handshake, SPI-POV
			while(stat) begin
				CEB = 1'b0;
				DATA = 1'b0;
				#SPERIOD;
				DATA = 1'b0;
				#SPERIOD;		// SENT "SEND STATUS"
				for(j = 0; j < sword; j = j+1) begin
					result[sword-j-1] = DOUT;
					#SPERIOD;
				end
				CEB = 1'b1;
				#(SPERIOD*2);
				if(result[1] == 1'b0 && result[0] == 1'b0) begin	// CHECKING WBUSY AND BUSY
					stat = 1'b0;
				end
			end
			$display ("SPI: Written data %x = %x", waddr, wdata);
			#(SPERIOD*8);
		end
	endtask
	
	task spi_read;
		input [sword-1:0] raddr;
		begin
			CEB = 1'b0;
			handshake = {2'b01,raddr,32'h00000000};
			for(j = 0; j < numbit_handshake; j = j+1) begin
				DATA = handshake[numbit_handshake-j-1];
				#SPERIOD;
			end
			CEB = 1'b1;
			#(SPERIOD*3);
			stat = 1'b1;
			// Wait the axi handshake, SPI-POV
			while(stat) begin
				CEB = 1'b0;
				DATA = 1'b0;
				#SPERIOD;
				DATA = 1'b0;
				#SPERIOD;		// SENT "SEND STATUS"
				for(j = 0; j < sword; j = j+1) begin
					result[sword-j-1] = DOUT;
					#SPERIOD;
				end
				CEB = 1'b1;
				#(SPERIOD*3);
				if(result[2] == 1'b0 && result[0] == 1'b0) begin	// CHECKING RBUSY AND BUSY
					stat = 1'b0;
				end else begin
					$display ("SPI: Waiting reading to be done (%b) %x", result[2:0], raddr);
				end
			end
			CEB = 1'b0;
			DATA = 1'b1;
			#SPERIOD;
			DATA = 1'b1;
			#SPERIOD;		// SEND "SEND RDATA"
			for(j = 0; j < sword; j = j+1) begin
				result[sword-j-1] = DOUT;
				#SPERIOD;
			end
			CEB = 1'b1;
			$display ("SPI: Read data %x = %x", raddr, result);
			#(SPERIOD*8);
		end
	endtask
	
	task spi_picorv32_reset;
		input rst;
		begin
			// SENDING PICORV RESET
			CEB = 1'b0;
			DATA = 1'b0;
			#SPERIOD;
			DATA = 1'b0;
			#SPERIOD;		// SENT "SEND STATUS", but we ignore totally the result
			#(SPERIOD*(2*sword-1));
			DATA = rst;	// Send to the reset
			#SPERIOD;
			CEB = 1'b1;
			#(SPERIOD*4);
		end
	endtask
	
	// Task for expect something (helper)
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
	
	// Our pseudo-random generator
	reg [63:0] xorshift64_state = 64'd88172645463325252;
	task xorshift64_next;
		begin
			// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
			xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
		end
	endtask
	
	// Memory to write
	reg [31:0] memory [0:SIZE_FIRMWARE];
	initial $readmemh("firmware/firmware.hex", memory);
	
	genvar z;
	generate
		for(z = 0; z < GPIO_PINS; z=z+1) begin : GPIO_PIN_ASSIGN
			assign GPIO_pin[z] = GPIO_pin_act[z]?GPIO_pins[z]:1'bz;
		end
	endgenerate

	initial begin
		waiting = 0;
		waiting_ok = 1'b0;
		cap = {sword{1'b0}};
		is_o = 1'b0;
		is_ok = 1'b0;
		CEB		= 1'b1;
		CLK 	= 1'b0;
		SCLK 	= 1'b0;
		RST 	= 1'b0;
		DATA 	= 1'b0;
		stat = 1'b0;
		stats = 1'b0;
		GPIO_pin_act = 32'd0;
		GPIO_pins = 32'd0;
		error = 0;
		result = {sword{1'b0}};
		handshake = {numbit_handshake{1'b0}};
		#(SPERIOD*20);
		RST 	= 1'b1;
		#(SPERIOD*6);
		
		/*// SENDING PICORV RESET TO ZERO
		spi_picorv32_reset(1'b0);
		
		// WRITTING PROGRAM
		for(i = 0; i < SIZE_FIRMWARE; i = i+1) begin
			spi_write(i, memory[i]);
		end
		
		// SENDING PICORV RESET TO ONE
		spi_picorv32_reset(1'b1);
		
		$display ("TIME=%t.", $time, "SPI: Programmed all instructions, picorv32 activated!");
		$timeformat(-9,0,"ns",7);
		
		// Waiting picorv to finish (Remember to put OK)
		while(~waiting_ok) #SPERIOD;
		
		// DAC_interface_AXI
		$display("TIME=%t.", $time, "Doing the DAC_interface_AXI test");
		for(l = 0; l < tries; l = l + 1) begin
			CEB = 1'b0;
			// Making handshake, writting, DAC dir, at random data 
			spi_write(32'h00005000,xorshift64_state[31:0]);
			aexpect(DAC_interface_AXI_DATA, xorshift64_state[11:0]);
			
			#(SPERIOD*8);
			xorshift64_next;
		end
		
		// ADC_interface_AXI
		$display("TIME=%t." , $time, "Doing the ADC_interface_AXI test");
		for(i = 0; i < tries; i = i+1) begin
			spi_read((32'h00000000 << 2) | 32'h0004000);
			spi_read((32'h00000001 << 2) | 32'h0004000);
			spi_read((32'h00000002 << 2) | 32'h0004000);
			spi_read((32'h00000006 << 2) | 32'h0004000);
			spi_read((32'h00000010 << 2) | 32'h0004000);
			spi_read((32'h00000011 << 2) | 32'h0004000);
			spi_read((32'h00000012 << 2) | 32'h0004000);
			spi_read((32'h00000013 << 2) | 32'h0004000);
		end
		
		// GPIO_interface_AXI
		$display("TIME=%t." , $time, "Doing the GPIO_interface_AXI test");
		spi_write(((2*GPIO_PWM+ 1) << 2) | 32'h00004200, 32'h00000000);		// Deactivate UART
		spi_write(((2*GPIO_PWM+ 3) << 2) | 32'h00004200, 32'h00000000);		// Deactivate PWMs
		
		// General GPIO tests
		for(i = 0; i < tries; i = i+1) begin
			// General GPIO Pullup test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+10) << 2) | 32'h00004200, xorshift64_state[31:0]);
			//aexpect(GPIO_Pullup, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO Pulldown test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 9) << 2) | 32'h00004200, xorshift64_state[31:0]);
			//aexpect(GPIO_Pulldown, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO Strength test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 8) << 2) | 32'h00004200, xorshift64_state[31:0]);
			//aexpect(GPIO_Strength, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO Tx test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 7) << 2) | 32'h00004200, xorshift64_state[31:0]);
			//aexpect(GPIO_Tx, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO Rx test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 6) << 2) | 32'h00004200, xorshift64_state[31:0]);
			//aexpect(GPIO_Rx, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO Out test
			// What I write is what i get
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 7) << 2) | 32'h00004200, 32'hFFFFFFFF);	// Tx
			spi_write(((2*GPIO_PWM+ 6) << 2) | 32'h00004200, 32'h00000000);	// Rx
			GPIO_pin_act = 32'h00000000;
			spi_write(((2*GPIO_PWM+ 5) << 2) | 32'h00004200, xorshift64_state[31:0]);
			aexpect(GPIO_pin, xorshift64_state[GPIO_PINS-1:0]);
			
			// General GPIO In test
			// What I get is what i put
			xorshift64_next;
			spi_write(((2*GPIO_PWM+ 7) << 2) | 32'h00004200, 32'h00000000);	// Tx
			spi_write(((2*GPIO_PWM+ 6) << 2) | 32'h00004200, 32'hFFFFFFFF);	// Rx
			GPIO_pin_act = 32'hFFFFFFFF;
			GPIO_pins = xorshift64_state[GPIO_PINS-1:0];
			spi_read(((2*GPIO_PWM+ 2) << 2) | 32'h00004200);
			aexpect(result[GPIO_PINS-1:0], xorshift64_state[GPIO_PINS-1:0]);
		end
		
		// General UART test
		GPIO_pins[1] = 1'b1;							// Uart Rx on 1
		spi_write(((2*GPIO_PWM+ 1) << 2) | 32'h00004200, 32'h00000001);	// Activate UART, 9600 BPS
		spi_write(((2*GPIO_PWM+ 6) << 2) | 32'h00004200, 32'h00000002);	// Rx Pin 1 must be 1
		spi_write(((2*GPIO_PWM+ 7) << 2) | 32'h00004200, 32'h00000001);	// Tx Pin 0 must be 1
		GPIO_pin_act = 32'h00000001;
		
		for(i = 0; i < tries; i = i+1) begin
			// General GPIO Out test
			xorshift64_next;
			spi_write(((2*GPIO_PWM+11) << 2) | 32'h00004200, {24'd0, xorshift64_state[7:0]});
			
			// 104166667=1000000000000/9600
			for(j=0; j < (104166667/PERIOD*(12)); j = j+1) begin
				GPIO_pins[1] = GPIO_pin[0];
				#PERIOD;
			end
			
			spi_read(((2*GPIO_PWM+11) << 2) | 32'h00004200);
			aexpect(result[7:0], xorshift64_state[7:0]);
		end
		
		// PWMs (Graphical)
		spi_write(((2*GPIO_PWM+ 3) << 2) | 32'h00004200, 32'hFFFFFFFF);	// Activate PWMs
		spi_write(((2*GPIO_PWM+ 1) << 2) | 32'h00004200, 32'h00000000);	// Deactivate UART
		spi_write(((2*GPIO_PWM+ 6) << 2) | 32'h00004200, 32'h00000000);	// Rx must be 0
		spi_write(((2*GPIO_PWM+ 7) << 2) | 32'h00004200, 32'hFFFFFFFF);	// Tx must be 1
		spi_write(((2*GPIO_PWM+ 0) << 2) | 32'h00004200, 32'h00000000);	// Main prescaler is 0
		for(i = 0; i < GPIO_PWM; i = i+1) begin
			xorshift64_next;
			spi_write((i << 2) | 32'h00004200, {16'd0, xorshift64_state[15:0]});	// Partial prescaler is 0
			spi_write(((GPIO_PWM+ i) << 2) | 32'h00004200, 32'h00000000);	// Partial prescaler is 0
		end
		
		// Time for PWMs
		#(PERIOD*300000);
		
		// SEGMENT_interface_AXI
		$display("TIME=%t." , $time, "Doing the SEGMENT_interface_AXI test");
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "a"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "b"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "r"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "a"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "s"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "e"});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, "."});
		spi_write((32'h00000000 << 2) | 32'h00004600, {24'd0, " "});
		
		#(PERIOD*300000);
		*/
		if (error == 0)
			$display("All match");
		else
			$display("Mismatches = %d", error);
		$finish;
		//$stop;
		
	end
	
	// SPI AXI SLAVE interface simulation
	always @(posedge spi_axi_slave_SCLK) begin
		if(spi_axi_slave_CEB == 1'b0) begin
			stats <= 1'b1;
			cap <= {cap[sword-2:0], spi_axi_slave_DATA};
		end else if(stats == 1'b1) begin
			stats <= 1'b0;
			if(cap == 79 || (cap == 75 && is_o == 1'b1))
				is_o <= 1'b1;
			else
				is_o <= 1'b0;
			if(cap == 75 && is_o == 1'b1)
				is_ok <= 1'b1;
`ifdef VERBOSE
			if (32 <= cap && cap < 128)
				$display("OUT: '%c'", cap);
			else
				$display("OUT: %3d", cap);
`else
			$write("%c", cap);
			$fflush();
`endif
		end
	end
	
	// Waiting to end program
	always @(posedge SCLK) begin
		if(waiting_ok == 1'b0) begin
			if(is_ok == 1'b1) begin
	
				$display ("Program Suceed! Reseted the picorv");
			
				waiting_ok = 1'b1;
				#(SPERIOD*4);
			
			end else begin
				waiting = waiting + 1;
				if(waiting >= max_wait) begin
					waiting_ok = 1'b1;
					$display("TIMEOUT!, PLEASE DO NOT FORGET TO PUT 'OK' ON THE FIRMWARE");
					$finish;
				end
				xorshift64_next;
			end
		end 
	end

endmodule
