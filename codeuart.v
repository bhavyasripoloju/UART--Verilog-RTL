// ====================================================================
// 1. BAUD RATE GENERATOR MODULE
// ====================================================================
module baud_rate_generator (
    input wire clk,
    input wire rst,
    output reg tx_enb,
    output reg rx_enb
);
    // Counters based on 50 MHz clock and 9600 Baud Rate
    reg [12:0] tx_counter; // Up to 5208 (2^13 = 8192)
    reg [8:0]  rx_counter; // Up to 325  (2^9 = 512)

    // RX Enable Generation (Oversampling clock: 9600 * 16 = 153600 Hz)
    // 50,000,000 / 153,600 = 325.5 -> Count 0 to 324
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_counter <= 0;
            rx_enb     <= 0;
        end else begin
            if (rx_counter == 324) begin
                rx_counter <= 0;
                rx_enb     <= 1;
            end else begin
                rx_counter <= rx_counter + 1;
                rx_enb     <= 0;
            end
        end
    end

    // TX Enable Generation (Standard Baud rate clock: 9600 Hz)
    // 50,000,000 / 9,600 = 5208.3 -> Count 0 to 5207
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_counter <= 0;
            tx_enb     <= 0;
        end else begin
            if (tx_counter == 5207) begin
                tx_counter <= 0;
                tx_enb     <= 1;
            end else begin
                tx_counter <= tx_counter + 1;
                tx_enb     <= 0;
            end
        end
    end
endmodule


// ====================================================================
// 2. UART TRANSMITTER (TX) MODULE
// ====================================================================
module uart_transmitter (
    input wire clk,
    input wire rst,
    input wire tx_enb,       // From Baud Generator
    input wire wr_enb,       // Write enable from Testbench/System
    input wire [7:0] data_in,// 8-bit parallel data input
    output reg tx,           // Serial output
    output wire busy         // Status indicator
);
    // State Encoding matching your notes
    parameter IDLE  = 2'b00;
    parameter START = 2'b01;
    parameter DATA  = 2'b10;
    parameter STOP  = 2'b11;

    reg [1:0] state;
    reg [7:0] data_reg;
    reg [2:0] bit_index; // To track 8 bits of data (0 to 7)

    // Busy signal logic: High whenever we aren't idle
    assign busy = (state != IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1; // Idle line high
            bit_index <= 0;
            data_reg  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (wr_enb) begin
                        data_reg <= data_in; // Latch input data
                        state    <= START;
                    end
                end

                START: begin
                    if (tx_enb) begin
                        tx    <= 1'b0; // Start bit is low
                        state <= DATA;
                        bit_index <= 0;
                    end
                end

                DATA: begin
                    if (tx_enb) begin
                        tx <= data_reg[bit_index];
                        if (bit_index == 7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end
                end

                STOP: begin
                    if (tx_enb) begin
                        tx    <= 1'b1; // Stop bit is high
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule


// ====================================================================
// 3. UART RECEIVER (RX) MODULE
// ====================================================================
module uart_receiver (
    input wire clk,
    input wire rst,
    input wire rx_enb,        // 16x oversampling tick
    input wire rx,            // Serial input line
    output reg rdy,           // Data ready pulse
    output reg [7:0] data_out // Parallel 8-bit output
);
    parameter IDLE  = 2'b00;
    parameter START = 2'b01;
    parameter DATA  = 2'b10;
    parameter STOP  = 2'b11;

    reg [1:0] state;
    reg [3:0] sample_count; // Tracks 16 ticks per bit
    reg [2:0] bit_index;    // Tracks 8 data bits
    reg [7:0] rx_shift_reg; // Holds incoming bits

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            sample_count <= 0;
            bit_index    <= 0;
            rx_shift_reg <= 0;
            data_out     <= 0;
            rdy          <= 0;
        end else begin
            rdy <= 0; // Default pulse state
            
            if (rx_enb) begin
                case (state)
                    IDLE: begin
                        if (rx == 1'b0) begin // Detect falling edge (Start bit)
                            sample_count <= 0;
                            state        <= START;
                        end
                    end

                    START: begin
                        if (sample_count == 7) begin // Center of start bit
                            if (rx == 1'b0) begin
                                sample_count <= 0;
                                bit_index    <= 0;
                                state        <= DATA;
                            end else begin
                                state <= IDLE; // False start bit reset
                            end
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end

                    DATA: begin
                        if (sample_count == 15) begin // Center of data bit
                            sample_count <= 0;
                            rx_shift_reg[bit_index] <= rx; // Sample bit
                            
                            if (bit_index == 7) begin
                                state <= STOP;
                            end else begin
                                bit_index <= bit_index + 1;
                            end
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end

                    STOP: begin
                        if (sample_count == 15) begin // Center of stop bit
                            if (rx == 1'b1) begin    // Valid stop bit check
                                data_out <= rx_shift_reg;
                                rdy      <= 1'b1;     // Pulse high for 1 clock cycle
                            end
                            state <= IDLE;
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule


// ====================================================================
// 4. TOP-LEVEL STRUCTURAL SYSTEM WRAPPER
// ====================================================================
module uart_top (
    input wire clk,
    input wire rst,
    input wire wr_enb,
    input wire [7:0] tx_data_in,
    output wire tx_serial_line,
    output wire tx_busy,
    output wire rx_data_rdy,
    output wire [7:0] rx_data_out
);
    wire tx_enb_sig;
    wire rx_enb_sig;

    // Instantiating Baud Rate Generator
    baud_rate_generator baud_gen (
        .clk(clk),
        .rst(rst),
        .tx_enb(tx_enb_sig),
        .rx_enb(rx_enb_sig)
    );

    // Instantiating Transmitter
    uart_transmitter tx_mod (
        .clk(clk),
        .rst(rst),
        .tx_enb(tx_enb_sig),
        .wr_enb(wr_enb),
        .data_in(tx_data_in),
        .tx(tx_serial_line),
        .busy(tx_busy)
    );

    // Instantiating Receiver (Internally looping TX back into RX)
    uart_receiver rx_mod (
        .clk(clk),
        .rst(rst),
        .rx_enb(rx_enb_sig),
        .rx(tx_serial_line), 
        .rdy(rx_data_rdy),
        .data_out(rx_data_out)
    );
endmodule