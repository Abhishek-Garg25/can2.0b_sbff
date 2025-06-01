// =============================================================================
// CAN 2.0B Verilog IP Core
// -----------------------------------------------------------------------------
// Filename     : tb_can_top.v
// Author       : Abhishek Garg
// Created      : 25-05-2025
// Version      : v1.0
// Description  : Testbench for Complete CAN module.
//
// Contact       : abhishekgarg403@gmail.com
// =============================================================================


module tb_can_controller;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;  // 100 MHz clock

    // Inputs
    reg [7:0]  brp = 10;
    reg [3:0]  tseg1 = 6;
    reg [3:0]  tseg2 = 3;
    reg [3:0]  sjw = 1;

    reg tx_start = 0;
    reg [28:0] id = 29'h123;
    reg ide = 0;
    reg rtr = 0;
    reg [3:0] dlc = 8;
    reg [63:0] data = 64'hCAFEBABEDEADBEEF;
    reg ack_received = 1;  // Always acknowledge in loopback

    wire tx;
    wire tx_done;
    wire busy;
    wire rx_data_valid;
    wire [63:0] rx_data;
    wire [28:0] rx_id;
    wire [3:0] rx_dlc;
    wire rx_ide;
    wire rx_rtr;
    // Loopback connection
    wire rx = tx;  // ? Correct sampling behavior


    // DUT
    can_controller uut (
        .clk(clk),
        .rst(rst),
        .brp(brp),
        .tseg1(tseg1),
        .tseg2(tseg2),
        .sjw(sjw),
        .tx_start(tx_start),
        .id(id),
        .ide(ide),
        .rtr(rtr),
        .dlc(dlc),
        .data(data),
        .ack_received(ack_received),
        .rx(rx),
        .tx(tx),
        .tx_done(tx_done),
        .busy(busy),
        .rx_data_valid(rx_data_valid),
        .rx_data(rx_data),
        .rx_id(rx_id),
        .rx_dlc(rx_dlc),
        .rx_ide(rx_ide),
        .rx_rtr(rx_rtr)
    );

    // Stimulus
    initial begin
        $display("Starting loopback test...");
        #50 rst = 0;
        
        // Wait for sample_point to go high (start of a new bit time)
        #50 @(posedge clk);
        
        // Then trigger transmission
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        
        wait (tx_done);
        $display("TX Done");

        wait (rx_data_valid);
        $display("RX Done");

        $display("RX ID = %h", rx_id);
        $display("RX DATA = %h", rx_data);
        $display("RX DLC = %d", rx_dlc);
        $display("RX IDE = %b", rx_ide);
        $display("RX RTR = %b", rx_rtr);

        #100 $finish;
    end
endmodule
