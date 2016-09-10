`timescale 1ns / 1ps

//  Xilinx Single Port Write First RAM
//  This code implements a parameterizable single-port write-first memory where when data
//  is written to the memory, the output reflects the same data being written to the memory.
//  If the output data is not needed during writes or the last read value is desired to be
//  it is suggested to use a No Change as it is more power efficient.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.
//  Modify the parameters for the desired RAM characteristics.

module xilinx_single_port_ram_write_first #(
  parameter RAM_WIDTH = 32,                       // Specify RAM data width
  parameter RAM_DEPTH = 1024,                     // Specify RAM depth (number of entries) 
  parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // RAM input data
  input clka,                           // Clock
  input wea,                            // Write enable
  input ena,                            // RAM Enable, for additional power savings, disable port when not in use
  output [RAM_WIDTH-1:0] douta          // RAM output data
);

  reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
  reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clka)
    if (!ena)
      if (!wea) begin
        BRAM[addra] <= dina; 
        ram_data <= dina;
      end else
        ram_data <= BRAM[addra];        

  assign douta = ram_data;

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule

module SP32B1024 (
   output [31:0] Q,
   input CLK,
   input CEN,
   input WEN,
   input [9:0] A,
   input [31:0] D
);


  xilinx_single_port_ram_write_first #(
    .RAM_WIDTH(32),                       // Specify RAM data width
    .RAM_DEPTH(1024),                     // Specify RAM depth (number of entries)
    .INIT_FILE("")                        // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) your_instance_name (
    .addra(A),     // Address bus, width determined from RAM_DEPTH
    .dina(D),       // RAM input data, width determined from RAM_WIDTH
    .clka(CLK),       // Clock
    .wea(WEN),         // Write enable
    .ena(CEN),         // RAM Enable, for additional power savings, disable port when not in use
     .douta(Q)      // RAM output data, width determined from RAM_WIDTH
  );

endmodule

