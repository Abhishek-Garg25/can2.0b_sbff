// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : can_tx.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : CAN Transmitter module for CAN 2.0B protocol. Handles bit
//                stuffing, arbitration, data framing, and CRC-15 generation.
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================

module can_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [10:0] id,
    input        ide,
    input        rtr,
    input  [3:0] dlc,
    input  [63:0] data,
    input        ack_received,
    input       rx,
    input        bit_start,
    input         sample_point,
    input   reg     error_frame_req,
    output  reg     error_frame_sent,
    output reg      bit_error,
    output reg      form_error,
    output reg      ack_error,
    input wire   abort,               // from controller
    output reg   tx_bit,
    output reg   tx_done,
    output reg   busy,
    output reg arbitration_lost
);

// FSM States
typedef enum logic [4:0] {
    IDLE, SOF, ARBITRATION, ARBITRATION_EXT, CONTROL, DATA,
    CRC, CRC_DELIM, ACK_SLOT, ACK_DELIM,
    EOF, INTERMISSION, ERROR_FRAME
} can_tx_state_t;


can_tx_state_t state, next_state;


// Internal Registers
reg [5:0] bit_cnt;
reg current_bit;
reg is_extended;
reg data_len;
reg [2:0] eof_cnt;
reg [1:0] ifs_cnt;
reg prev_tx_bit;
reg rx_sampled;
reg retry_pending;              // internal
reg [1:0] intermission_cnt;     // for 3-bit Intermission before retry


// Bit Stuffing Inputs and Latching
reg raw_bit;
reg raw_bit_valid;
reg latched_raw_bit;
reg latched_valid;
wire stuffed_bit;
wire stuffed_bit_valid;
wire stuffing_busy;
// CRC
wire [14:0] crc_out;
reg crc_rst;
reg crc_enable;


// Modules Instantiation
bit_stuffing bit_stuffing_inst (
    .clk(clk), .rst(rst),
    .data_in(raw_bit), .data_valid(raw_bit_valid), .bit_start(bit_start),
    .data_out(stuffed_bit), .data_out_valid(stuffed_bit_valid),.stuffing_busy(stuffing_busy)
);

crc15 crc_inst (
    .clk(clk), .rst(rst),
    .data_in(raw_bit), .data_valid(raw_bit_valid && crc_enable),
    .crc_out(crc_out)
);


// Add a flag to track when transmission has started
reg tx_started;

// Sample rx on sample_point
    always @(posedge clk or posedge rst)
        if (rst)
            rx_sampled <= 1'b1;
        else if (sample_point)
            rx_sampled <= rx;
            


always @(posedge clk or posedge rst) begin
    if (rst) begin
        tx_started <= 0;
        busy <= 0;
    end else if (tx_start && state == IDLE) begin
        tx_started <= 1;  // Transmission starts when leaving IDLE
        busy <= 1;
    end else if (state == EOF && eof_cnt == 6) begin
        tx_started <= 0;  // Transmission ends after EOF field is complete
        busy <= 0;
    end
end


always @(posedge clk or posedge rst) begin
    if (rst)
        crc_enable <= 0;
    else case (state)
        SOF, ARBITRATION, ARBITRATION_EXT, CONTROL, DATA:
            crc_enable <= 1;
        default:
            crc_enable <= 0;
    endcase
end



// Bit latch logic

always @(posedge clk or posedge rst) begin
    if (rst) begin
        latched_raw_bit <= 1;
        latched_valid <= 0;
    end else if (bit_start && raw_bit_valid) begin
        latched_raw_bit <= raw_bit;
        latched_valid <= 1;
       // raw_bit_valid <= 0;
    end else begin
        latched_valid <= 0;
    end
end

//-----------------------------------------
// Transmission Logic
//-----------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        raw_bit <= 1'b1;
        raw_bit_valid <= 0;
 //       latched_raw_bit <= 1;
 //       latched_valid <= 0;
        bit_cnt <= 0;
//        tx_bit <= 1;
        tx_done <= 0;
        arbitration_lost <= 0;
        state <= IDLE;
    end else if(bit_start) begin
        if (abort && state != IDLE) begin
            //tx_bit <= 1'b1;       // release the bus (recessive)
            tx_done <= 1'b1;      // notify controller of abort
            state <= IDLE;        // reset to IDLE
            bit_cnt <= 0;
            raw_bit_valid <= 0;
