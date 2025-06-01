// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : bit_timing.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : Fully synthesizable Verilog implementation of a CAN 2.0B
//                compliant bit timing module.
//                bit_start -> can_tx
//                sample_point -> can_rx
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================

module bit_timing (
    input        clk,
    input        rst,
    input [7:0]  brp,        // Baud Rate Prescaler
    input [3:0]  tseg1,      // Time Segment 1
    input [3:0]  tseg2,      // Time Segment 2
    input [3:0]  sjw,        // Sync Jump Width (unused here)
    output reg   sample_point,
    output reg   tq_pulse,
    output reg   bit_start   // New output: one pulse per bit time
);

    reg [7:0] tq_counter;
    reg [4:0] bit_time_cnt;  // Count TQs in one bit time
    wire [4:0] total_tq = tseg1 + tseg2 + 1;  // +1 for SYNC_SEG

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tq_counter    <= 0;
            bit_time_cnt  <= 0;
            sample_point  <= 0;
            tq_pulse      <= 0;
            bit_start     <= 0;
        end else begin
            if (tq_counter == brp) begin
                tq_counter <= 0;
                tq_pulse   <= 1;

                // At beginning of bit time
                bit_start <= (bit_time_cnt == 0);

                // Generate sample point after SYNC_SEG + TSEG1
                sample_point <= (bit_time_cnt == tseg1);

                // Update bit time counter
                if (bit_time_cnt == total_tq - 1)
                    bit_time_cnt <= 0;
                else
                    bit_time_cnt <= bit_time_cnt + 1;
            end else begin
                tq_counter    <= tq_counter + 1;
                tq_pulse      <= 0;
                sample_point  <= 0;
                bit_start     <= 0;
            end
        end
    end
endmodule
