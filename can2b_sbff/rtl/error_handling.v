// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : error_handling.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : Handles all Tx errors and Rx errors and trigger frame
//                generation also counts for TEC and REC.
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================
module error_handling (
    input        clk,
    input        rst,
    input        bit_error,
    input        form_error,
    input        ack_error,
    input        error_frame_sent,
    input        tx_mode,
    input        rx_error_flag,
    input        tx_error_flag,
    output reg   error_frame_req,
    output reg   error_passive,
    output reg   bus_off
);

reg error_latched;
reg [8:0] tec;
reg [7:0] rec;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        error_frame_req <= 0;
        error_latched <= 0;
        tec <= 0;
        rec <= 0;
        error_passive <= 0;
        bus_off <= 0;
    end else begin
        // Error latching
        if (bit_error || form_error || ack_error)
            error_latched <= 1;
        else if (error_frame_sent)
            error_latched <= 0;

        error_frame_req <= error_latched;

        // Error counter logic
        if (tx_error_flag) begin
            if (tec < 255)
                tec <= tec + 8'd8;
        end else if (tx_mode && !bit_error && !form_error && !ack_error) begin
            if (tec > 0)
                tec <= tec - 1;
        end

        if (rx_error_flag) begin
            if (rec < 127)
                rec <= rec + 1;
        end else if (!tx_mode && !bit_error && !form_error && !ack_error) begin
            if (rec > 0)
                rec <= rec - 1;
        end

        // State transitions
        error_passive <= (tec >= 128 || rec >= 128);
        bus_off <= (tec >= 256);
    end
end

endmodule