//            crc_rst <= 1;         // reset CRC
//            tx_started <= 0;      // clear busy
    end else begin
       // raw_bit_valid <= 1'b0;
        case (state)
            IDLE: begin
                tx_done <= 0;
                if (tx_started) begin
                    state <= SOF;
                end else begin
                    state <= IDLE;
                end
                bit_cnt <= 0;              
            end
            
            SOF: begin                
                raw_bit <= 1'b0;          // SOF bit is always 0
                raw_bit_valid <= 1'b1;    // Strobe the bit
                state <= ARBITRATION;                
            end


            ARBITRATION: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    if(ide) begin
                        case (bit_cnt)
                            0  : raw_bit <= id[28];
                            1  : raw_bit <= id[27];
                            2  : raw_bit <= id[26];
                            3  : raw_bit <= id[25];
                            4  : raw_bit <= id[24];
                            5  : raw_bit <= id[23];
                            6  : raw_bit <= id[22];
                            7  : raw_bit <= id[21];
                            8  : raw_bit <= id[20];
                            9  : raw_bit <= id[19];
                            10 : raw_bit <= id[18];
                            11 : raw_bit <= 1'b1;     // SRR (always recessive in extended)
                            12 : raw_bit <= 1'b1;     // IDE (always recessive in extended)
                        endcase
                        
                        if (bit_cnt == 12) begin
                            bit_cnt <= 0;
                            state <= ARBITRATION_EXT;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
    
                      end else begin
                            case (bit_cnt)
                                  0  : raw_bit <= id[10];
                                  1  : raw_bit <= id[9];
                                  2  : raw_bit <= id[8];
                                  3  : raw_bit <= id[7];
                                  4  : raw_bit <= id[6];
                                  5  : raw_bit <= id[5];
                                  6  : raw_bit <= id[4];
                                  7  : raw_bit <= id[3];
                                  8  : raw_bit <= id[2];
                                  9  : raw_bit <= id[1];
                                  10 : raw_bit <= id[0];
                                  11 : raw_bit <= rtr;
                                  12 : raw_bit <= 1'b0; // IDE = 0
                                  default: raw_bit <= 1'b0;
                              endcase
                               if (bit_cnt == 12) begin
                                   bit_cnt <= 0;
                                   state <= CONTROL;
                               end else
                                   bit_cnt <= bit_cnt + 1;
                            end
                           if (latched_valid && latched_raw_bit == 1'b1 && rx_sampled == 1'b0) begin  // arbitration lost
                                arbitration_lost <= 1'b1;
                                retry_pending <= 1'b1;
                                state <= INTERMISSION;
              //                  tx_bit <= 1'b1;  // release bus
                                intermission_cnt <= 2'd0;
                            end
     
                end           
            end

            
           ARBITRATION_EXT: begin
               if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    case (bit_cnt)
                        0  : raw_bit <= id[17];
                        1  : raw_bit <= id[16];
                        2  : raw_bit <= id[15];
                        3  : raw_bit <= id[14];
                        4  : raw_bit <= id[13];
                        5  : raw_bit <= id[12];
                        6  : raw_bit <= id[11];
                        7  : raw_bit <= id[10];
                        8  : raw_bit <= id[9];
                        9  : raw_bit <= id[8];
                        10 : raw_bit <= id[7];
                        11 : raw_bit <= id[6];
                        12 : raw_bit <= id[5];
                        13 : raw_bit <= id[4];
                        14 : raw_bit <= id[3];
                        15 : raw_bit <= id[2];
                        16 : raw_bit <= id[1];
                        17 : raw_bit <= id[0];
                        18 : raw_bit <= rtr;
                        default: raw_bit <= 1'b0;
                    endcase                
                    if (bit_cnt == 18) begin
                        bit_cnt <= 0;
                        state <= CONTROL;
                    end else
                        bit_cnt <= bit_cnt + 1;
                end
            end

            CONTROL: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                
                    if (ide) begin
                        // Extended frame: r1, r0, DLC[3:0]
                        case (bit_cnt)
                            0: raw_bit <= 1'b0;            // r1
                            1: raw_bit <= 1'b0;            // r0
                            2: raw_bit <= dlc[3];      // DLC[3]
                            3: raw_bit <= dlc[2];      // DLC[2]
                            4: raw_bit <= dlc[1];      // DLC[1]
                            5: raw_bit <= dlc[0];      // DLC[0]
                            default: raw_bit <= 1'b0;
                        endcase
                        
                
                        // Transition after 6 bits
                        if (bit_cnt == 5) begin
                            state <= ((dlc) == 0 || rtr) ? CRC : DATA;
                            bit_cnt <= 0;
                        end else
                             bit_cnt <= bit_cnt + 1;
                    end else begin
                        // Standard frame: r0, DLC[3:0]
                        case (bit_cnt)
                            0: raw_bit <= 1'b0;            // r0
                            1: raw_bit <= dlc[3];      // DLC[3]
                            2: raw_bit <= dlc[2];      // DLC[2]
                            3: raw_bit <= dlc[1];      // DLC[1]
                            4: raw_bit <= dlc[0];      // DLC[0]
                            default: raw_bit <= 1'b0;
                        endcase
                                   
                        // Transition after 5 bits
                        if (bit_cnt == 4) begin
                            state <= ((dlc) == 0 || rtr) ? CRC : DATA;
                            bit_cnt <= 0;
                        end else
                            bit_cnt <= bit_cnt + 1;
                    end
                end
            end


            DATA: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                
                    // Transmit data MSB-first
                    raw_bit <= data[63 - bit_cnt];
                        
                    // Once all bits for given DLC are transmitted
                    if (bit_cnt == (dlc * 8 - 1)) begin
                        bit_cnt <= 0;
                        state <= CRC;
                    end else
                        bit_cnt <= bit_cnt + 1;
                end
            end


            CRC: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                
                    // Send 15 CRC bits MSB-first
                    raw_bit <= crc_out[14 - bit_cnt];
                    
                
                    if (bit_cnt == 14) begin
                        bit_cnt <= 0;
                        state <= CRC_DELIM;
                    end else
                        bit_cnt <= bit_cnt + 1;
                end
            end

            CRC_DELIM: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    raw_bit <= 1'b1; // CRC delimiter is always recessive
                    bit_cnt <= 0;
                    state <= ACK_SLOT;
                end
            end

            
            ACK_SLOT: begin
                if(!stuffing_busy) begin
                    raw_bit <= (ack_received) ? 1 : 0; raw_bit_valid <= 1;
                    if (rx_sampled != 0)
                        ack_error <= 1;
                    state <= ACK_DELIM;
                end
            end
            
            ACK_DELIM: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    raw_bit <= 1'b1;  // Always recessive           
                    state <= EOF;
                    eof_cnt <= 0;
                end
            end
            
            EOF: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    raw_bit <= 1'b1;  // All EOF bits are recessive
                    
                    if (eof_cnt == 3'd6) begin
                        state <= IDLE;
                        eof_cnt <= 0;
                        tx_done <= 1;  // Optional signal to indicate TX completion
                    end else begin
                        eof_cnt <= eof_cnt + 1;
                        state <= EOF;
                    end
                end
            end
            
            INTERMISSION: begin
                if(!stuffing_busy) begin
                    raw_bit_valid <= 1;
                    raw_bit <= 1'b1;   
                    if (ifs_cnt == 2) begin
                        ifs_cnt <= 0;
                        if (retry_pending) begin
                            retry_pending <= 0;
                            state <= SOF;
                        end else begin
                            tx_done <= 1;
                            state <= IDLE;
                        end
                    end else begin
                        ifs_cnt <= ifs_cnt + 1;
                        state <= INTERMISSION;
                    end
                end
            end

            ERROR_FRAME: begin
                if(!stuffing_busy) begin
                    if (bit_cnt < 6)
                        raw_bit <= 0;
                    else if (bit_cnt < 14)
                        raw_bit <= 1;
                    else begin
                        bit_cnt <= 0;
                        state <= INTERMISSION;
                        error_frame_sent <= 1;
                    end
                    if (bit_cnt == 14)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1;
                end
            end

            default: begin
                raw_bit <= 1;
            end
        endcase
        
        if (state == IDLE || state == INTERMISSION) begin
            bit_error <= 0;
            form_error <= 0;
            ack_error <= 0;
            error_frame_sent <= 0;
        end

        // Complete transmission
        if (state == INTERMISSION && bit_start)
            tx_done <= 1;
    end
    end
end

//-----------------------------------------
// Output Assignment
//-----------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst)
        tx_bit <= 1;
    else if (bit_start && stuffed_bit_valid && tx_started)
        tx_bit <= stuffed_bit;
    else if(!tx_started)
        tx_bit <= 1;
    
end


always @(posedge clk)
    if (sample_point && state != ACK_SLOT && state != ACK_DELIM && state != EOF && state != INTERMISSION) begin
        // Detect bit error: transmitted dominant (0), but sampled recessive (1)
        if (tx_bit == 1'b0 && rx_sampled == 1'b1 || tx_bit == 1'b1 && rx_sampled == 1'b0) begin
            bit_error <= 1'b1;
        end else begin
            bit_error <= 1'b0;
        end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        prev_tx_bit <= 1;
    else if (bit_start)
        prev_tx_bit <= tx_bit;
end
endmodule
