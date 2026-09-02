/**
 *  Copyright (C) 2025, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: UART test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "uart.v"
// `include "uart_io.v"

/*============================================================================*/
module uart_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

localparam NR_BITS_1 = 8;

wire [NR_BITS_1-1:0] uart1_rx_d;
wire uart1_rx_dv;
wire parity1_ok;
reg  [NR_BITS_1-1:0] rx1_data = 0;
reg  [NR_BITS_1-1:0] uart1_tx_d = 0;
reg  uart1_tx_dv = 0;
wire uart1_tx_dr;
wire uart1_rx;
wire uart1_tx;
wire uart4_tx;
reg  uart_rx1_tx4 = 0;

assign uart1_rx = uart_rx1_tx4 ? uart4_tx : uart1_tx;

uart #(
    .CLK_FREQ( 250 ),
    .BAUD_RATE( 50 ),
    .NR_BITS( NR_BITS_1 ),
    .PARITY( "NONE" ),
    .STOP_BITS( 1 ))
uart1 (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart1_rx_d),
    .uart_rx_dv(uart1_rx_dv),
    .parity_ok(parity1_ok),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr),
    .uart_rx(uart1_rx),
    .uart_tx(uart1_tx)
    );

localparam NR_BITS_2 = 7;

wire [NR_BITS_2-1:0] uart2_rx_d;
wire uart2_rx_dv;
wire parity2_ok;
reg  [NR_BITS_2-1:0] rx2_data = 0;
reg  [NR_BITS_2-1:0] uart2_tx_d = 0;
reg  uart2_tx_dv = 0;
wire uart2_tx_dr;
wire uart2_rx;
wire uart2_tx;

assign uart2_rx = uart2_tx;

uart #(
    .CLK_FREQ( 250 ),
    .BAUD_RATE( 50 ),
    .NR_BITS( NR_BITS_2 ),
    .PARITY( "EVEN" ),
    .STOP_BITS( 2 ))
uart2 (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart2_rx_d),
    .uart_rx_dv(uart2_rx_dv),
    .parity_ok(parity2_ok),
    .uart_tx_d(uart2_tx_d),
    .uart_tx_dv(uart2_tx_dv),
    .uart_tx_dr(uart2_tx_dr),
    .uart_rx(uart2_rx),
    .uart_tx(uart2_tx)
    );

localparam NR_BITS_3 = 12;

wire [NR_BITS_3-1:0] uart3_rx_d;
wire uart3_rx_dv;
wire parity3_ok;
reg  [NR_BITS_3-1:0] rx3_data = 0;
reg  [NR_BITS_3-1:0] uart3_tx_d = 0;
reg  uart3_tx_dv = 0;
wire uart3_tx_dr;
wire uart3_rx;
wire uart3_tx;

assign uart3_rx = uart3_tx;

uart #(
    .CLK_FREQ( 250 ),
    .BAUD_RATE( 50 ),
    .NR_BITS( NR_BITS_3 ),
    .PARITY( "ODD" ),
    .STOP_BITS( 1 ))
uart3 (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart3_rx_d),
    .uart_rx_dv(uart3_rx_dv),
    .parity_ok(parity3_ok),
    .uart_tx_d(uart3_tx_d),
    .uart_tx_dv(uart3_tx_dv),
    .uart_tx_dr(uart3_tx_dr),
    .uart_rx(uart3_rx),
    .uart_tx(uart3_tx)
    );

wire [NR_BITS_1-1:0] uart4_rx_d;
wire uart4_rx_dv;
wire parity4_ok;
wire [NR_BITS_1-1:0] uart4_tx_d;
wire uart4_tx_dv;
wire uart4_tx_dr;
wire uart4_rx;

assign uart4_rx = uart1_tx; // Input UART1 TX!

uart #(
    .CLK_FREQ( 250 ),
    .BAUD_RATE( 50 ),
    .NR_BITS( NR_BITS_1 ),
    .PARITY( "NONE" ),
    .STOP_BITS( 1 ))
