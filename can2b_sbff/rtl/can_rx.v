// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : can_rx.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : CAN Receiver module for CAN 2.0B protocol. Handles bit
//                unstuffing, arbitration, data parsing, and CRC-15 generation.
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================

`timescale 1ns / 1ps

module can_rx (
    input         clk,
    input         rst,
    input         rx,
    input         sample_point,
    output reg    rx_valid,
    output reg    rx_error,
    output reg [28:0] rx_id,
    output reg    rx_ide,
    output reg    rx_rtr,
    output reg [3:0] rx_dlc,
    output reg [63:0] rx_data,
    output reg form_error,
    output reg crc_error,
    output wire stuff_error 
);

    typedef enum logic [3:0] {
        IDLE, SOF, ARBITRATION, ARBITRATION_EXT, CONTROL,
        DATA, CRC, CRC_DELIM, ACK_SLOT, ACK_DELIM, EOF, ERROR
    } state_t;

    state_t state, next_state;

    reg [5:0] bit_cnt;
    reg [5:0] data_cnt;
    reg [2:0] eof_cnt;
    reg [3:0] prev_state;
    reg [28:0] id_shift;
    reg [3:0]  dlc_shift;
    reg [3:0]  rx_dlc_latched;
    reg [63:0] data_shift;
    reg [14:0] crc_shift;
    reg        crc_enable;
    reg        crc_enable_d;
    reg        ide_flag_latched;
    reg        arbitration_done;
    reg        dlc_done;
    reg        eof_done;
    wire [3:0] rx_dlc_next;
    reg [14:0] crc_shift_latched;
    reg        data_done;
    reg        data_start;
    reg        rx_sampled;
    wire       unstuffed_bit, unstuffed_valid;
    wire [14:0] crc_out;
    reg [10:0] base_id_shift;
    reg [17:0] ext_id_shift;

    
    // CRC generator instance
    crc15 crc15_inst (
        .clk(clk),
        .rst(rst),
        .data_valid(unstuffed_valid && crc_enable),
        .data_in(unstuffed_bit),
        .crc_out(crc_out)
    );

    // Bit unstuffing instance
    bit_unstuffing bit_unstuffing_inst (
        .clk(clk),
        .rst(rst),
        .bit_in(rx_sampled),
        .bit_valid(sample_point),
        .bit_out(unstuffed_bit),
        .bit_out_valid(unstuffed_valid),
        .error_stuff(stuff_error)
    );
    
    function [14:0] reverse15;
        input [14:0] in;
        integer i;
        begin
            for (i = 0; i < 15; i = i + 1)
                reverse15[i] = in[14 - i];
        end
    endfunction

    // Sample rx on sample_point
    always @(posedge clk or posedge rst)
        if (rst)
            rx_sampled <= 1'b1;
        else if (sample_point)
            rx_sampled <= rx;

    // CRC enable signal
    always @(posedge clk or posedge rst) begin
        if (rst)
            crc_enable <= 0;
        else if (unstuffed_valid) begin
            case (state)
                IDLE:
                    if (!unstuffed_bit)
                        crc_enable <= 1;
                ARBITRATION,
                ARBITRATION_EXT,
                CONTROL:
                    crc_enable <= 1;
                DATA: begin
                    crc_enable <= 1;
                    if (bit_cnt == (rx_dlc_latched * 8) - 1) begin
                        crc_enable <= 0;
                    end
                end
                default:
                    crc_enable <= 0;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            prev_state <= SOF;
        else
            prev_state <= state;
    end

    // Data parsing logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_id      <= 0;
            rx_ide     <= 0;
            rx_rtr     <= 0;
            rx_dlc     <= 0;
            rx_dlc_latched <= 0;
            rx_data    <= 0;
            id_shift   <= 0;
            dlc_shift  <= 0;
            data_shift <= 0;
            crc_shift  <= 0;
 //           crc_error <= 0;
            form_error <= 0;
            ide_flag_latched <= 0;
            rx_error <= 0;
            state <= IDLE;
        end else if (unstuffed_valid) begin
            case (state)
                IDLE: begin
                // Only reset fields when starting a new frame (SOF detected)
                    if (!unstuffed_bit) begin
                        eof_cnt <= 0;
//                        rx_valid <= 0;
                        rx_id <= 0;
                        rx_ide <= 0;
                        rx_rtr <= 0;
                        rx_dlc <= 0;
                        rx_dlc_latched <= 0;
                        rx_data <= 0;
                        id_shift <= 0;
                        dlc_shift <= 0;
                        data_shift <= 0;
                        crc_shift <= 0;
  //                      crc_error <= 0;
                        ide_flag_latched <= 0;
                        rx_error <= 0;
                        data_cnt <= 0;
                        bit_cnt <= 0;
                        form_error <= 0;
                        eof_done <= 0;
                        state <= ARBITRATION;
                     end
                end


                SOF: begin
                    id_shift <= 0;
                    dlc_shift <= 0;
                    data_shift <= 0;
                    crc_shift <= 0;
                    rx_error <= 0;
                    bit_cnt <= 0;
                    state <= ARBITRATION;
                end

               ARBITRATION: begin
                    if (bit_cnt < 11) begin
                        base_id_shift <= {base_id_shift[9:0], unstuffed_bit};  // 11 bits
                    end else if (bit_cnt == 11) begin
                        rx_rtr <= unstuffed_bit;  // Standard RTR or SRR
                    end else if (bit_cnt == 12) begin
                        rx_ide <= unstuffed_bit;  // IDE bit
                        ide_flag_latched <= unstuffed_bit;
                
                        if (unstuffed_bit) begin  // Extended frame
                            bit_cnt <= 0;         // ? Reset bit counter
							$display("❌ Extended ID received – not supported in eval");
							rx_error = 1'b1;
                            state <= ERROR;
                        end else begin            // Standard frame
                            rx_id <= base_id_shift;  // Assign full 11-bit ID
                            bit_cnt <= 0;            // ? Reset bit counter
                            state <= CONTROL;
                        end
                    end
                    if(bit_cnt == 12)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1;
                    
                end



                ARBITRATION_EXT: begin

                    if (bit_cnt < 18) begin
                        ext_id_shift <= {ext_id_shift[16:0], unstuffed_bit};
                    end else if (bit_cnt == 18) begin
                        rx_rtr <= unstuffed_bit;
                        rx_id <= {base_id_shift, ext_id_shift};  // Combine 11 + 18 bits into 29-bit ID
                        bit_cnt <= 0;
                        state <= CONTROL;
                    end 
                    if(bit_cnt == 18)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1;

                end

               CONTROL: begin
                    if(!rx_ide) begin
                        case (bit_cnt)
                            1, 2, 3: begin
                                dlc_shift <= {dlc_shift[2:0], unstuffed_bit};  // DLC[3:1]
                            end
                            4: begin
                                rx_dlc <= {dlc_shift[2:0], unstuffed_bit};     // Final DLC[3:0]
                                rx_dlc_latched <= ({dlc_shift[2:0], unstuffed_bit} > 8) ? 8 : {dlc_shift[2:0], unstuffed_bit};
                                dlc_done <= 1;
                            end
                            default: dlc_done <= 0;
                        endcase
                        if(bit_cnt == 4) begin
                            bit_cnt <= 0;
                            state <= DATA;
                       end else
                            bit_cnt <= bit_cnt + 1;
                     end else begin
                            case (bit_cnt)
                                 2, 3, 4: begin
                                     dlc_shift <= {dlc_shift[2:0], unstuffed_bit};  // DLC[3:1]
                                 end
                                 5: begin
                                     rx_dlc <= {dlc_shift[2:0], unstuffed_bit};     // Final DLC[3:0]
                                     rx_dlc_latched <= ({dlc_shift[2:0], unstuffed_bit} > 8) ? 8 : {dlc_shift[2:0], unstuffed_bit};
                                     dlc_done <= 1;
                                 end
                                 default: dlc_done <= 0;
                             endcase
                             if(bit_cnt == 5) begin
                                  bit_cnt <= 0;
                                  state <= DATA;
                             end else
                                  bit_cnt <= bit_cnt + 1;
                        end
                end

               DATA: begin
                    if (bit_cnt < (rx_dlc_latched * 8)) begin
                        data_shift <= {data_shift[62:0], unstuffed_bit};                       
                    end
                    
                    if (bit_cnt == (rx_dlc_latched * 8 - 1)) begin
                        rx_data <= {data_shift[62:0], unstuffed_bit};  // Correct alignment                                                                      
                        state <= CRC;
                        bit_cnt <= 0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                CRC: begin
                    crc_shift <= {crc_shift[13:0], unstuffed_bit};
                    if (bit_cnt == 14) begin
                        bit_cnt <= 0;
                        state <= CRC_DELIM;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
                
                CRC_DELIM: begin
                    if (!unstuffed_bit) begin
                        rx_error <= 1;
                        state <= ERROR;
                    end else if (crc_error) begin
                        rx_error <= 1;
                        state <= ERROR;
                    end else begin
                        state <= ACK_SLOT;
                        bit_cnt <= 0;
                    end
                end
                
                ACK_SLOT: begin
                    state <= ACK_DELIM;
                    bit_cnt <= 0;
                    // Optional: could check if rx_sampled == 0 to confirm acknowledgment sent by another node
                end
                
                ACK_DELIM: begin
                    if (!unstuffed_bit) begin
                        rx_error <= 1; // ACK delimiter must be recessive
                    end else begin
                        state <= EOF;
                        bit_cnt <= 0;
                    end
                end
                
                EOF: begin
                    if (!unstuffed_bit)
                        form_error <= 1;  // If any bit in EOF is dominant, it's a form error
                        rx_error <= 1;
                    if (eof_cnt == 6) begin
                        state <= IDLE;
                        eof_done <= 1;
                    end
                    eof_cnt <= eof_cnt + 1;
                end

                ERROR: begin
                    if (rx_sampled) begin
                        eof_cnt <= eof_cnt + 1;
                        if (eof_cnt == 6) begin
                            eof_cnt <= 0;
                            state <= IDLE;
                        end
                    end else begin
                        eof_cnt <= 0;
                    end
                end

            endcase
            if (stuff_error && (state != IDLE && state != ERROR)) begin
                state <= ERROR;
                rx_error <= 1;
            end
        end
    end
    
    
    // Compare one cycle later, after CRC is fully loaded and stable
    always @(posedge clk or posedge rst) begin
        if (rst)
            crc_error <= 0;
        else if (unstuffed_valid && state == CRC && bit_cnt == 15)
            crc_error <= (reverse15(crc_shift) != crc_out);
    end
    
   reg eof_done_d;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            eof_done_d <= 0;
  //          rx_valid <= 0;
        end else begin
            eof_done_d <= eof_done;
            rx_valid <= eof_done & ~eof_done_d;  // pulse only on rising edge of eof_done
        end
    end

    
    // Debugging (Optional)
//    always @(posedge clk) begin
//        if (sample_point)
//            $display("Time: %0t | Bit Count: %0d | rx: %b", $time, bit_cnt, rx);
//        if (rx_valid)
//            $display("rx_valid: ID=%h, IDE=%b, RTR=%b, DLC=%d, Data=%h", rx_id, rx_ide, rx_rtr, rx_dlc, rx_data);
//    end

endmodule


