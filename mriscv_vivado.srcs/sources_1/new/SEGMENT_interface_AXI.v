`timescale 1ns / 1ps

module SEGMENT_interface_AXI #
	(
	parameter			PERIOD = 15625
	)
	(
//----general--input----
	input CLK,
	input RST,
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
	
	// Interface
	output reg [7:0]    SEGMENT_AN,
	output reg [7:0]    SEGMENT_SEG);
	
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
	
	localparam integer trefresh = 2e9;	// Refresh time in picoseconds / 8
	localparam integer count_end = (trefresh/PERIOD) - 1;
	localparam integer bits_count = 32;//clogb2(count_end)+1;
	
	reg [bits_count-1:0] count;
	wire enable_count;
	assign enable_count = count == count_end?1'b1:1'b0;
	
	always @(posedge CLK)
    begin : COUNT_READY_COUNTER
        if(RST == 1'b0) begin
            count <= 0;
        end else begin
            if(enable_count) begin	
                count <= 0;
			end else begin
                count <= count+1;
            end
        end
    end
	
	// AXI-4 Auxiliar
    reg [31:0] waddr, raddr;
    reg [31:0] wdata;
	reg [3:0] wstrb;
    reg [1:0] wassert;
    reg rassert;
	
	// AXI-4 immediate responses
    assign axi_awready = 1'b1;
    assign axi_arready = 1'b1;
    assign axi_wready = 1'b1;
	
	// AXI-4 Single shot response and saving
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
                wassert[0] <= 1'b0;
            end else if(axi_awvalid) begin
                waddr <= axi_awaddr;
                wassert[0] <= 1'b1;
            end else begin
                waddr <= waddr;
                wassert[0] <= wassert[0];
            end
            
            if(axi_bvalid) begin	// bvalid indicates wterm sig
                wdata <= wdata;
				wstrb <= wstrb;
                wassert[1] <= 1'b0;
            end else if(axi_wvalid) begin
                wdata <= axi_wdata;
				wstrb <= axi_wstrb;
                wassert[1] <= 1'b1;
            end else begin
                wdata <= wdata;
				wstrb <= wstrb;
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
	
	reg [7:0] regs [0:7];
	integer idx;
	reg [1:0] state;
	reg flag_erase;
	parameter st0_idle = 0, st1_waitrready = 1, st2_waitbready = 2;
	
	always @(posedge CLK)
	if (RST == 1'b0) begin
		state <= st0_idle;
		for(idx = 0; idx < 8; idx = idx + 1)
			regs[idx] <= 0;
		axi_bvalid <= 1'b0;
		axi_rvalid <= 1'b0;
		axi_rdata <= 0;
		flag_erase <= 1'b0;
	end	else case (state)
	st0_idle :
		if (rassert) begin
			axi_rdata <= {24'd0, regs[raddr[4:2]]};
			state <= st1_waitrready;
			axi_rvalid <= 1'b1;
		end	else if(wassert == 2'b11) begin
			if(waddr[4:2] == 3'h0 && wdata[7:0] == 8'h0A)
				flag_erase <= 1'b1;
			else if(waddr[4:2] == 3'h0 && wdata[7:0] >= 8'd32) begin
				if(flag_erase) begin
					flag_erase <= 1'b0;
					for(idx = 0; idx < 8; idx = idx + 1)
						regs[idx] <= 0;
				end else begin
					regs[0] <= wdata[7:0];
					for(idx = 0; idx < 7; idx = idx + 1)
						regs[idx+1] <= regs[idx];
				end
			end else begin 
				regs[waddr[4:2]] <= wdata[7:0];
			end
			state <= st2_waitbready;
			axi_bvalid <= 1'b1;
		end else begin
			state <= state;
		end
	st1_waitrready :
		if (axi_rready ==1) begin
			axi_rvalid <= 1'b0;
			state <= st0_idle;
		end	else begin
			state <= state;
		end
	st2_waitbready :
		if (axi_bready ==1) begin
			axi_bvalid <= 1'b0;
			state <= st0_idle;
		end	else begin
			state <= state;
		end
	default: begin
		state <= st0_idle; end
	endcase
	
	// ASCII Decoder
	reg [7:0] ascii7;
	wire [7:0] ascii;
	always @(ascii) begin
		case (ascii)
		//  CODEX   :   ascii7 = 8'bABCDEFG.
			8'd0	:	ascii7 = 8'b00000001;
			8'd1	:	ascii7 = 8'b00000001;
			8'd2	:	ascii7 = 8'b00000001;
			8'd3	:	ascii7 = 8'b00000001;
			8'd4	:	ascii7 = 8'b00000001;
			8'd5	:	ascii7 = 8'b00000001;
			8'd6	:	ascii7 = 8'b00000001;
			8'd7	:	ascii7 = 8'b00000001;
			8'd8	:	ascii7 = 8'b00000001;
			8'd9	:	ascii7 = 8'b00000001;
			8'd10	:	ascii7 = 8'b00000001;
			8'd11	:	ascii7 = 8'b00000001;
			8'd12	:	ascii7 = 8'b00000001;
			8'd13	:	ascii7 = 8'b00000001;
			8'd14	:	ascii7 = 8'b00000001;
			8'd15	:	ascii7 = 8'b00000001;
			8'd16	:	ascii7 = 8'b00000001;
			8'd17	:	ascii7 = 8'b00000001;
			8'd18	:	ascii7 = 8'b00000001;
			8'd19	:	ascii7 = 8'b00000001;
			8'd20	:	ascii7 = 8'b00000001;
			8'd21	:	ascii7 = 8'b00000001;
			8'd22	:	ascii7 = 8'b00000001;
			8'd23	:	ascii7 = 8'b00000001;
			8'd24	:	ascii7 = 8'b00000001;
			8'd25	:	ascii7 = 8'b00000001;
			8'd26	:	ascii7 = 8'b00000001;
			8'd27	:	ascii7 = 8'b00000001;
			8'd28	:	ascii7 = 8'b00000001;
			8'd29	:	ascii7 = 8'b00000001;
			8'd30	:	ascii7 = 8'b00000001;
			8'd31	:	ascii7 = 8'b00000001;
		//  CODEX   :   ascii7 = 8'bABCDEFG.
			8'd32	:	ascii7 = 8'b00000000;
			8'd33	:	ascii7 = 8'b01100001;//! '.
			8'd34	:	ascii7 = 8'b01000010;//" ''
			8'd35	:	ascii7 = 8'b01111111;//# |o|
			8'd36	:	ascii7 = 8'b10110111;//$ S.
			8'd37	:	ascii7 = 8'b11111111;//% 8.
			8'd38	:	ascii7 = 8'b11111010;//& 6b
			8'd39	:	ascii7 = 8'b01000000;//' '
			8'd40	:	ascii7 = 8'b00011100;//(
			8'd41	:	ascii7 = 8'b00111000;//)
			8'd42	:	ascii7 = 8'b01000010;//*
			8'd43	:	ascii7 = 8'b01100010;//+
			8'd44	:	ascii7 = 8'b00100000;//,
			8'd45	:	ascii7 = 8'b00000010;//-
			8'd46	:	ascii7 = 8'b00000001;//.
			8'd47	:	ascii7 = 8'b01001010;///
			8'd48	:	ascii7 = 8'b11111100;//0
			8'd49	:	ascii7 = 8'b01100000;//1
			8'd50	:	ascii7 = 8'b11011010;//2
			8'd51	:	ascii7 = 8'b11110010;//3
			8'd52	:	ascii7 = 8'b01100110;//4
			8'd53	:	ascii7 = 8'b10110110;//5
			8'd54	:	ascii7 = 8'b10111110;//6
			8'd55	:	ascii7 = 8'b11100000;//7
			8'd56	:	ascii7 = 8'b11111110;//8
			8'd57	:	ascii7 = 8'b11110110;//9
			8'd58	:	ascii7 = 8'b00010011;//:
			8'd59	:	ascii7 = 8'b00010001;//;
			8'd60	:	ascii7 = 8'b00011000;//<
			8'd61	:	ascii7 = 8'b00010010;//=
			8'd62	:	ascii7 = 8'b00110000;//>
			8'd63	:	ascii7 = 8'b11000001;//?
		//  CODEX   :   ascii7 = 8'bABCDEFG.
			8'd64	:	ascii7 = 8'b11111010;//@
			8'd65	:	ascii7 = 8'b11101110;//A
			8'd66	:	ascii7 = 8'b00111110;//B b
			8'd67	:	ascii7 = 8'b00011010;//C c
			8'd68	:	ascii7 = 8'b01111010;//D d
			8'd69	:	ascii7 = 8'b10011110;//E
			8'd70	:	ascii7 = 8'b10001110;//F
			8'd71	:	ascii7 = 8'b11110110;//G g 9
			8'd72	:	ascii7 = 8'b01101110;//H
			8'd73	:	ascii7 = 8'b01100000;//I
			8'd74	:	ascii7 = 8'b01110000;//J
			8'd75	:	ascii7 = 8'b10101110;//K
			8'd76	:	ascii7 = 8'b00001110;//L
			8'd77	:	ascii7 = 8'b11101100;//M large n
			8'd78	:	ascii7 = 8'b00101010;//N n
			8'd79	:	ascii7 = 8'b11111100;//O 0
			8'd80	:	ascii7 = 8'b11001110;//P
			8'd81	:	ascii7 = 8'b11100110;//Q q
			8'd82	:	ascii7 = 8'b00001010;//R
			8'd83	:	ascii7 = 8'b10110110;//S
			8'd84	:	ascii7 = 8'b10001100;//T
			8'd85	:	ascii7 = 8'b01111100;//U
			8'd86	:	ascii7 = 8'b01000110;//V u up
			8'd87	:	ascii7 = 8'b01111110;//W
			8'd88	:	ascii7 = 8'b10101010;//X
			8'd89	:	ascii7 = 8'b01110110;//Y
			8'd90	:	ascii7 = 8'b11011010;//Z
			8'd91	:	ascii7 = 8'b10011100;//[
			8'd92	:	ascii7 = 8'b00100110;//\
			8'd93	:	ascii7 = 8'b11100100;//]
			8'd94	:	ascii7 = 8'b10000100;//^
			8'd95	:	ascii7 = 8'b00010000;//_
		//  CODEX   :   ascii7 = 8'bABCDEFG.
			8'd96	:	ascii7 = 8'b01000000;//`
			8'd97	:	ascii7 = 8'b11101110;//A
			8'd98	:	ascii7 = 8'b00111110;//B b
			8'd99	:	ascii7 = 8'b00011010;//C c
			8'd100	:	ascii7 = 8'b01111010;//D d
			8'd101	:	ascii7 = 8'b10011110;//E
			8'd102	:	ascii7 = 8'b10001110;//F
			8'd103	:	ascii7 = 8'b11110110;//G g 9
			8'd104	:	ascii7 = 8'b01101110;//H
			8'd105	:	ascii7 = 8'b01100000;//I
			8'd106	:	ascii7 = 8'b01110000;//J
			8'd107	:	ascii7 = 8'b10101110;//K
			8'd108	:	ascii7 = 8'b00001110;//L
			8'd109	:	ascii7 = 8'b11101100;//M large n
			8'd110	:	ascii7 = 8'b00101010;//N n
			8'd111	:	ascii7 = 8'b11111100;//O 0
			8'd112	:	ascii7 = 8'b11001110;//P
			8'd113	:	ascii7 = 8'b11100110;//Q q
			8'd114	:	ascii7 = 8'b00001010;//R
			8'd115	:	ascii7 = 8'b10110110;//S
			8'd116	:	ascii7 = 8'b10001100;//T
			8'd117	:	ascii7 = 8'b01111100;//U
			8'd118	:	ascii7 = 8'b01000110;//V u up
			8'd119	:	ascii7 = 8'b01111110;//W
			8'd120	:	ascii7 = 8'b10101010;//X
			8'd121	:	ascii7 = 8'b01110110;//Y
			8'd122	:	ascii7 = 8'b11011010;//Z
			8'd123	:	ascii7 = 8'b00011101;//{
			8'd124	:	ascii7 = 8'b01100000;//|
			8'd125	:	ascii7 = 8'b01100101;//}
			8'd126	:	ascii7 = 8'b10000000;//~
			8'd127	:	ascii7 = 8'b00000001;// DEL
		//  CODEX   :   ascii7 = 8'bABCDEFG.			 GREEK LETTERS CAN SUCK MY DICK
			8'd128	:	ascii7 = 8'b00000001;
			8'd129	:	ascii7 = 8'b00000001;
			8'd130	:	ascii7 = 8'b00000001;
			8'd131	:	ascii7 = 8'b00000001;
			8'd132	:	ascii7 = 8'b00000001;
			8'd133	:	ascii7 = 8'b00000001;
			8'd134	:	ascii7 = 8'b00000001;
			8'd135	:	ascii7 = 8'b00000001;
			8'd136	:	ascii7 = 8'b00000001;
			8'd137	:	ascii7 = 8'b00000001;
			8'd138	:	ascii7 = 8'b00000001;
			8'd139	:	ascii7 = 8'b00000001;
			8'd140	:	ascii7 = 8'b00000001;
			8'd141	:	ascii7 = 8'b00000001;
			8'd142	:	ascii7 = 8'b00000001;
			8'd143	:	ascii7 = 8'b00000001;
			8'd144	:	ascii7 = 8'b00000001;
			8'd145	:	ascii7 = 8'b00000001;
			8'd146	:	ascii7 = 8'b00000001;
			8'd147	:	ascii7 = 8'b00000001;
			8'd148	:	ascii7 = 8'b00000001;
			8'd149	:	ascii7 = 8'b00000001;
			8'd150	:	ascii7 = 8'b00000001;
			8'd151	:	ascii7 = 8'b00000001;
			8'd152	:	ascii7 = 8'b00000001;
			8'd153	:	ascii7 = 8'b00000001;
			8'd154	:	ascii7 = 8'b00000001;
			8'd155	:	ascii7 = 8'b00000001;
			8'd156	:	ascii7 = 8'b00000001;
			8'd157	:	ascii7 = 8'b00000001;
			8'd158	:	ascii7 = 8'b00000001;
			8'd159	:	ascii7 = 8'b00000001;
			8'd160	:	ascii7 = 8'b00000001;
			8'd161	:	ascii7 = 8'b00000001;
			8'd162	:	ascii7 = 8'b00000001;
			8'd163	:	ascii7 = 8'b00000001;
			8'd164	:	ascii7 = 8'b00000001;
			8'd165	:	ascii7 = 8'b00000001;
			8'd166	:	ascii7 = 8'b00000001;
			8'd167	:	ascii7 = 8'b00000001;
			8'd168	:	ascii7 = 8'b00000001;
			8'd169	:	ascii7 = 8'b00000001;
			8'd170	:	ascii7 = 8'b00000001;
			8'd171	:	ascii7 = 8'b00000001;
			8'd172	:	ascii7 = 8'b00000001;
			8'd173	:	ascii7 = 8'b00000001;
			8'd174	:	ascii7 = 8'b00000001;
			8'd175	:	ascii7 = 8'b00000001;
			8'd176	:	ascii7 = 8'b00000001;
			8'd177	:	ascii7 = 8'b00000001;
			8'd178	:	ascii7 = 8'b00000001;
			8'd179	:	ascii7 = 8'b00000001;
			8'd180	:	ascii7 = 8'b00000001;
			8'd181	:	ascii7 = 8'b00000001;
			8'd182	:	ascii7 = 8'b00000001;
			8'd183	:	ascii7 = 8'b00000001;
			8'd184	:	ascii7 = 8'b00000001;
			8'd185	:	ascii7 = 8'b00000001;
			8'd186	:	ascii7 = 8'b00000001;
			8'd187	:	ascii7 = 8'b00000001;
			8'd188	:	ascii7 = 8'b00000001;
			8'd189	:	ascii7 = 8'b00000001;
			8'd190	:	ascii7 = 8'b00000001;
			8'd191	:	ascii7 = 8'b00000001;
			8'd192	:	ascii7 = 8'b00000001;
			8'd193	:	ascii7 = 8'b00000001;
			8'd194	:	ascii7 = 8'b00000001;
			8'd195	:	ascii7 = 8'b00000001;
			8'd196	:	ascii7 = 8'b00000001;
			8'd197	:	ascii7 = 8'b00000001;
			8'd198	:	ascii7 = 8'b00000001;
			8'd199	:	ascii7 = 8'b00000001;
			8'd200	:	ascii7 = 8'b00000001;
			8'd201	:	ascii7 = 8'b00000001;
			8'd202	:	ascii7 = 8'b00000001;
			8'd203	:	ascii7 = 8'b00000001;
			8'd204	:	ascii7 = 8'b00000001;
			8'd205	:	ascii7 = 8'b00000001;
			8'd206	:	ascii7 = 8'b00000001;
			8'd207	:	ascii7 = 8'b00000001;
			8'd208	:	ascii7 = 8'b00000001;
			8'd209	:	ascii7 = 8'b00000001;
			8'd210	:	ascii7 = 8'b00000001;
			8'd211	:	ascii7 = 8'b00000001;
			8'd212	:	ascii7 = 8'b00000001;
			8'd213	:	ascii7 = 8'b00000001;
			8'd214	:	ascii7 = 8'b00000001;
			8'd215	:	ascii7 = 8'b00000001;
			8'd216	:	ascii7 = 8'b00000001;
			8'd217	:	ascii7 = 8'b00000001;
			8'd218	:	ascii7 = 8'b00000001;
			8'd219	:	ascii7 = 8'b00000001;
			8'd220	:	ascii7 = 8'b00000001;
			8'd221	:	ascii7 = 8'b00000001;
			8'd222	:	ascii7 = 8'b00000001;
			8'd223	:	ascii7 = 8'b00000001;
			8'd224	:	ascii7 = 8'b00000001;
			8'd225	:	ascii7 = 8'b00000001;
			8'd226	:	ascii7 = 8'b00000001;
			8'd227	:	ascii7 = 8'b00000001;
			8'd228	:	ascii7 = 8'b00000001;
			8'd229	:	ascii7 = 8'b00000001;
			8'd230	:	ascii7 = 8'b00000001;
			8'd231	:	ascii7 = 8'b00000001;
			8'd232	:	ascii7 = 8'b00000001;
			8'd233	:	ascii7 = 8'b00000001;
			8'd234	:	ascii7 = 8'b00000001;
			8'd235	:	ascii7 = 8'b00000001;
			8'd236	:	ascii7 = 8'b00000001;
			8'd237	:	ascii7 = 8'b00000001;
			8'd238	:	ascii7 = 8'b00000001;
			8'd239	:	ascii7 = 8'b00000001;
			8'd240	:	ascii7 = 8'b00000001;
			8'd241	:	ascii7 = 8'b00000001;
			8'd242	:	ascii7 = 8'b00000001;
			8'd243	:	ascii7 = 8'b00000001;
			8'd244	:	ascii7 = 8'b00000001;
			8'd245	:	ascii7 = 8'b00000001;
			8'd246	:	ascii7 = 8'b00000001;
			8'd247	:	ascii7 = 8'b00000001;
			8'd248	:	ascii7 = 8'b00000001;
			8'd249	:	ascii7 = 8'b00000001;
			8'd250	:	ascii7 = 8'b00000001;
			8'd251	:	ascii7 = 8'b00000001;
			8'd252	:	ascii7 = 8'b00000001;
			8'd253	:	ascii7 = 8'b00000001;
			8'd254	:	ascii7 = 8'b00000001;
			8'd255	:	ascii7 = 8'b00000001;
			default : 	ascii7 = 8'b00000001;
		endcase
	end
	
	reg [2:0] sync;
	
	always @(sync)
	begin : DECODER_AN
		case(sync)
			3'd0	:	SEGMENT_AN = 8'b11111110;
			3'd1	:	SEGMENT_AN = 8'b11111101;
			3'd2	:	SEGMENT_AN = 8'b11111011;
			3'd3	:	SEGMENT_AN = 8'b11110111;
			3'd4	:	SEGMENT_AN = 8'b11101111;
			3'd5	:	SEGMENT_AN = 8'b11011111;
			3'd6	:	SEGMENT_AN = 8'b10111111;
			3'd7	:	SEGMENT_AN = 8'b01111111;
		endcase
	end
	
	always @(posedge CLK)
    begin : SYNC_COUNTER
        if(RST == 1'b0) begin
            sync <= 0;
			SEGMENT_SEG <= 0;
        end else begin
            if(enable_count)
                sync <= sync+1;
			SEGMENT_SEG <= ~ascii7;
        end
    end
	
	assign ascii = regs[sync];
	
	
endmodule
