`timescale 1ps / 1ps


module AXI_SPI_ROM_EXT #
    (
    parameter              sword = 32,
    parameter            numbit_divisor = 3,    // The SCLK will be CLK/2^(numbit_divisor-1)
    parameter            PERIOD = 15625
    )
    (
      // Common
      input         CLK,                // system clock
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
      
      // SPI ROM interface
      output          ROM_CS,
      input           ROM_SDI,
      output          ROM_SDO,
      output          ROM_WP,
      output          ROM_HLD,
      output          ROM_SCK

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
    
    localparam integer tdevice_PU = 3e8;
    localparam integer count_ready_end = (tdevice_PU/PERIOD) - 1;
    localparam integer bits_count_ready = clogb2(count_ready_end);
    
    reg [bits_count_ready-1:0] count_ready;
    wire init_ready;
    assign init_ready = (count_ready == count_ready_end)?1'b1:1'b0;
    
    always @(posedge CLK)
    begin : COUNT_READY_COUNTER
        if(RST == 1'b0) begin
            count_ready <= 0;
        end else begin
            if(~init_ready) begin    
                count_ready <= count_ready+1;
            end
        end
    end
    
    wire SCLK;
    wire EOS;        // Not used... yet
    wire CEB; 
    wire DATA;
    assign ROM_SCK = SCLK;
    assign ROM_HLD = 1'b1;
    assign ROM_WP = 1'b1;
    assign ROM_CS = CEB;
    assign ROM_SDO = DATA;
    
STARTUPE2 #(
   .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
   .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
)
STARTUPE2_inst (
   .CFGCLK(),        // 1-bit output: Configuration main clock output
   .CFGMCLK(),       // 1-bit output: Configuration internal oscillator clock output
   .EOS(EOS),        // 1-bit output: Active high output signal indicating the End Of Startup.
   .PREQ(),          // 1-bit output: PROGRAM request to fabric output
   .CLK(1'b0),       // 1-bit input: User start-up clock input
   .GSR(1'b0),       // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
   .GTS(1'b0),       // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
   .KEYCLEARB(1'b0), // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
   .PACK(1'b0),      // 1-bit input: PROGRAM acknowledge input
   .USRCCLKO(SCLK),  // 1-bit input: User CCLK input
   .USRCCLKTS(1'b0), // 1-bit input: User CCLK 3-state enable input
   .USRDONEO(1'b1),  // 1-bit input: User DONE pin output control
   .USRDONETS(1'b1)  // 1-bit input: User DONE 3-state enable output
);
    
    // Read Channel:
    // Write Channel:
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
            if(axi_bvalid) begin    // bvalid indicates wterm sig
                waddr <= waddr;
                wassert[0] <= 1'b0;
            end else if(axi_awvalid) begin
                waddr <= axi_awaddr | 32'h00800000; // Workaround for putting the .bit in the 0x0 position (relative to ROM)
                wassert[0] <= 1'b1;
            end else begin
                waddr <= waddr;
                wassert[0] <= wassert[0];
            end
            
            if(axi_bvalid) begin    // bvalid indicates wterm sig
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
            
            if(axi_rvalid) begin    // rvalid indicates rterm sig
                raddr <= raddr;
                rassert <= 1'b0;
            end else if(axi_arvalid) begin
                raddr <= axi_araddr | 32'h00800000;
                rassert <= 1'b1;
            end else begin
                raddr <= raddr;
                rassert <= rassert;
            end
        end
    end
    
    // Angry CLK divisor for SCLK
    reg [numbit_divisor-1:0] divisor;
    always @(posedge CLK ) begin
        if(RST == 1'b0) begin
            divisor <= {numbit_divisor{1'b0}};
        end else begin
            divisor <= divisor + 1;
        end
    end
    wire SCLK_EN;    // This is an Enable that does the same that the divisor
    localparam [numbit_divisor-1:0] div_comp = ~(1 << (numbit_divisor-1));
    assign SCLK_EN = divisor == div_comp ? 1'b1:1'b0;
    wire SCLK_NEN;
    assign SCLK_NEN = divisor == 0 ? 1'b1:1'b0;
    wire SCLKA;
    assign SCLKA = ~divisor[numbit_divisor-1];
    // SCLK Activator (High state thing)
    assign SCLK = (~CEB)?SCLKA:1'b0;
    
    // Counter for SPI SYNC
    localparam command_data_bits = (8+sword*2);
    localparam numbit_sync = clogb2(command_data_bits);
    reg [command_data_bits-1:0] cap_data;
    reg [command_data_bits-1:0] rcv_data;
    reg cap_enable;
    reg [command_data_bits-1:0] command_data;
    reg [numbit_sync-1:0] sync_stop;
    reg [numbit_sync-1:0] command_sync_stop;
    reg [numbit_sync-1:0] sync;
    wire stop;
    reg transmit;
    assign stop = sync == sync_stop? 1'b1:1'b0;
    always @(posedge CLK ) begin
        if(RST == 1'b0) begin
            sync <= {numbit_sync{1'b0}};
        end else begin
            if(SCLK_EN == 1'b1) begin
            if((transmit == 1'b1 && ~(|sync)) || (|sync)) begin
                if(stop == 1'b1) begin
                    sync <= {numbit_sync{1'b0}};
                end else begin
                    sync <= sync + 1;
                end
            end else begin
                sync <= sync;
            end
            end
        end
    end
    
    always @(posedge CLK ) begin
        if(RST == 1'b0) begin
            cap_data <= 0;
            sync_stop <= 0;
            rcv_data <= 0;
            transmit <= 1'b0;
            //CEB <= 1'b1;
        end else begin
            if(SCLK_EN == 1'b1) begin
                if(cap_enable == 1'b1 && transmit == 1'b0) begin
                    sync_stop <= command_sync_stop;
                    cap_data <= command_data;
                    transmit <= 1'b1;
                end else if(stop == 1'b1 && transmit == 1'b1) begin
                    sync_stop <= sync_stop;
                    cap_data <= cap_data;
                    transmit <= 1'b0;
                end else if(transmit == 1'b1) begin
                    sync_stop <= sync_stop;
                    cap_data <= cap_data << 1;
                    transmit <= transmit;
                end else begin
                    sync_stop <= sync_stop;
                    cap_data <= cap_data;
                    transmit <= transmit;
                end
            end
            
            if(SCLK_NEN == 1'b1) begin
                if(cap_enable == 1'b1 && transmit == 1'b0) begin
                    rcv_data <= 0;
                end else if(stop == 1'b1 && transmit == 1'b1) begin
                    rcv_data <= {rcv_data[command_data_bits-2:0], ROM_SDI};
                end else if(transmit == 1'b1) begin
                    rcv_data <= {rcv_data[command_data_bits-2:0], ROM_SDI};
                end else begin
                    rcv_data <= rcv_data;
                end
            end
        end
    end
    
    genvar q;
    reg cap_read;
    generate
        for(q = 0; q < (sword/8); q=q+1) begin : CAPREAD_THING
            always @(posedge CLK ) begin
                if(RST == 1'b0) begin
                    axi_rdata[(q+1)*8-1:q*8] <= 0;
                end else begin
                    if(cap_read == 1'b1) begin
                        axi_rdata[(q+1)*8-1:q*8] <= rcv_data[(sword/8 - q)*8-1:(sword/8 - q - 1)*8];
                    end
                end
            end
        end
    endgenerate
    
    assign CEB = ~transmit;
    assign DATA = (CEB==1'b0) ?cap_data[command_data_bits-1]:1'bz;
    
    reg [3:0] state;
    reg [3:0] ret_state;
    reg [3:0] wen_state;
    reg [3:0] awt_state;
    
    localparam stg_execute = 0, st0_com_wen = 1, st1_idle = 2, st2_com_read = 3, st3_rvalid = 4, st4_com_wrt1 = 5, st5_com_wrt2 = 6, st6_com_wrt3 = 7, st7_com_wrt4 = 8, st8_bvalid = 9, st9_cap_read = 10, st10_com_stat = 11, st11_wait_wip = 12, stI_init = 13;
    
    // Output depends only on the state
    always @ (state) begin
        axi_rvalid = 1'b0;
        axi_bvalid = 1'b0;
        cap_enable = 1'b0;
        command_data = 0;
        command_sync_stop = 0;
        cap_read = 1'b0;
        case (state)
            stg_execute: begin 
                end
            stI_init: begin 
                end
            st0_com_wen: begin 
                cap_enable = 1'b1;
                command_data = {8'h06, 8'b00000011, 56'd0};
                command_sync_stop = 8 -1;
                end
            st1_idle: begin 
                end
            st2_com_read: begin 
                cap_enable = 1'b1;
                command_data = {8'h13, raddr, 32'd0};
                command_sync_stop = 8+32+32-1;
                end
            st3_rvalid: begin 
                axi_rvalid = 1'b1;
                end
            st4_com_wrt1: begin  
                cap_enable = wstrb[0];
                command_data = {8'h12, waddr, wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};
                if(wstrb[3:0] == 4'b1111)
                    command_sync_stop = 8+32+32-1;
                else if(wstrb[2:0] == 3'b111)
                    command_sync_stop = 8+32+24-1;
                else if(wstrb[1:0] == 2'b11)
                    command_sync_stop = 8+32+16-1;
                else
                    command_sync_stop = 8+32+8-1;
                end
            st5_com_wrt2: begin 
                cap_enable = wstrb[1];
                command_data = {8'h12, waddr+1, wdata[15:8], wdata[23:16], wdata[31:24], 8'd0};
                if(wstrb[3:1] == 3'b111)
                    command_sync_stop = 8+32+24-1;
                else if(wstrb[2:1] == 2'b11)
                    command_sync_stop = 8+32+16-1;
                else
                    command_sync_stop = 8+32+8-1;
                end
            st6_com_wrt3: begin 
                cap_enable = wstrb[2];
                command_data = {8'h12, waddr+2, wdata[23:16], wdata[31:24], 16'd0};
                if(wstrb[3:2] == 2'b11)
                    command_sync_stop = 8+32+16-1;
                else
                    command_sync_stop = 8+32+8-1;
                end
            st7_com_wrt4: begin 
                cap_enable = wstrb[3];
                command_data = {8'h12, waddr+3, wdata[31:24], 24'd0};
                command_sync_stop = 8+32+8-1;
                end
            st8_bvalid: begin 
                axi_bvalid = 1'b1;
                end
            st9_cap_read: begin 
                cap_read = 1'b1;
                end
            st10_com_stat: begin 
                cap_enable = 1'b1;
                command_data = {8'h05, 64'd0};
                command_sync_stop = 16-1;
                end
            st11_wait_wip: begin 
                end
        endcase
    end
    
    // Determine the next state
    always @ (posedge CLK ) begin
        if (RST == 1'b0) begin
            state <= stI_init;
            ret_state <= stI_init;
            wen_state <= st4_com_wrt1;
            awt_state <= st5_com_wrt2;
        end else begin
            case (state)
            stg_execute:
                if(SCLK_EN & stop)
                    state <= ret_state;
                else
                    state <= stg_execute;
            stI_init: 
                if(init_ready) 
                    state <= st1_idle; 
                else 
                    state <= stI_init;
            st0_com_wen: 
                if(transmit) begin
                    state <= stg_execute;
                    ret_state <= wen_state; 
                end
            st1_idle:
                if (EOS) begin
                    if (rassert == 1'b1)
                        state <= st2_com_read;
                    else if (wassert == 2'b11) begin
                        state <= st0_com_wen;
                        if(wstrb[0]) begin
                            wen_state <= st4_com_wrt1;
                        end else if(wstrb[1]) begin
                            wen_state <= st5_com_wrt2;
                        end else if(wstrb[2]) begin
                            wen_state <= st6_com_wrt3;
                        end else if(wstrb[3]) begin
                            wen_state <= st7_com_wrt4;
                        end else begin // Wait... what?
                            state <= st8_bvalid;
                        end 
                    end else
                        state <= st1_idle;
                end else begin
                    state <= st1_idle;
                end
            st2_com_read: 
                if(transmit) begin
                    state <= stg_execute;
                    ret_state <= st9_cap_read; 
                end
            st3_rvalid:
                if (axi_rready == 1'b1)
                    state <= st1_idle;
                else 
                    state <= st3_rvalid;
            st4_com_wrt1: 
                if(wstrb[2:0] == 3'b111 || wstrb == 4'b0011 || wstrb == 4'b0001) begin
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st8_bvalid;
                    end
                end else if(wstrb == 4'b1011 || wstrb == 4'b1001) begin 
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st0_com_wen;
                        wen_state <= st7_com_wrt4; 
                    end
                end else if(wstrb[2:0] == 3'b101) begin
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st0_com_wen;
                        wen_state <= st6_com_wrt3; 
                    end
                end else begin    // Wait... what?
                    state <= st8_bvalid;
                end
            st5_com_wrt2: 
                if(wstrb[2:1] == 2'b11 || wstrb[3:1] == 3'b001) begin
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st8_bvalid;
                    end
                end else if(wstrb[3:1] == 3'b101) begin 
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st0_com_wen;
                        wen_state <= st7_com_wrt4; 
                    end
                end else begin    // Wait... what?
                    state <= st8_bvalid;
                end
            st6_com_wrt3: 
                if(wstrb[2] == 1'b1) begin
                    if(transmit) begin
                        state <= stg_execute;
                        ret_state <= st10_com_stat; 
                        awt_state <= st8_bvalid;
                    end
                end else begin    // Wait... what?
                    state <= st8_bvalid;
                end
            st7_com_wrt4: 
                if(transmit) begin
                    state <= stg_execute;
                    ret_state <= st10_com_stat; 
                    awt_state <= st8_bvalid;
                end
            st8_bvalid:
                if (axi_bready == 1'b1)
                    state <= st1_idle;
                else 
                    state <= st8_bvalid;
            st9_cap_read:
                state <= st3_rvalid;
            st10_com_stat: 
                if(transmit) begin
                    state <= stg_execute;
                    ret_state <= st11_wait_wip; 
                end
            st11_wait_wip:
                if (rcv_data[0] == 1'b0)
                    state <= awt_state;
                else 
                    state <= st10_com_stat;
            default:
                state <= stI_init;
            endcase
        end
    end
    
    
endmodule
