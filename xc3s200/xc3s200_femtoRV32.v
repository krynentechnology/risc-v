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
 *  Description: RISCV femtoRV32 HW setup for Digilent Xilinx Spartan-3
 *               Starter Kit (XC3S200-4FT256).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "../lib/uart_io.v"
// `include "../femtoRV32.v"
// `include "uart.xise.v"

/*============================================================================*/
module xc3s200_femtoRV32(
/*============================================================================*/
    input  wire CLK_50M, // 50Mhz clock
    input  wire ARST, // BTN3
    // UART full duplex lines
    input wire UART_RX, // TTL/RS232
    output wire UART_TX, // TTL/RS232
    input wire UART_RX_A, // TTL/RS232
    output wire UART_TX_A, // TTL/RS232
    // Buttons
    input wire [2:0] BTN,
    // Sliding switches
    input wire [7:0] SWT,
    // LEDs, seven segment display
    output wire [7:0] LED,
    output wire [3:0] SSG_AN_n, // Active low
    output wire [6:0] SSG_n, // Active low
    output wire SSG_DP_n, // Active low
    // SRAM
    output wire SRAM_OE_n, // Output inable, 1 = output disabled (Z)
    output wire SRAM_WE_n, // Write inable, 1 = read
    output wire [17:0] SRAM_A, // Address outputs
    inout  wire [15:0] SRAM_IO1, // Data inputs/outputs
    output wire SRAM_CE1_n, // Chip enable
    output wire SRAM_LB1_n, // Low byte control
    output wire SRAM_UB1_n, // High byte control
    inout  wire [15:0] SRAM_IO2, // Data inputs/outputs
    output wire SRAM_CE2_n, // Chip enable
    output wire SRAM_LB2_n, // Low byte control
    output wire SRAM_UB2_n // High byte control
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

localparam AW = 21; // 1Mb memory and 1Mb I/O space.
localparam RSTW = 4; // Reset delay shift width
localparam PC_BITS = 12;
localparam NR_BITS = 8;
localparam RX_FIFO = 8;

wire clk;
wire rst_n;
reg [RSTW-1:0] rst_delay = 0;

wire [7:0] uart1_rx_d;
wire uart1_rx_dv;
wire [7:0] uart1_tx_d;
wire uart1_tx_dv;
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
    .parity_ok(),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr),
    .uart_rx(UART_RX),
    .uart_tx(UART_TX)
    );

wire [7:0] uart_io_rx_d;
wire uart_io_rx_dv;
wire uart_io_rx_dr;
wire parity_io_ok;
wire rx_fifo_nz;
reg  [7:0] uart_io_tx_d = 0;
reg  uart_io_tx_dv = 0;
wire uart_io_tx_dr;
wire x_modem;
wire [7:0] x_seq;

uart_io #(
    .PROMPT("XC3S>"),
    .NR_BITS(NR_BITS),
    .SKIP_SPACE(0),
    .RX_FIFO(RX_FIFO),
    .XMODEM(1))
