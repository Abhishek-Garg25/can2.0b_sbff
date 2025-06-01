// ===================================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------------
// Filename     : crc15.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : ISO 11898-1 CRC-15: x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1
//
// Contact       : abhishekgarg403@gmail.com
// ===================================================================================

`timescale 1ns / 1ps

module crc15 (
    input        clk,
    input        rst,
    input        data_in,
    input        data_valid,
    output reg [14:0] crc_out
);
    reg [14:0] crc;
    wire feedback;

    assign feedback = data_in ^ crc[14];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            crc <= 15'h0000;
        end else if (data_valid) begin
            crc[14] <= crc[13] ^ feedback;
            crc[13] <= crc[12];
            crc[12] <= crc[11];
            crc[11] <= crc[10];
            crc[10] <= crc[9] ^ feedback;
            crc[9]  <= crc[8];
            crc[8]  <= crc[7] ^ feedback;
            crc[7]  <= crc[6] ^ feedback;
            crc[6]  <= crc[5];
            crc[5]  <= crc[4];
            crc[4]  <= crc[3] ^ feedback;
            crc[3]  <= crc[2] ^ feedback;
            crc[2]  <= crc[1];
            crc[1]  <= crc[0];
            crc[0]  <= feedback;
        end
    end

    always @(*) begin
        crc_out = crc;
    end
endmodule
