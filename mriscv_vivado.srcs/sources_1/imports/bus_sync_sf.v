// CLOCK DOMAIN SYNC BY CKDUR
`timescale 1ns/1ns

module bus_sync_sf #
(
	// 0 F1 > F2, 1 F1 < F2, 2 Double FF, 3 Flag, 4 bypass
	parameter impl = 0,
	// Numbits
	parameter sword = 32
)
(
	input CLK1,
	input CLK2,
	input RST,
	input [sword-1:0] data_in,
	output [sword-1:0] data_out
);

genvar i;
generate
	if (impl == 1) begin
		wire NCLK2;
		assign NCLK2 = ~CLK2;
		reg ECLK1, EECLK1;
		always @(posedge NCLK2 or negedge RST) begin
			if(RST == 1'b0) begin
				ECLK1 <= 1'b0;
				EECLK1 <= 1'b0;
			end else begin
				ECLK1 <= CLK1;
				EECLK1 <= ECLK1;
			end
		end
		reg [sword-1:0] reg_data1;
		reg [sword-1:0] reg_data2;
		reg [sword-1:0] reg_data3;
		always @(posedge CLK1 or negedge RST) begin
			if(RST == 1'b0) begin
				reg_data1 <= {sword{1'b0}};
			end else begin
				reg_data1 <= data_in;
			end
		end
		always @(posedge CLK2 or negedge RST) begin
			if(RST == 1'b0) begin
				reg_data2 <= {sword{1'b0}};
				reg_data3 <= {sword{1'b0}};
			end else begin
				if(EECLK1) begin
					reg_data2 <= reg_data1;
				end
				reg_data3 <= reg_data2;
			end
		end
		assign data_out = reg_data3;
	end else if(impl == 0) begin
		wire NCLK1;
		assign NCLK1 = ~CLK1;
		reg ECLK2, EECLK2;
		always @(posedge NCLK1 or negedge RST) begin
			if(RST == 1'b0) begin
				ECLK2 <= 1'b0;
				EECLK2 <= 1'b0;
			end else begin
				ECLK2 <= CLK2;
				EECLK2 <= ECLK2;
			end
		end
		reg [sword-1:0] reg_data1;
		reg [sword-1:0] reg_data2;
		reg [sword-1:0] reg_data3;
		always @(posedge CLK1 or negedge RST) begin
			if(RST == 1'b0) begin
				reg_data1 <= {sword{1'b0}};
				reg_data2 <= {sword{1'b0}};
			end else begin
				reg_data1 <= data_in;
				if(EECLK2) begin
					reg_data2 <= reg_data1;
				end
			end
		end
		always @(posedge CLK2 or negedge RST) begin
			if(RST == 1'b0) begin
				reg_data3 <= {sword{1'b0}};
			end else begin
				reg_data3 <= reg_data2;
			end
		end
		assign data_out = reg_data3;
	end else if(impl == 2) begin
        reg [sword-1:0] reg_data1;
        reg [sword-1:0] reg_data2;
        always @(posedge CLK2 or negedge RST) begin
            if(RST == 1'b0) begin
                reg_data1 <= {sword{1'b0}};
                reg_data2 <= {sword{1'b0}};
            end else begin
                reg_data1 <= data_in;
                reg_data2 <= reg_data1;
            end
        end
        assign data_out = reg_data2;
	end else if(impl == 3) begin
		reg [sword-1:0] FlagToggle_clkA;
		reg [2:0] SyncA_clkB [sword-1:0];
		
		for(i = 0; i < sword; i = i+1) begin
			// this changes level when the FlagIn_clkA is seen in clkA
			always @(posedge CLK1 or negedge RST) 
			if(RST == 1'b0) FlagToggle_clkA[i] <= 1'b0;
			else FlagToggle_clkA[i] <= FlagToggle_clkA[i] ^ data_in[i];
			// which can then be sync-ed to clkB
			always @(posedge CLK2 or negedge RST)  
			if(RST == 1'b0) SyncA_clkB[i] <= 0;
			else SyncA_clkB[i] <= {SyncA_clkB[i][1:0], FlagToggle_clkA[i]};
			// and recreate the flag in clkB
			assign data_out[i] = (SyncA_clkB[i][2] ^ SyncA_clkB[i][1]);
		end
	end else if(impl == 4) begin
		assign data_out = data_in;
	end
endgenerate

endmodule
