/**
 *  Copyright (C) 2026, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU Lesser General Public License as published by the
 *  Free Software Foundation, either version 3 of the License, or (at your
 *  option) any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program. If not, see <https://www.gnu.org/licenses/> for a
 *  copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: RISCV femtoRV32 test bench for Digilent Xilinx Spartan-3
 *               Starter Kit (XC3S200-4FT256).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "../lib/uart_io.v"
// `include "../femtoRV32.v"
// `include "uart.xise.v"
// `include "xc3s200_femtoRV32.v"

/*============================================================================*/
module xc3s_femtoRV32_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

localparam NR_BITS = 8;

wire uart1_rx;
wire uart1_tx;
wire [7:0] uart1_rx_d;
wire uart1_rx_dv;
wire parity1_ok;
reg  [7:0] rx1_data = 0;
reg  [7:0] uart1_tx_d = 0;
reg  uart1_tx_dv = 0;
wire uart1_tx_dr;

uart #(
    .CLK_FREQ(35000000),
`ifndef XC3S200_TB
    .BAUD_RATE(115200),
`else
    .BAUD_RATE(7000000), // One fifth of clock frequency for simulation
`endif
    .NR_BITS(NR_BITS),
    .PARITY("NONE"),
    .STOP_BITS(1))
uart1(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart1_rx_d),
    .uart_rx_dv(uart1_rx_dv),
    .parity_ok(parity1_ok),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr),
    .uart_rx(uart1_tx),
    .uart_tx(uart1_rx)
    );

wire uart2_rx;
wire uart2_tx;
wire [7:0] uart2_rx_d;
wire uart2_rx_dv;
wire parity2_ok;
reg  [7:0] rx2_data = 0;
reg  [7:0] uart2_tx_d = 0;
reg  uart2_tx_dv = 0;
wire uart2_tx_dr;

uart #(
    .CLK_FREQ(35000000),
`ifndef XC3S200_TB
    .BAUD_RATE(115200),
`else
    .BAUD_RATE(7000000), // One fifth of clock frequency for simulation
`endif
    .NR_BITS(NR_BITS),
    .PARITY("NONE"),
    .STOP_BITS(1))
uart2(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart2_rx_d),
    .uart_rx_dv(uart2_rx_dv),
    .parity_ok(parity2_ok),
    .uart_tx_d(uart2_tx_d),
    .uart_tx_dv(uart2_tx_dv),
    .uart_tx_dr(uart2_tx_dr),
    .uart_rx(uart2_tx),
    .uart_tx(uart2_rx)
    );

localparam SRAW = 18; // SRAM Address Width

reg  [2:0] btn = 0;
reg  [7:0] swt = 0;
wire [7:0] led;
wire [3:0] ssg_an_n;
wire [6:0] ssg_n;
wire ssg_dp_n;
wire sram_oe_n;
wire sram_we_n;
wire [SRAW-1:0] sram_a;
wire [15:0] sram_io1; // inout
wire sram_ce1_n;
wire sram_lb1_n;
wire sram_ub1_n;
wire [15:0] sram_io2; // inout
wire sram_ce2_n;
wire sram_lb2_n;
wire sram_ub2_n;

/*============================================================================*/
xc3s200_femtoRV32 xc3s200_femtoRV32_dut(
/*============================================================================*/
    .CLK_50M(clk),
    .ARST(~rst_n),
    .UART_RX(uart1_rx), // TTL/RS232
    .UART_TX(uart1_tx), // TTL/RS232
    .UART_RX_A(uart2_rx), // TTL/RS232
    .UART_TX_A(uart2_tx), // TTL/RS232
    .BTN(btn),
    .SWT(swt),
    .LED(led),
    .SSG_AN_n(ssg_an_n), // Active low
    .SSG_n(ssg_n), // Active low
    .SSG_DP_n(ssg_dp_n), // Active low
    .SRAM_OE_n(sram_oe_n), // Output enable, 1 = output disabled (Z)
    .SRAM_WE_n(sram_we_n), // Write enable, 1 = read
    .SRAM_A(sram_a), // Address outputs
    .SRAM_IO1(sram_io1), // Data inputs/outputs
    .SRAM_CE1_n(sram_ce1_n), // Chip enable
    .SRAM_LB1_n(sram_lb1_n), // Low byte control
    .SRAM_UB1_n(sram_ub1_n), // High byte control
    .SRAM_IO2(sram_io2), // Data inputs/outputs
    .SRAM_CE2_n(sram_ce2_n), // Chip enable
    .SRAM_LB2_n(sram_lb2_n), // Low byte control
    .SRAM_UB2_n(sram_ub2_n) // High byte control
    );

/*============================================================================*/
function integer clog2( input [31:0] value );
/*============================================================================*/
    reg [31:0] depth;
begin
    clog2 = 1; // Minimum bit width
    if ( value > 1 ) begin
        depth = value - 1;
        clog2 = 0;
        while ( depth > 0 ) begin
            depth = depth >> 1;
            clog2 = clog2 + 1;
        end
    end
end
endfunction // clog2

localparam SD = 2 ** SRAW; // Sram Depth
reg [31:0] sram[0:SD-1];

assign sram_io1 = ( ~sram_oe_n & sram_we_n ) ? sram[sram_a][15:0] : 16'hZZZZ;
assign sram_io2 = ( ~sram_oe_n & sram_we_n ) ? sram[sram_a][31:16] : 16'hZZZZ;

/*============================================================================*/
always @(posedge clk) begin : sram_process
/*============================================================================*/
    if ( !sram_we_n ) begin
        if ( !sram_lb1_n ) begin
            sram[sram_a][7:0] <= sram_io1[7:0];
        end
        if ( !sram_ub1_n ) begin
            sram[sram_a][15:8] <= sram_io1[15:8];
        end
        if ( !sram_lb2_n ) begin
            sram[sram_a][23:16] <= sram_io2[7:0];
        end
        if ( !sram_ub2_n ) begin
            sram[sram_a][31:24] <= sram_io2[15:8];
        end
    end