console (
    .clk(clk),
    .rst_n(rst_n),
    .uart_io_rx_d(uart_io_rx_d),
    .uart_io_rx_dv(uart_io_rx_dv),
    .uart_io_rx_dr(uart_io_rx_dr),
    .parity_io_ok(parity_io_ok),
    .rx_fifo_nz(rx_fifo_nz),
    .uart_io_tx_d(uart_io_tx_d),
    .uart_io_tx_dv(uart_io_tx_dv),
    .uart_io_tx_dr(uart_io_tx_dr),
    .uart_rx_d(uart1_rx_d),
    .uart_rx_dv(uart1_rx_dv),
    .parity_ok(1'b1),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr),
    .x_modem(x_modem),
    .x_seq(x_seq)
    );

assign UART_TX_A = UART_RX_A;

wire [AW-1:0] mem_io_a;
wire [3:0] mem_io_wmask;
wire [31:0] mem_io_d_wr;
wire mem_io_rd;
reg  [31:0] mem_io_d_rd = 0;
reg  [31:0] mem_boot_d_rd = 0;
reg  boot_mem_en_ = 0;
wire we = |mem_io_wmask;

FemtoRV32 #(
   .PC_RESET(32'h00100000),
   .SP_RESET(32'h00100000), // Top of stack (SRAM)
   .ADDR_WIDTH(AW),
   .RVM(1),
   .DELAY_MULTIPLY(0))
riscv (
    .clk(clk),
    .rst_n(rst_n),
    .mem_addr(mem_io_a),
    .mem_wdata(mem_io_d_wr),
    .mem_wmask(mem_io_wmask),
    .mem_rdata(boot_mem_en_ ? mem_boot_d_rd : mem_io_d_rd),
    .mem_rstrb(mem_io_rd),
    .mem_rbusy(1'b0),
    .mem_wbusy(1'b0)
    );

// SRAM interface (2 x IS61LV25616AL)
wire [31:0] mem_d_rd;
wire we_n = ~we | mem_io_a[AW-1];
assign SRAM_OE_n = we | mem_io_a[AW-1]; // Memory mapped IO!
assign SRAM_WE_n = we_n;
assign SRAM_A = mem_io_a[AW-2:2];
assign mem_d_rd[15:0] = SRAM_IO1;
assign SRAM_IO1 = we_n ? 16'hZZZZ : mem_io_d_wr[15:0];
assign SRAM_CE1_n = ~rst_n;
assign SRAM_LB1_n = ~mem_io_wmask[0];
assign SRAM_UB1_n = ~mem_io_wmask[1];
assign mem_d_rd[31:16] = SRAM_IO2;
assign SRAM_IO2 = we_n ? 16'hZZZZ : mem_io_d_wr[31:16];
assign SRAM_CE2_n = ~rst_n;
assign SRAM_LB2_n = ~mem_io_wmask[2];
assign SRAM_UB2_n = ~mem_io_wmask[3];

localparam BMS = 512; // Block RAM
localparam BMSW = clog2( BMS );
reg  [31:0] boot_mem[0:BMS-1];
wire boot_mem_en = ( mem_io_a[AW-1] && ( mem_io_a[AW-2:BMSW+2] == 0 ));

`ifndef XC3S200_TB
// Generated by Xilinx Architecture Wizard, written for synthesis tool: XST
// Period Jitter (unit interval) for block DCM_INST = 0.04 UI
// Period Jitter (Peak-to-Peak) for block DCM_INST = 0.92 ns
wire CLKIN_IBUFG;
wire CLK0_BUF;
wire CLKFB_IN;
wire CLKFX_OBUF;
wire CLKFX_OUT;
wire LOCKED_OUT;

IBUFG CLKIN_IBUFG_INST(
    .I(CLK_50M),
    .O(CLKIN_IBUFG));
BUFG CLK0_BUFG_INST(
    .I(CLK0_BUF),
    .O(CLKFB_IN));
BUFG CLKFX_BUFG_INST(
    .I(CLKFX_OBUF),
    .O(CLKFX_OUT));

DCM #(
    .CLK_FEEDBACK("1X"),
    .CLKDV_DIVIDE(2.0),
    .CLKFX_DIVIDE(10),
    .CLKFX_MULTIPLY(7), // 35MHz!
    .CLKIN_DIVIDE_BY_2("FALSE"),
    .CLKIN_PERIOD(20.000),
    .CLKOUT_PHASE_SHIFT("NONE"),
    .DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
    .DFS_FREQUENCY_MODE("LOW"),
    .DLL_FREQUENCY_MODE("LOW"),
    .DUTY_CYCLE_CORRECTION("TRUE"),
    .FACTORY_JF(16'h8080),
    .PHASE_SHIFT(0),
    .STARTUP_WAIT("FALSE"))
DCM_INST(
    .CLKFB(CLKFB_IN),
    .CLKIN(CLKIN_IBUFG),
    .DSSEN(1'b0),
    .PSCLK(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .RST(ARST),
    .CLKDV(),
    .CLKFX(CLKFX_OBUF),
    .CLKFX180(),
    .CLK0(CLK0_BUF),
    .CLK2X(),
    .CLK2X180(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .LOCKED(LOCKED_OUT),
    .PSDONE(),
    .STATUS());

integer i;
/*============================================================================*/
initial begin : init_boot_memory
/*============================================================================*/
    for ( i = 0; i < BMS; i = i + 1 ) boot_mem[i] = 0;
    $readmemh( "../xc3s200_boot.mem", boot_mem );
end // init_boot_memory

assign clk = CLKFX_OUT;
`else
integer file;
integer r;
integer i;
reg [31:0] temp;
/*============================================================================*/
initial begin : init_boot_memory
/*============================================================================*/
    for ( i = 0; i < BMS; i = i + 1 ) boot_mem[i] = 0;
    file = $fopen( "xc3s200_boot.mem", "r" ); // Open text file!
    if ( file ) begin
        $fclose( file );
        $readmemh( "xc3s200_boot.mem", boot_mem );
    end else begin
        file = $fopen( "xc3s200_boot.bin", "rb" ); // Open binary file!
        if ( file ) begin
            r = 1;
            for ( i = 0; ( r && ( i < BMS )); i = i + 1 ) begin
                r = $fread( temp, file );
                if ( r ) boot_mem[i] = swap32( temp ); // Little Endian!
            end
            $fclose( file );
        end else begin
            // Some simulators require files accessed to be placed in their
            // working (build) directory!
            $display( "Could not open xc3s200_boot.mem or xc3s200_boot.bin file!" );
        end
    end
end // init_boot_memory

assign clk = CLK_50M;
`endif
assign rst_n = &rst_delay;

/*============================================================================*/
always @(posedge clk) begin : synchronized_reset
/*============================================================================*/
    rst_delay <= {rst_delay[RSTW-2:0], 1'b1};
`ifndef XC3S200_TB
    if ( ~LOCKED_OUT ) rst_delay <= 0;
`else
    if ( ARST ) rst_delay <= 0;
`endif
end // synchronized_reset

localparam CCW = 13;

reg [CCW-1:0] clk_count = 0;
/*============================================================================*/
always @(posedge clk) begin : clk_counter
/*============================================================================*/
    clk_count <= clk_count + 1;
end // clk_counter

/*============================================================================*/
always @(posedge clk) begin : mem_boot_access // Single port block RAM
/*============================================================================*/
    boot_mem_en_ <= boot_mem_en;

    if ( boot_mem_en ) begin
        if ( &mem_io_wmask ) begin // Only 32-bit writes!
            boot_mem[mem_io_a[10:2]] <= mem_io_d_wr;
        end
        mem_boot_d_rd <= boot_mem[mem_io_a[10:2]];
    end
end // mem_boot_access

reg [7:0] ssg_disp[0:3]; // ssg_disp[x][7] = dp
/*============================================================================*/
initial begin : init_ssg_display
/*============================================================================*/
    ssg_disp[0] = 8'hFF; // All off
    ssg_disp[1] = 8'hFF;
    ssg_disp[2] = 8'hFF;
    ssg_disp[3] = 8'hFF;
end // init_ssg_display

// Seven segment anode driver
wire [1:0] ssg_an_sel = clk_count[CCW-1:CCW-2];
assign SSG_AN_n[0] = ~( ssg_an_sel == 2'd0 );
assign SSG_AN_n[1] = ~( ssg_an_sel == 2'd1 );
assign SSG_AN_n[2] = ~( ssg_an_sel == 2'd2 );
assign SSG_AN_n[3] = ~( ssg_an_sel == 2'd3 );
// Seven segment decimal point decoder
assign SSG_DP_n = ssg_disp[ssg_an_sel][7];
// Seven segment decoder
assign SSG_n = ssg_disp[ssg_an_sel][6:0];
wire io_ssg_sel = ( ~boot_mem_en & mem_io_a[AW-1] & mem_io_a[AW-3] );

reg [7:0] led_disp = 0;
assign LED[3:0] = led_disp[3:0];
assign LED[4] = BTN[0] | led_disp[4];
assign LED[5] = BTN[1] | led_disp[5];
assign LED[6] = BTN[2] | led_disp[6];
assign LED[7] = ARST | led_disp[7];
wire io_led_sel = ( ~boot_mem_en & mem_io_a[AW-1] & mem_io_a[AW-4] );

wire io_uart_sel = ( ~boot_mem_en & mem_io_a[AW-1] & mem_io_a[AW-2] );
assign uart_io_rx_dr = io_uart_sel & mem_io_rd & uart_io_rx_dv;
// mem_io_d_rd_uart           [31:24],   [23:17],    [16],   [15:11],          [10],          [9],           [8],        [7:0]
wire [31:0] mem_io_d_rd_uart = {x_seq, {7{1'b0}}, x_modem, {5{1'b0}}, uart_io_tx_dr, parity_io_ok, uart_io_rx_dv, uart_io_rx_d};

/*============================================================================*/
always @(posedge clk) begin : mem_io_access
/*============================================================================*/
    uart_io_tx_dv <= 0;

    if ( mem_io_a[AW-1] ) begin
        mem_io_d_rd <= {{21{1'b0}}, BTN, SWT};

        if ( io_uart_sel ) begin
            mem_io_d_rd <= {{24{1'b0}}, mem_io_d_rd_uart};

            if ( we & mem_io_wmask[0] ) begin
                if ( uart_io_tx_dr && !uart_io_tx_dv ) begin
                    uart_io_tx_d <= mem_io_d_wr[7:0];
                    uart_io_tx_dv <= 1;
                end
            end
        end

        if ( we & io_ssg_sel ) begin
            if ( mem_io_wmask[0] ) ssg_disp[3] <= mem_io_d_wr[7:0];
            if ( mem_io_wmask[1] ) ssg_disp[2] <= mem_io_d_wr[15:8];
            if ( mem_io_wmask[2] ) ssg_disp[1] <= mem_io_d_wr[23:16];
            if ( mem_io_wmask[3] ) ssg_disp[0] <= mem_io_d_wr[31:24];
        end

        if ( we & io_led_sel ) begin
            if ( mem_io_wmask[0] ) led_disp <= mem_io_d_wr[7:0];
        end
    end else begin
        mem_io_d_rd <= mem_d_rd;
    end

    if ( !rst_n ) begin
        mem_io_d_rd <= 0;
    end
end // mem_io_access

endmodule  // xc3s200_femtoRV32