uart4 (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart4_rx_d),
    .uart_rx_dv(uart4_rx_dv),
    .parity_ok(parity4_ok),
    .uart_tx_d(uart4_tx_d),
    .uart_tx_dv(uart4_tx_dv),
    .uart_tx_dr(uart4_tx_dr),
    .uart_rx(uart4_rx),
    .uart_tx(uart4_tx)
    );

wire [NR_BITS_1-1:0] uart4_io_rx_d;
wire uart4_io_rx_dv;
reg  uart4_io_rx_dr = 1;
wire parity4_io_ok;
wire rx_fifo_nz;
reg  [NR_BITS_1-1:0] uart4_io_tx_d = 0;
reg  uart4_io_tx_dv = 0;
wire uart4_io_tx_dr;
wire x_modem;
wire [7:0] x_seq;

uart_io #(
    .PROMPT( "C10LP>" ),
    .NR_BITS( NR_BITS_1 ),
    .SKIP_SPACE( 0 ),
    .RX_FIFO( 8 ),
    .XMODEM( 1 ))
console (
    .clk(clk),
    .rst_n(rst_n),
    .uart_io_rx_d(uart4_io_rx_d),
    .uart_io_rx_dv(uart4_io_rx_dv),
    .uart_io_rx_dr(uart4_io_rx_dr),
    .parity_io_ok(parity4_io_ok),
    .rx_fifo_nz(rx_fifo_nz),
    .uart_io_tx_d(uart4_io_tx_d),
    .uart_io_tx_dv(uart4_io_tx_dv),
    .uart_io_tx_dr(uart4_io_tx_dr),
    .uart_rx_d(uart4_rx_d),
    .uart_rx_dv(uart4_rx_dv),
    .parity_ok(parity4_ok),
    .uart_tx_d(uart4_tx_d),
    .uart_tx_dv(uart4_tx_dv),
    .uart_tx_dr(uart4_tx_dr),
    .x_modem(x_modem),
    .x_seq(x_seq)
    );

always #5 clk = ~clk; // 100MHz clock

/*============================================================================*/
always @(posedge clk) begin : rx1_data_collect
/*============================================================================*/
    if ( uart1_rx_dv ) begin
        rx1_data <= uart1_rx_d;
        // $display( "RX1D = %02X, XMODEM = %d, XSEQ = %0d, XERROR = %d", uart1_rx_d, x_modem, x_seq, console.x_error );
        wait ( !uart1_rx_dv );
    end
end // rx1_data_collect

/*============================================================================*/
always @(posedge clk) begin : rx2_data_collect
/*============================================================================*/
    if ( uart2_rx_dv ) begin
        rx2_data <= uart2_rx_d;
        // $display( "RX2D = %02X", uart2_rx_d );
        wait ( !uart2_rx_dv );
    end
end // rx2_data_collect

/*============================================================================*/
always @(posedge clk) begin : rx3_data_collect
/*============================================================================*/
    if ( uart3_rx_dv ) begin
        rx3_data <= uart3_rx_d;
        // $display( "RX3D = %02X", uart3_rx_d );
        wait ( !uart3_rx_dv );
    end
end // rx3_data_collect

/*============================================================================*/
task uart_write( input integer uart,
                 input [NR_BITS_3-1:0] uart_d );
