// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : bit_stuffing.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : Bit Stuffing Module stuff oposite polarity bit after
//                5 consecutive identical bits
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================

module bit_stuffing (
    input        clk,
    input        rst,
    input        data_in,
    input reg    data_valid,
    input        bit_start,
    output reg   data_out,
    output reg   data_out_valid,
    output reg   stuffing_busy
);

    reg [2:0] cnt;
    reg last_bit;
    reg fsm_initialized;
    reg stuffing;

    reg buffer_valid;
    reg buffer_bit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt             <= 3'd0;
            last_bit        <= 1'b0;
            data_out        <= 1'b0;
            data_out_valid  <= 1'b0;
            stuffing_busy   <= 1'b0;
            fsm_initialized <= 1'b0;
            stuffing        <= 1'b0;
            buffer_valid    <= 1'b0;
            buffer_bit      <= 1'b0;
        end else if (bit_start) begin
            data_out_valid <= 1'b0;

            if (stuffing) begin
                // Send the stuffed bit (opposite of last_bit)
                data_out       <= ~last_bit;
                buffer_bit     <= data_in;
                data_out_valid <= 1'b1;
                stuffing       <= 1'b0;
                stuffing_busy  <= 1'b0;
                buffer_valid   <= 1'b1;  // 6th bit will be sent next
            end else if (buffer_valid) begin
                // Now send the 6th real bit
                data_out       <= buffer_bit;
                data_out_valid <= 1'b1;
                last_bit       <= buffer_bit;
                buffer_valid   <= 1'b0;
                cnt            <= 3'd1;  // Restart count from 1
            end else if (!fsm_initialized && data_valid) begin
                data_out        <= data_in;
                data_out_valid  <= 1'b1;
                last_bit        <= data_in;
                cnt             <= 3'd1;
                fsm_initialized <= 1'b1;
            end else if (data_valid) begin
                if (data_in == last_bit) begin
                    if (cnt == 3'd4) begin
                        // Hold back 6th bit and send stuffed bit now
                        stuffing       <= 1'b1;
                        stuffing_busy  <= 1'b1;
                        data_out       <= data_in;
                        last_bit       <= data_in; 
                        // Do not output anything this cycle
                    end else if(cnt <= 3'd4) begin
                        // Less than 5 same bits, just send it
                        cnt            <= cnt + 1;
                        data_out       <= data_in;
                        data_out_valid <= 1'b1;
                        last_bit       <= data_in;
                    end
                end else begin
                    // Bit change resets the counter
                    cnt            <= 3'd1;
                    data_out       <= data_in;
                    data_out_valid <= 1'b1;
                    last_bit       <= data_in;
                end
            end
        end
    end
endmodule
