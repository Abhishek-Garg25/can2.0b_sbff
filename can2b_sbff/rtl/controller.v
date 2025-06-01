// =============================================================================
// CAN 2.0B Verilog IP Core - Evaluation Version
// -----------------------------------------------------------------------------
// Filename     : can_controller_eval.v
// Author       : Abhishek Garg
// Version      : v1.0-EVAL
// Description  : Evaluation-only version of the CAN 2.0B controller module.
//                Extended ID (29-bit) support is disabled. Synthesis is blocked.
//                Redistribution or production use is prohibited.
// =============================================================================

`ifndef SYNTHESIS
    initial begin
        $display("🔒 This is an EVALUATION VERSION of the CAN2B controller.");
        $display("❌ Synthesis is blocked. Only 11-bit standard CAN ID is allowed.");
    end
`endif

module can_controller (
    input        clk,              // Clock
    input        rst,              // Reset
    input wire [7:0]  brp,             // Baud Rate Prescaler
    input wire [3:0]  tseg1,           // Time Segment 1
    input wire [3:0]  tseg2,           // Time Segment 2
    input wire [3:0]  sjw,             // Synchronization Jump Width
    input        tx_start,         // Start transmission
    input  [28:0] id,              // Frame ID
    input        ide,              // Identifier Extension (IDE)
    input        rtr,              // Remote Transmission Request (RTR)
    input  [3:0] dlc,              // Data Length Code (DLC)
    input  [63:0] data,            // Data
    input        ack_received,     // Acknowledge received from the bus
    input        rx,       // Sampled bit on the bus       
    output [3:0]  rx_dlc,          // Received data length code
    output        rx_ide,            // Received IDE bit
    output        rx_rtr,            // Received RTR bit
    output       tx,           // Transmit bit (to CAN bus)
    output       tx_done,          // Transmission done signal
    output       busy,             // Bus is busy
    output       rx_data_valid,    // Received data valid
    output [63:0] rx_data,         // Received data
    output [28:0] rx_id            // Received frame ID
);

// Evaluation-only limitation: block extended identifier usage
always @(*) begin
    if (ide) begin
        $display("❌ Extended identifiers (IDE=1) not supported in evaluation version.");
        $stop;
    end
end

    // Internal Signals
    wire        can_tx_busy;
    wire        can_tx_done;
    wire        can_rx_done;
    wire [63:0] can_rx_data;
    wire [28:0] can_rx_id;
    wire         arbitration_lost;
    wire         abort;
    wire bit_error_tx, form_error_tx, ack_error_tx;
    wire stuff_error_rx, form_error_rx, crc_error_rx;
    wire error_frame_req_tx;
    wire error_frame_sent;
    wire tx_error_flag;
    wire rx_error;
    wire error_passive;
    wire bus_off;
    
    // Internal wires for bit timing and CAN modules
    wire tq_pulse;
    wire bit_start;
    wire sample_point;
    // Instantiate the bit timing module
    bit_timing bit_timing_inst (
        .clk(clk),
        .rst(rst),
        .brp(brp),
        .tseg1(tseg1),
        .tseg2(tseg2),
        .sjw(sjw),
        .sample_point(sample_point),
        .tq_pulse(tq_pulse),
        .bit_start(bit_start)
    );
    // CAN Transmitter Instance (from your previously provided code)
    can_tx u_can_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .id(id),
        .ide(ide),
        .rtr(rtr),
        .dlc(dlc),
        .data(data),
        .ack_received(ack_received),
        .rx(rx),
        .bit_start(bit_start),
        .sample_point(sample_point),
        .tx_bit(tx),
        .tx_done(can_tx_done),
        .arbitration_lost(arbitration_lost),
        .abort(abort),
        .bit_error(bit_error_tx),
        .form_error(form_error_tx),
        .ack_error(ack_error_tx),
        .error_frame_sent(error_frame_sent),
        .error_frame_req(error_frame_req_tx),
        .busy(can_tx_busy)
    );

    
    // CAN Receiver Instance (from your previously provided code)
    can_rx u_can_rx (
            .clk(clk),
            .rst(rst),
            .rx(rx),
            .sample_point(sample_point),
            .rx_valid(can_rx_done),
            .rx_data(can_rx_data),
            .rx_error(rx_error),
            .rx_id(can_rx_id),
            .rx_dlc(rx_dlc),
            .rx_ide(rx_ide),
            .stuff_error(stuff_error_rx),
            .form_error(form_error_rx),
            .crc_error(crc_error_rx),
            .rx_rtr(rx_rtr)
        );
        
assign tx_error_flag = bit_error_tx||ack_error_tx||form_error_tx;

    error_handling error_inst (
        .clk(clk),
        .rst(rst),
        .bit_error(bit_error_tx||stuff_error_rx),       // connect tx error
        .form_error(form_error_tx||form_error_rx||crc_error_rx),     // optionally, or from rx
        .ack_error(ack_error_tx),       // optionally, or from rx
        .error_frame_sent(error_frame_sent),
        .error_frame_req(error_frame_req_tx),
        .tx_mode(can_tx_busy),
        .tx_error_flag(tx_error_flag),
        .rx_error_flag(rx_error),
        .error_passive(error_passive),
        .bus_off(bus_off)
     );

    // Control Logic: Manage Transmit and Receive
    assign tx_done = can_tx_done;
    assign busy = can_tx_busy;

    // Assign Received Data and ID
    assign rx_data_valid = can_rx_done;
    assign rx_data = can_rx_data;
    assign rx_id = can_rx_id;
    assign abort = arbitration_lost;
endmodule
