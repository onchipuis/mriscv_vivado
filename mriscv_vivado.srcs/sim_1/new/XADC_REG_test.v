`timescale 1ps / 1ps

module XADC_REG_test (
);

reg     DCLK = 1'b0;
reg     RESET;
wire [3:0] VAUXP; 
wire [3:0] VAUXN; // Auxiliary analog channel inputs
wire VP; 
wire VN; // Dedicated and Hardwired Analog Input Pair
wire [15:0] MEASURED_TEMP; 
wire [15:0] MEASURED_VCCINT;
wire [15:0] MEASURED_VCCAUX; 
wire [15:0] MEASURED_VCCBRAM;
wire [15:0] MEASURED_AUX0; 
wire [15:0] MEASURED_AUX1;
wire [15:0] MEASURED_AUX2; 
wire [15:0] MEASURED_AUX3;
wire [7:0] ALM;
wire [4:0] CHANNEL;
wire OT;
wire XADC_EOC;
wire XADC_EOS;

XADC_REG XADC_REG_inst (
	.DCLK(DCLK), // Clock input for DRP
	.RESET(RESET),
	.VAUXP(VAUXP), 
	.VAUXN(VAUXN), // Auxiliary analog channel inputs
	.VP(VP), 
	.VN(VN),
	.MEASURED_TEMP(MEASURED_TEMP), 
	.MEASURED_VCCINT(MEASURED_VCCINT),
	.MEASURED_VCCAUX(MEASURED_VCCAUX), 
	.MEASURED_VCCBRAM(MEASURED_VCCBRAM),
	.MEASURED_AUX0(MEASURED_AUX0), 
	.MEASURED_AUX1(MEASURED_AUX1),
	.MEASURED_AUX2(MEASURED_AUX2), 
	.MEASURED_AUX3(MEASURED_AUX3),
	.ALM(ALM),
	.CHANNEL(CHANNEL),
	.OT(OT),
	.XADC_EOC(XADC_EOC),
	.XADC_EOS(XADC_EOS)
);

assign VP = 0;
assign VN = 1;
assign VAUXP = 0;
assign VAUXN = 0;

integer PERIOD = 5000 ;

always
begin #(PERIOD/2) DCLK = ~DCLK; end 

initial begin
	DCLK     = 1'b0;
	RESET     = 1'b1;
	#101000;
	RESET     = 1'b0;
	
	#60000000;
	
	$finish;
end

endmodule