/*============================================================================*/
begin
    if ( 1 == uart ) begin
        wait ( uart1_tx_dr );
        wait ( clk ) @( negedge clk );
        uart1_tx_d = uart_d[NR_BITS_1-1:0];
        uart1_tx_dv = 1;
        wait ( !uart1_tx_dr );
        wait ( clk ) @( negedge clk );
        uart1_tx_dv = 0;
    end
    if ( 2 == uart ) begin
        wait ( uart2_tx_dr );
        wait ( clk ) @( negedge clk );
        uart2_tx_d = uart_d[NR_BITS_2-1:0];
        uart2_tx_dv = 1;
        wait ( !uart2_tx_dr );
        wait ( clk ) @( negedge clk );
        uart2_tx_dv = 0;
    end
    if ( 3 == uart ) begin
        wait ( uart3_tx_dr );
        wait ( clk ) @( negedge clk );
        uart3_tx_d = uart_d;
        uart3_tx_dv = 1;
        wait ( !uart3_tx_dr );
        wait ( clk ) @( negedge clk );
        uart3_tx_dv = 0;
    end
    if ( 4 == uart ) begin
        wait ( uart4_io_tx_dr );
        wait ( clk ) @( negedge clk );
        uart4_io_tx_d = uart_d[NR_BITS_1-1:0];
        uart4_io_tx_dv = 1;
        wait ( !uart4_io_tx_dr );
        wait ( clk ) @( negedge clk );
        uart4_io_tx_dv = 0;
    end
end
endtask // uart_write

localparam [7:0] SOH = 8'h01; // Start Of Header
localparam [7:0] EOT = 8'h04; // End Of Transmission
localparam [7:0] ACK = 8'h06; // ACKnowlegde
localparam [7:0] BS = 8'h08; // Back Space
localparam [7:0] CR = 8'h0D; // Carriage Return
localparam [7:0] LF = 8'h0A; // Line Feed
localparam [7:0] XON = 8'h11; // Transmit ON
localparam [7:0] XOFF = 8'h13; // Transmit OFF
localparam [7:0] NAK = 8'h15; // Negative AcKnowlegde

reg [7:0] i = 0;
reg [7:0] x_sum = 0;
/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    uart_rx1_tx4 = 0;
    uart4_io_rx_dr = 1;
    #100
    rst_n = 1;
    $display( "UART simulation started" );
    uart_write( 1, 8'h81 );
    uart_write( 1, 8'h5A );
    uart_write( 1, 8'hA5 );
    uart_write( 1, 8'h81 );
    uart_write( 1, 0 );
    /*----------------------*/
    uart_write( 2, 7'h41 );
    uart_write( 2, 7'h5A );
    uart_write( 2, 7'h25 );
    uart_write( 2, 7'h41 );
    uart_write( 2, 0 );
    /*----------------------*/
    uart_write( 3, 12'h801 );
    uart_write( 3, 12'hA5A );
    uart_write( 3, 12'h5A5 );
    uart_write( 3, 12'h801 );
    uart_write( 3, 0 );
    /*----------------------*/
    uart_rx1_tx4 = 1;
    uart4_io_rx_dr = 0;
    uart_write( 1, 8'h81 );
    uart_write( 1, 8'h5A );
    uart_write( 1, 8'hA5 );
    uart_write( 1, 8'h81 );
    uart_write( 1, 0 );
    uart_write( 1, LF );
    #2000
    uart_rx1_tx4 = 1; // Check XMODEM protocol; 0 = transmission, 1 = response
    uart4_io_rx_dr = 1;
    uart_write( 1, SOH ); // Start XMODEM
    uart_write( 1, 8'd1 );
    uart_write( 1, ~( 8'd1 ));
    x_sum = 0;
    for ( i = 0; i < 128; i = i + 1 ) begin
        uart_write( 1, i );
        x_sum = x_sum + i;
    end    
    uart_write( 1, x_sum );
    if ( uart_rx1_tx4 ) begin
        wait ( rx1_data == ACK );
    end else begin
        wait ( rx1_data == x_sum );
    end
    uart_write( 1, SOH ); // Start XMODEM
    uart_write( 1, 8'd2 );
    uart_write( 1, ~( 8'd2 ));
    x_sum = 0;
    for ( i = 0; i < 128; i = i + 1 ) begin
        uart_write( 1, i );
        x_sum = x_sum + i;
    end    
    uart_write( 1, ( x_sum + 1 )); // Summing error!
    uart_write( 1, EOT );
    if ( uart_rx1_tx4 ) begin
        wait ( rx1_data == NAK );
    end else begin
        wait ( rx1_data == EOT );
    end
    #1000
    uart_write( 4, 8'hFF );
    #4000
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "uart_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // uart_tb