end // sram_process

always #10 clk = ~clk; // 50MHz clock

localparam [7:0] SOH = 8'h01; // Start Of Header
localparam [7:0] EOT = 8'h04; // End Of Transmission
localparam [7:0] ACK = 8'h06; // ACKnowlegde
localparam [7:0] BS = 8'h08; // Back Space
localparam [7:0] CR = 8'h0D; // Carriage Return
localparam [7:0] LF = 8'h0A; // Line Feed
localparam [7:0] XON = 8'h11; // Transmit ON
localparam [7:0] XOFF = 8'h13; // Transmit OFF
localparam [7:0] NAK = 8'h15; // Negative AcKnowlegde
localparam [7:0] SPACE = 8'h20;
localparam MSL = 50; // Maximum string length
localparam MSLW = clog2( MSL ); // MSL Width

reg [MSL*8:1] tempStr = 0;
reg [7:0] uart1Str[0:MSL];
reg [MSL:0] strCount = 0;

int m;
/*============================================================================*/
always @(posedge clk) begin : rx1_data_collect
/*============================================================================*/
    if ( uart1_rx_dv ) begin
        rx1_data <= uart1_rx_d;
        if ( !xc3s200_femtoRV32_dut.console.x_modem ) begin
            if (( uart1_rx_d == LF ) || ( strCount == MSL )) begin
                if ( strCount > 2 ) begin // Skip empty string CRLF!
                    for ( m = strCount; m >= 0; m = m - 1 ) begin
                        tempStr = tempStr >> 8;
                        tempStr[MSL*8:(MSL*8)-7] = uart1Str[m];
                    end
                    if ( m ) $display( "%s", tempStr );
                    for ( m = 0; m < MSL; m = m + 1 ) uart1Str[m] = 0;
                end
                tempStr = 0;
                strCount = 0;
            end else if ( uart1_rx_d >= SPACE ) begin
                uart1Str[strCount] = uart1_rx_d;
                strCount = strCount + 1;
            end
        end
        // $display( "RX1D = %02X", uart1_rx_d );
        // $display( "RX1D = %02X %c, XMODEM = %d, XSEQ = %0d, XERROR = %d", uart1_rx_d, uart1_rx_d, x_modem, x_seq, console.x_error );
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
task uart_write( input integer uart,
                 input [7:0] uart_d );
/*============================================================================*/
begin
    if ( 1 == uart ) begin
        wait ( uart1_tx_dr );
        wait ( clk ) @( negedge clk );
        uart1_tx_d = uart_d[7:0];
        uart1_tx_dv = 1;
        wait ( !uart1_tx_dr );
        wait ( clk ) @( negedge clk );
        uart1_tx_dv = 0;
    end
    if ( 2 == uart ) begin
        wait ( uart2_tx_dr );
        wait ( clk ) @( negedge clk );
        uart2_tx_d = uart_d[7:0];
        uart2_tx_dv = 1;
        wait ( !uart2_tx_dr );
        wait ( clk ) @( negedge clk );
        uart2_tx_dv = 0;
    end
end
endtask // uart_write

/*============================================================================*/
function [31:0] swap32( input [31:0] value );
/*============================================================================*/
begin
    swap32[7:0] = value[31:24];
    swap32[15:8] = value[23:16];
    swap32[23:16] = value[15:8];
    swap32[31:24] = value[7:0];
end
endfunction // swap32

integer file;
integer r;
integer i, j, k;
reg [7:0] x_frame;
reg [7:0] x_sum;
reg [31:0] temp;
/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    for ( i = 0; i < SD; i = i + 1 ) sram[i] = 0;
    #100
    rst_n = 1;
    $display( "XC3S200_FEMTORV32 simulation started" );
    #10000
    wait ( rx1_data == LF ); // FemtoRV32 xc3s200_boot.c boot message should be displayed
    wait ( xc3s200_femtoRV32_dut.console.uart_io_tx_dr );
    file = $fopen( "xc3s200_sys.bin", "rb" ); // Open binary file!
    if ( file ) begin
        x_frame = 1;
        x_sum = 0;
        r = 1;
        for ( i = 0; r; i = i + 1 ) begin
            for ( j = 0; ( r && ( j < 128 )); j = j + r ) begin
                if ( j == 0 ) begin
                    uart_write( 1, SOH ); // Start XMODEM frame
                    uart_write( 1, x_frame );
                    uart_write( 1, ~x_frame );
                end
                temp = 0;
                r = $fread( temp, file );
                temp = swap32( temp ); // Little Endian!
                // $display( "temp = %08X, r = %0d", temp, r );
                for ( k = 0; k < r; k = k + 1 ) begin
                    uart_write( 1, temp[7:0] );
                    x_sum = x_sum + temp[7:0];
                    temp = temp >> 8;
                end
            end
            while ( j < 128 ) begin // XMODEM frame padding!
                uart_write( 1, 8'd0 );
                x_sum = x_sum + 8'd0;
                j = j + 1;
            end
            uart_write( 1, x_sum );
            x_sum = 0;
            x_frame = x_frame + 1;
        end
        uart_write( 1, EOT );
        $fclose( file );
    end else begin
        // Some simulators require files accessed to be placed in their
        // working (build) directory!
        $display( "Could not open xc3s200_sys.bin file!" );
    end
    #10000
    wait ( rx1_data == LF ); // FemtoRV32 xc3s200_sys.c system message should be displayed
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "xc3s_femtoRV32_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule  // xc3s_femtoRV32_tb
