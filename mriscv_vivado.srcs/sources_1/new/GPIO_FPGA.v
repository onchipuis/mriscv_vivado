`timescale 1ns / 1ps

/*
GPIO FPGA
*/

module GPIO_FPGA #
	(
	parameter			GPIO_PINS = 32				// How many pins exists?
	)
	(
	// General GPIO interface spec
	output [GPIO_PINS-1:0] GPIO_PinIn,		// Pin in data
	input  [GPIO_PINS-1:0] GPIO_PinOut,		// Pin out data
	input  [GPIO_PINS-1:0] GPIO_Rx,			// Pin enabled for reciving
	input  [GPIO_PINS-1:0] GPIO_Tx,			// Pin enabled for transmitting
	input  [GPIO_PINS-1:0] GPIO_Strength,	// Pin strength? (This is ignored)
	input  [GPIO_PINS-1:0] GPIO_Pulldown,	// Pin Pulldown resistor active (This is ignored)
	input  [GPIO_PINS-1:0] GPIO_Pullup,		// Pin Pullup resistor active (This is ignored)
	
	// FPGA GPIO
	inout [GPIO_PINS-1:0] GPIO_pin
	
	);

	genvar i;
	generate
		for(i = 0; i < GPIO_PINS; i=i+1) begin : GPIO_IMPL
			assign GPIO_pin[i] = GPIO_Tx[i]?GPIO_PinOut[i]:1'bZ;
			assign GPIO_PinIn[i] = GPIO_Rx[i]?GPIO_pin[i]:1'b0;
		end
	endgenerate
	
endmodule
