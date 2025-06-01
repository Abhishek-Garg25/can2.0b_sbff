// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : bit_unstuffing.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : Bit unstuffing Module unstuff oposite polarity bit after
//                5 consecutive identical bits and generate stuff errors
//                for improper stuffed frames
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================

`timescale 1ns / 1ps

module bit_unstuffing (
    input  wire clk,
    input  wire rst,
    input  wire bit_in,
    input  wire bit_valid,
    output reg  bit_out,
    output reg  bit_out_valid,
    output reg  error_stuff
);

    reg [2:0] count;
    reg last_bit;
    reg initialized;
    reg skipping;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 3'd0;
            last_bit      <= 1'b0;
            initialized   <= 1'b0;
            skipping      <= 1'b0;
            bit_out       <= 1'b0;
            bit_out_valid <= 1'b0;
            error_stuff   <= 1'b0;
        end else begin
            bit_out_valid <= 1'b0;
            error_stuff   <= 1'b0;

            if (bit_valid) begin
                if (!initialized) begin
                    last_bit      <= bit_in;
                    bit_out       <= bit_in;
                    bit_out_valid <= 1'b1;
                    count         <= 3'd1;
                    initialized   <= 1'b1;
                    skipping      <= 1'b0;
                end else if (skipping) begin
                    // Expect a stuffed bit: it must be the inverse of last_bit
                    if (bit_in == ~last_bit) begin
                        // Valid stuffed bit, skip it
                        skipping <= 1'b0;
                        count    <= 3'd1;  // reset to 1 for new sequence
                    end else begin
                        // Stuffing violation
                        error_stuff <= 1'b1;
                        skipping    <= 1'b0;
                        count       <= 3'd0; // Reset everything on error
                        initialized <= 0;
                    end
                end else begin
                    // Normal data bit
                   if (bit_in == last_bit) begin
                        count <= count + 1;
                        bit_out <= bit_in;
                        bit_out_valid <= 1'b1;
                    
                        if (count == 3'd4) begin // <- FIXED HERE
                            skipping <= 1'b1;
                        end

                    end else begin
                        // Bit transition resets counter
                        count <= 3'd1;
                        skipping <= 1'b0;
                        bit_out <= bit_in;
                        bit_out_valid <= 1'b1;
                    end

                    
                end
                last_bit <= bit_in;
            end
        end
    end
endmodule
