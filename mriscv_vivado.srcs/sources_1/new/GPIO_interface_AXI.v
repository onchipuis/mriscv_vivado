`timescale 1ns / 1ps

/*
GPIO interface for AXI-4 Lite
Support up-to 32 GPIO with up-to 32 PWM with UART interface

This is the first version (0.1)
TODO: Better addressing
*/

module GPIO_interface_AXI #
    (
    parameter            PERIOD = 100000,            // Actually Frequency in KHz 
    parameter            GPIO_PINS = 32,             // How many pins exists?
    parameter            GPIO_PWM = 32,              // How many of the above support PWM?
    parameter            GPIO_IRQ = 8,               // How many of the above support IRQ?
    parameter            GPIO_TWO_PRESCALER = 1,     // Independent Prescaler PWM enabled?
    parameter            PWM_PRESCALER_BITS = 16,    // How many bits is the prescaler? (Main frequency divisor)
    parameter            PWM_BITS = 16,              // How many bits are the pwms?
    parameter            UART_RX_BUFFER_BITS = 10    // How many buffer?
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
    
    // General GPIO interface spec (feel free replacing for your needs)
    input  [GPIO_PINS-1:0] GPIO_PinIn,         // Pin in data
    output [GPIO_PINS-1:0] GPIO_PinOut,        // Pin out data
    output reg [GPIO_PINS-1:0] GPIO_Rx,        // Pin enabled for reciving
    output reg [GPIO_PINS-1:0] GPIO_Tx,        // Pin enabled for transmitting
    output reg [GPIO_PINS-1:0] GPIO_Strength,  // Pin strength?
    output reg [GPIO_PINS-1:0] GPIO_Pulldown,  // Pin Pulldown resistor active
    output reg [GPIO_PINS-1:0] GPIO_Pullup,    // Pin Pullup resistor active
    
    // IRQs
    output [GPIO_IRQ-1:0] CORE_IRQ,            // The irqs
    output reg [31:0]     PROGADDR_IRQ         // IRQ address
    
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
                waddr <= axi_awaddr;
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
                raddr <= axi_araddr;
                rassert <= 1'b1;
            end else begin
                raddr <= raddr;
                rassert <= rassert;
            end
        end
    end
    
    // Prescaler
    reg [PWM_PRESCALER_BITS-1:0] prescaler;
    reg [PWM_PRESCALER_BITS-1:0] prescaler_limit;
    wire enable_prescaler;
    assign enable_prescaler = prescaler == prescaler_limit?1'b1:1'b0;
    
    always @(posedge CLK)
    begin : COUNT_PRESCALER
        if(RST == 1'b0) begin
            prescaler <= 0;
        end else begin
            if(enable_prescaler) begin    
                prescaler <= 0;
            end else begin
                prescaler <= prescaler+1;
            end
        end
    end
    
    genvar i;
    
    // PWM BEHAVIORAL
    reg [PWM_BITS:0] count_pwm [0:GPIO_PWM-1];                            // Pwm counters
    reg [PWM_BITS:0] pwm [0:GPIO_PWM-1];                                // Pwm limiter
    reg [PWM_PRESCALER_BITS-1:0] pre_count_pwm [0:GPIO_PWM-1];            // Pwm prescaler
    reg [PWM_PRESCALER_BITS-1:0] limit_pre_count_pwm [0:GPIO_PWM-1];    // Pwm prescaler limit
    wire [GPIO_PWM-1:0] enable_pre_count_pwm;
    wire [GPIO_PWM-1:0] out_pwm;
    generate
        for(i = 0; i < GPIO_PWM; i=i+1) begin : ADDITIONAL_PRESCALERS
        
            // Aditional prescaler
            if(GPIO_TWO_PRESCALER) begin
                always @(posedge CLK)
                    if (RST == 1'b0 || enable_pre_count_pwm[i] == 1'b1) 
                        pre_count_pwm[i] <= 0;
                    else 
                        pre_count_pwm[i] <= pre_count_pwm[i]+1;
                assign enable_pre_count_pwm[i] = pre_count_pwm[i] == limit_pre_count_pwm[i]?1'b1:1'b0;
            end 
            else assign enable_pre_count_pwm[i] = 1'b1;
            
            always @(posedge CLK)
                if (RST == 1'b0) 
                    count_pwm[i] <= 0;
                else 
                    count_pwm[i] <= count_pwm[i]+1;
            assign out_pwm[i] = count_pwm[i] < pwm[i]?1'b0:1'b1;
        end
    endgenerate
    
    // GENERAL GPIO OUT
    reg [GPIO_PWM-1:0] is_pwm;
    reg    [GPIO_PINS-1:0] out_gpio;
    localparam GPIO_REG_BIT_SERIAL=0;
    reg [31:0] gpio_reg;    // This is a general purpose register
    wire serial_txd;
    
    generate
        for(i = 0; i < GPIO_PINS; i=i+1) begin : MUX_PWM
            if(i == 0) assign GPIO_PinOut[i] = gpio_reg[GPIO_REG_BIT_SERIAL]?serial_txd:(is_pwm[i]?out_pwm[i]:out_gpio[i]);
            else if(i < GPIO_PWM) assign GPIO_PinOut[i] = is_pwm[i]?out_pwm[i]:out_gpio[i];
            else assign GPIO_PinOut[i] = out_gpio[i];
        end
    endgenerate
    
    // IRQ assign
    reg [GPIO_IRQ-1:0] is_irq;
    generate
        for(i = 0; i < GPIO_IRQ; i=i+1) begin : MUX_IRQ
            assign CORE_IRQ[i] = (is_irq[i] & GPIO_Rx[i+2])?GPIO_PinIn[i+2]:1'b0;
        end
    endgenerate

    // Serial through GPIO
    // Serial Rx travels through GPIOPIN1
    // If you ask for tx, is assigned before on GPIOPIN0
    wire serial_rxd;
    assign serial_rxd = gpio_reg[GPIO_REG_BIT_SERIAL]?GPIO_PinIn[1]:1'b1;
    wire [3:0] bps;
    assign bps = gpio_reg[4:1];
    reg [15:0] prescale;
    always @(bps) begin
        case(bps)
            //    prescale = Fin/(Fbps*8)
            4'h0: prescale = PERIOD * 1000 / (9600 * 8); //1250000000/PERIOD/9600;
            4'h1: prescale = PERIOD * 1000 / (9600 * 8); //1250000000/PERIOD/9600;
            4'h2: prescale = PERIOD * 1000 / (600 * 8); //1250000000/PERIOD/600;
            4'h3: prescale = PERIOD * 1000 / (1200 * 8); //1250000000/PERIOD/1200;
            4'h4: prescale = PERIOD * 1000 / (2400 * 8); //1250000000/PERIOD/2400;
            4'h5: prescale = PERIOD * 1000 / (4800 * 8); //1250000000/PERIOD/4800;
            4'h6: prescale = PERIOD * 1000 / (9600 * 8); //1250000000/PERIOD/9600;
            4'h7: prescale = PERIOD * 1000 / (14000 * 8); //1250000000/PERIOD/14000;
            4'h8: prescale = PERIOD * 1000 / (19200 * 8); //1250000000/PERIOD/19200;
            4'h9: prescale = PERIOD * 1000 / (28800 * 8); //1250000000/PERIOD/28800;
            4'hA: prescale = PERIOD * 1000 / (38400 * 8); //1250000000/PERIOD/38400;
            4'hB: prescale = PERIOD * 1000 / (56000 * 8); //1250000000/PERIOD/56000;
            4'hC: prescale = PERIOD * 1000 / (57600 * 8); //1250000000/PERIOD/57600;
            4'hD: prescale = PERIOD * 1000 / (115200 * 8); //1250000000/PERIOD/115200;
            4'hE: prescale = PERIOD * 1000 / (115200 * 8); //1250000000/PERIOD/115200;
            4'hF: prescale = PERIOD * 1000 / (115200 * 8); //1250000000/PERIOD/115200;
        endcase
    end
    
    wire [1:0] uart_bits;
    assign uart_bits = gpio_reg[6:5];
    wire [1:0] uart_parity;
    assign uart_parity = gpio_reg[17:16];
    wire [1:0] uart_stopbit;
    assign uart_stopbit = gpio_reg[19:18];
    
    localparam UART_DATA_WIDTH = 8;
    wire RST_I = ~RST;
    wire tx_busy;
    wire rx_busy;
    wire rx_overrun_error;
    wire rx_frame_error;
    reg [UART_DATA_WIDTH-1:0] uart_tx_axi_tdata;
    reg uart_tx_axi_tvalid;
    wire uart_tx_axi_tready;
    wire [UART_DATA_WIDTH-1:0] uart_rx_axi_tdata;
    wire uart_rx_axi_tvalid;
    reg uart_rx_axi_tready;
    
    uart uart_impl(
        .clk(CLK),
        .rst(RST_I),
        .input_axis_tdata(uart_tx_axi_tdata),
        .input_axis_tvalid(uart_tx_axi_tvalid),
        .input_axis_tready(uart_tx_axi_tready),
        .output_axis_tdata(uart_rx_axi_tdata),
        .output_axis_tvalid(uart_rx_axi_tvalid),
        .output_axis_tready(uart_rx_axi_tready),
        .rxd(serial_rxd),
        .txd(serial_txd),
        .tx_busy(tx_busy),
        .rx_busy(rx_busy),
        .rx_overrun_error(rx_overrun_error),
        .rx_frame_error(rx_frame_error),
        .uart_bits(uart_bits),
        .uart_parity(uart_parity),
        .uart_stopbit(uart_stopbit),
        .prescale(prescale)        // The BPS of prescale is Fbps = Fin/(prescale*8), so prescale = Fin/(Fbps*8)
    );
    
    // UART buffer for receive
    reg [UART_DATA_WIDTH-1:0] uart_rx_data;
    reg uart_dump;                            // If 1, uart_rx_data is filled, must wait uart_dumped
    reg uart_dumped;            
    reg uart_nodump;
    reg uart_overflow;
    
    reg [UART_RX_BUFFER_BITS-1:0] uart_sp;    // Start pointer
    reg [UART_RX_BUFFER_BITS-1:0] uart_ep;    // End pointer
    reg [1:0] uart_dumping;

    reg uart_mem_cen;        // mem interface
    reg uart_mem_wen;
    reg [UART_RX_BUFFER_BITS-1:0] uart_mem_addr;
    reg [UART_DATA_WIDTH-1:0] uart_mem_d;
    wire [UART_DATA_WIDTH-1:0] uart_mem_q;
    
    always @(posedge CLK) 
    if (RST == 1'b0) begin
        uart_mem_addr <= 0;
        uart_mem_d <= 0;
        uart_mem_cen <= 1'b0;
        uart_mem_wen <= 1'b0;
        uart_sp <= 0;
        uart_ep <= 0;
        uart_dumping <= 1'b0;
        uart_dumped <= 1'b0;
        uart_rx_data <= 0;
        uart_nodump <= 1'b0;
        uart_overflow <= 1'b0;
    end    else begin
        if (uart_rx_axi_tready) begin // 1: From 2, the data is saved. Increment uart_sp
            uart_mem_wen <= 1'b0;
            uart_mem_cen <= 1'b0;
            uart_rx_axi_tready <= 1'b0;
            if((uart_sp+1) == uart_ep) begin    // Buffer overflow
                uart_overflow <= 1'b1;
            end else begin
                uart_overflow <= 1'b0;
                uart_sp <= uart_sp+1;
            end
        end else if (uart_rx_axi_tvalid) begin    // 2: There is a data. Saves into MEM, then goes to 1
            if((uart_sp+1) != uart_ep) begin    // Buffer overflow
                uart_mem_addr <= uart_sp;
                uart_mem_d <= uart_rx_axi_tdata;
                uart_mem_wen <= 1'b1;
                uart_mem_cen <= 1'b1;
            end
            uart_rx_axi_tready <= 1'b1;
        end else if (uart_dumped) begin    // 3: Final dump step. Clear uart_dumped (only lasts 1 clock cycle
            uart_dumped <= 1'b0;
        end else if (uart_dumping == 2'b10) begin // 4: Second dump step. uart_dumping is a flag. uart_dumped is triggered.
        // Here clears the flag. Fills uart_rx_data with MEM[uart_ep], then 
        // increments uart_ep. If uart_ep will be equal to uart_sp, both will be 
        // zero. If uart_ep is equal to uart_sp, means no data (Buffer empty).
            uart_rx_data <= uart_mem_q;
            uart_mem_cen <= 1'b0;
            uart_dumping <= 2'b00;
            uart_dumped <= 1'b1;
            if(uart_ep == uart_sp) begin
                uart_nodump <= 1'b1;
            end else if((uart_ep+1) == uart_sp) begin
                uart_sp <= 0;
                uart_ep <= 0;
            end else begin
                uart_ep <= uart_ep+1;
            end
        end else if (uart_dumping == 2'b01) begin // Step 4 consumes two cycles
            uart_dumping <= 2'b10;
        end else if (uart_dump) begin // 5: First dump step. uart_dump is triggered from FSM. Put all on MEM and triggers uart_dumping.
        // If uart_ep is equal to uart_sp, means no data (Buffer empty). 
        // If above 
            if(uart_ep == uart_sp) begin
                uart_nodump <= 1'b1;
                uart_dumped <= 1'b1;
            end else begin
                uart_mem_addr <= uart_ep;
                uart_mem_cen <= 1'b1;
                uart_dumping <= 2'b01;
                uart_dumped <= 1'b0;
                uart_nodump <= 1'b0;
            end
        end else begin
            uart_mem_wen <= 1'b0;
            uart_mem_cen <= 1'b0;
            uart_rx_axi_tready <= 1'b0;
        end
    end
    
    //************CHANGEME
    // Memory implementation. Replace this code with your
    // own memory
    reg [UART_DATA_WIDTH-1:0] MEM [0:(2**UART_RX_BUFFER_BITS)-1];
    reg [UART_DATA_WIDTH-1:0] Q;
    always @(posedge CLK)
    if (RST == 1'b0) begin
        Q <= 0;
    end    else begin
        if(uart_mem_cen) begin
            Q <= MEM[uart_mem_addr];
            if(uart_mem_wen) MEM[uart_mem_addr] <= uart_mem_d;
        end
    end
    assign uart_mem_q = Q;
    //************CHANGEME
    
    // Addressing
    // Number of addr
    localparam NUM_ADDR = GPIO_PWM + GPIO_PWM + 1 + 1 + 1 + 3 + 3 + 3 + 3 + 3 + 3 + 3 + 3 + 1;
    localparam BITS_ADDR = clogb2(NUM_ADDR);
    /*
    reg [PWM_BITS:0] pwm [0:GPIO_PWM-1];    // Write/Read
    reg [PWM_PRESCALER_BITS-1:0] limit_pre_count_pwm [0:GPIO_PWM-1];    // Write/Read
    reg [PWM_PRESCALER_BITS-1:0] prescaler_limit;    // Write/Read
    reg [31:0] gpio_reg;                        // Some write, Read
    input [GPIO_PINS-1:0] GPIO_PinIn,            // Read only
    reg [GPIO_PWM-1:0] is_pwm;                    // Write/Read/Trigerable
    reg    [GPIO_PINS-1:0] out_gpio;                // Write/Read/Trigerable
    reg [GPIO_PINS-1:0] GPIO_Rx,                // Write/Read/Trigerable
    reg [GPIO_PINS-1:0] GPIO_Tx,                // Write/Read/Trigerable
    reg [GPIO_PINS-1:0] GPIO_Strength,            // Write/Read/Trigerable
    reg [GPIO_PINS-1:0] GPIO_Pulldown,            // Write/Read/Trigerable
    reg [GPIO_PINS-1:0] GPIO_Pullup*/            // Write/Read/Trigerable

    localparam GPIO_REG_BIT_TX_BUSY=8; // wire tx_busy;
    localparam GPIO_REG_BIT_RX_BUSY=9; // wire rx_busy;
    localparam GPIO_REG_BIT_RX_OVERRUN_ERROR=10; // wire rx_overrun_error;
    localparam GPIO_REG_BIT_RX_FRAME_ERROR=11; // wire rx_frame_error;
    localparam GPIO_REG_BIT_RX_OVERFLOW=12; // reg uart_overflow;
    localparam GPIO_REG_BIT_RX_NODUMP=13; // reg uart_nodump;
    
    // Axi bypass to uart tx
    /*
    reg [UART_DATA_WIDTH-1:0] uart_tx_axi_tdata;
    reg uart_tx_axi_tvalid;
    wire uart_tx_axi_tready;*/
    
    // State machine only
    /*
    reg [UART_DATA_WIDTH-1:0] uart_rx_data;    // Read only
    reg uart_dump;                            // Write only
    reg uart_dumped;                        // Read only
    reg uart_nodump;*/                        // Read only
    
    // Bus logic
    integer idx;
    reg [2:0] state;
    parameter st0_idle = 0, st1_waitrready = 1, st2_waitbready = 2, st3_tx_wait = 3, st4_rx_wait = 4;
    always @(posedge CLK)
    if (RST == 1'b0) begin
        state <= st0_idle;
        axi_bvalid <= 1'b0;
        axi_rvalid <= 1'b0;
        axi_rdata <= 0;
        uart_tx_axi_tdata <= 0;
        uart_tx_axi_tvalid <= 1'b0;
        uart_dump <= 1'b0;
        PROGADDR_IRQ <= 32'h00000000;
        
        is_pwm <= 0;
        is_irq <= 0;
        out_gpio <= 0;
        GPIO_Rx <= 2;                // Serial activation default
        GPIO_Tx <= 1;                // Serial activation default
        GPIO_Strength <= 0;
        GPIO_Pulldown <= 0;
        GPIO_Pullup <= 0;
        gpio_reg <= 32'h000000001;    // By default, is activated the serial
        prescaler_limit <= {PWM_PRESCALER_BITS{1'b1}};
        
        for(idx = 0; idx < GPIO_PWM; idx = idx + 1) begin
            pwm[idx] <= 0;
            limit_pre_count_pwm[idx] <= 0;
        end
    end    else begin 
        // Assign read-only
        gpio_reg[GPIO_REG_BIT_TX_BUSY] <= tx_busy;
        gpio_reg[GPIO_REG_BIT_RX_BUSY] <= rx_busy;
        gpio_reg[GPIO_REG_BIT_RX_OVERRUN_ERROR] <= rx_overrun_error;
        gpio_reg[GPIO_REG_BIT_RX_FRAME_ERROR] <= rx_frame_error;
        gpio_reg[GPIO_REG_BIT_RX_OVERFLOW] <= uart_overflow;
        gpio_reg[GPIO_REG_BIT_RX_NODUMP] <= uart_nodump;
        case (state)
        st0_idle :
            // TODO: Addressing is a bit... arithmetic
            // please replace this with a better addressing
            if (rassert) begin
                if(0 <= raddr[BITS_ADDR+1:2] && raddr[BITS_ADDR+1:2] < GPIO_PWM) begin
                    axi_rdata <= pwm[raddr[BITS_ADDR+1:2] - 0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if(GPIO_PWM <= raddr[BITS_ADDR+1:2] && raddr[BITS_ADDR+1:2] < 2*GPIO_PWM) begin
                    axi_rdata <= limit_pre_count_pwm[raddr[BITS_ADDR+1:2] - GPIO_PWM];
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= prescaler_limit;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+1) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= gpio_reg;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+2) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_PinIn;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+3) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= is_pwm;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+4) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= is_irq;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+5) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= out_gpio;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+6) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_Rx;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+7) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_Tx;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+8) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_Strength;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+9) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_Pulldown;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+10) == raddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= GPIO_Pullup;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+11) == raddr[BITS_ADDR+1:2]) begin    // Serial Rx
                    state <= st4_rx_wait;
                    uart_dump <= 1'b1;
                end else if((2*GPIO_PWM+28) == waddr[BITS_ADDR+1:2]) begin
                    axi_rdata <= PROGADDR_IRQ;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else begin
                    axi_rdata <= 0;
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end
            end    else if(wassert == 2'b11) begin
                if(0 <= waddr[BITS_ADDR+1:2] && waddr[BITS_ADDR+1:2] < GPIO_PWM) begin
                    pwm[waddr[BITS_ADDR+1:2] - 0] <= wdata[PWM_BITS:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if(GPIO_PWM <= waddr[BITS_ADDR+1:2] && waddr[BITS_ADDR+1:2] < 2*GPIO_PWM) begin
                    limit_pre_count_pwm[waddr[BITS_ADDR+1:2] - GPIO_PWM] = wdata[PWM_PRESCALER_BITS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM) == waddr[BITS_ADDR+1:2]) begin
                    prescaler_limit <= wdata[PWM_PRESCALER_BITS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+1) == waddr[BITS_ADDR+1:2]) begin
                    gpio_reg <= wdata;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+2) == waddr[BITS_ADDR+1:2]) begin
                    //GPIO_PinIn <= wdata[GPIO_PINS-1:0]; <-- Yeah, sure...
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+3) == waddr[BITS_ADDR+1:2]) begin
                    is_pwm <= wdata[GPIO_PWM-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+4) == raddr[BITS_ADDR+1:2]) begin
                    is_irq <= wdata[GPIO_IRQ-1:0];
                    state <= st1_waitrready;
                    axi_rvalid <= 1'b1;
                end else if((2*GPIO_PWM+5) == waddr[BITS_ADDR+1:2]) begin
                    out_gpio <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+6) == waddr[BITS_ADDR+1:2]) begin
                    GPIO_Rx <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+7) == waddr[BITS_ADDR+1:2]) begin
                    GPIO_Tx <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+8) == waddr[BITS_ADDR+1:2]) begin
                    GPIO_Strength <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+9) == waddr[BITS_ADDR+1:2]) begin
                    GPIO_Pulldown <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+10) == waddr[BITS_ADDR+1:2]) begin
                    GPIO_Pullup <= wdata[GPIO_PINS-1:0];
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+11) == waddr[BITS_ADDR+1:2]) begin    // Serial tx
                    uart_tx_axi_tdata <= wdata[UART_DATA_WIDTH-1:0];
                    uart_tx_axi_tvalid <= 1'b1;
                    state <= st3_tx_wait;
                end else if((2*GPIO_PWM+12) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PWM; idx=idx+1) if(wdata[idx]) is_pwm[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+13) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_IRQ; idx=idx+1) if(wdata[idx]) is_irq[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+14) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) out_gpio[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+15) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Rx[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+16) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Tx[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+17) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Strength[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+18) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Pulldown[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+19) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Pullup[idx] <= 1'b1;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+20) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PWM; idx=idx+1) if(wdata[idx]) is_pwm[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+21) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_IRQ; idx=idx+1) if(wdata[idx]) is_irq[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+22) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) out_gpio[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+23) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Rx[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+24) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Tx[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+25) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Strength[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+26) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Pulldown[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+27) == waddr[BITS_ADDR+1:2]) begin
                    for(idx = 0; idx < GPIO_PINS; idx=idx+1) if(wdata[idx]) GPIO_Pullup[idx] <= 1'b0;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else if((2*GPIO_PWM+28) == waddr[BITS_ADDR+1:2]) begin
                    PROGADDR_IRQ <= wdata;
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end else begin
                    // Invalid, just return the bready
                    state <= st2_waitbready;
                    axi_bvalid <= 1'b1;
                end
            end else begin
                state <= state;
            end
        st1_waitrready :
            if (axi_rready) begin
                axi_rvalid <= 1'b0;
                state <= st0_idle;
            end    else begin
                state <= state;
            end
        st2_waitbready :
            if (axi_bready) begin
                axi_bvalid <= 1'b0;
                state <= st0_idle;
            end    else begin
                state <= state;
            end
        st3_tx_wait :
            if (uart_tx_axi_tready) begin
                uart_tx_axi_tvalid <= 1'b0;
                state <= st2_waitbready;
                axi_bvalid <= 1'b1;
            end    else begin
                state <= state;
            end
        st4_rx_wait :
            if (uart_dumped) begin
                uart_dump <= 1'b0;
                axi_rdata <= uart_rx_data;
                state <= st1_waitrready;
                axi_rvalid <= 1'b1;
            end    else begin
                state <= state;
            end
        default: begin
            state <= st0_idle; end
        endcase
    end
        
    
endmodule
