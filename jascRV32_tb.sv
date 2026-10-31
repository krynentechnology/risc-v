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
 *  Description: RISC-V jascRV32 test bench.
 */

// Dependencies:
// `include "jascRV32.v"

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module jascRV32_tb();
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

/*============================================================================*/
task gcc( input [3:0] cycles ); // generate clock cycle
/*============================================================================*/
    reg [3:0] i;
begin
    for ( i = 0; i < cycles; i = i + 1 ) begin
        #5;
        clk = 1;
        #5;
        clk = 0;
    end
end
endtask // gcc

localparam AW = 21;

reg  rvim = 0;
wire [AW-1:0] addr_I;
wire [AW-1:0] addr_IM;
wire [AW-1:0] addr = rvim ? addr_IM : addr_I;
reg  [31:0] rd_data = 0;
wire rd_I;
wire rd_IM;
wire rd = rvim ? rd_IM : rd_I;
wire [31:0] wr_data_I;
wire [31:0] wr_data_IM;
wire [31:0] wr_data = rvim ? wr_data_IM : wr_data_I;
wire [3:0] wr_mask_I;
wire [3:0] wr_mask_IM;
wire [3:0] wr_mask = rvim ? wr_mask_IM : wr_mask_I;
wire [31:0] sccc_I;
wire [31:0] sccc_IM;
wire [31:0] sccc = rvim ? sccc_IM : sccc_I; // System Clock Cycle Counter
reg  hold = 0;
reg  [3:0] r0r31_sel = 0; // R0R31 set select

jascRV32 #(
    .PC_RESET(0),
    .AW(AW), // addr[AW-1] = I/O
    .RVM(0),
    .DELAY_MULTIPLY(0))
riscv_I (
    .clk(rvim ? 1'b0 : clk),
    .rst_n(rst_n),
    .addr(addr_I),
    .rd_data(rd_data),
    .rd(rd_I),
    .wr_data(wr_data_I),
    .wr_mask(wr_mask_I),
    .sccc(sccc_I),
    .hold(hold),
    .r0r31_sel(r0r31_sel)
    );

jascRV32 #(
    .PC_RESET(0),
    .AW(AW), // addr[AW-1] = I/O
    .RVM(1),
    .DELAY_MULTIPLY(0))
riscv_IM (
    .clk(rvim ? clk : 1'b0),
    .rst_n(rst_n),
    .addr(addr_IM),
    .rd_data(rd_data),
    .rd(rd_IM),
    .wr_data(wr_data_IM),
    .wr_mask(wr_mask_IM),
    .sccc(sccc_IM),
    .hold(hold),
    .r0r31_sel(r0r31_sel)
    );

localparam [5:0] R_TYPE = 1 << 0;
localparam [5:0] I_TYPE = 1 << 1;
localparam [5:0] S_TYPE = 1 << 2;
localparam [5:0] B_TYPE = 1 << 3;
localparam [5:0] U_TYPE = 1 << 4;
localparam [5:0] J_TYPE = 1 << 5;

/*============================================================================*/
function [31:0] instruction(
    input [5:0] format, // R, I, S, B, U or J type
    input [4:0] opcode,
    input [4:0] rdId,
    input [4:0] rs1Id,
    input [4:0] rs2Id,
    input [2:0] funct3,
    input [6:0] funct7,
    input [31:0] imm );
/*============================================================================*/
begin
    if (( format == 0 ) || (( format & ~( format - 1 )) != format )) $display( "Invalid instruction format!" );
    instruction[6:0] = {opcode, 2'b11};
    if ( format & ( R_TYPE | I_TYPE | U_TYPE | J_TYPE )) instruction[11:7] = rdId;
    if ( format & ( R_TYPE | I_TYPE | S_TYPE | B_TYPE )) begin
        instruction[14:12] = funct3;
        instruction[19:15] = rs1Id;
        if ( !( format & I_TYPE )) instruction[24:20] = rs2Id;
    end
    if ( format & R_TYPE ) instruction[31:25] = funct7;
    if ( format & I_TYPE ) instruction[31:20] = imm[11:0];
    if ( format & S_TYPE ) begin
        instruction[11:7] = imm[4:0];
        instruction[31:25] = imm[11:5];
    end
    if ( format & B_TYPE ) begin
        instruction[7] = imm[11];
        instruction[11:8] = imm[4:1];
        instruction[30:25] = imm[10:5];
        instruction[31] = imm[12];
    end
    if ( format & U_TYPE ) instruction[31:12] = imm[31:12];
    if ( format & J_TYPE ) begin
        instruction[19:12] = imm[19:12];
        instruction[20] = imm[11];
        instruction[30:21] = imm[10:1];
        instruction[31] = imm[20];
    end
end
endfunction

reg passed = 0;
int nbPassed = 0;
int nbFailed = 0;

/*============================================================================*/
task result( input string opcode );
/*============================================================================*/
begin
    $display( "-%c- %s", ( passed ? "V" : "X" ), opcode );
    if ( passed ) nbPassed = nbPassed + 1; else nbFailed = nbFailed + 1;
end
endtask

localparam [4:0] isLoad   = 5'b00000;
localparam [4:0] isALUimm = 5'b00100;
localparam [4:0] isAUIPC  = 5'b00101;
localparam [4:0] isStore  = 5'b01000;
localparam [4:0] isALUreg = 5'b01100;
localparam [4:0] isLUI    = 5'b01101;
localparam [4:0] isBranch = 5'b11000;
localparam [4:0] isJALR   = 5'b11001;
localparam [4:0] isJAL    = 5'b11011;
localparam [4:0] isSYSTEM = 5'b11100;

reg [AW-1:0] PC = 0;

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    rvim = 0;
    #10
    gcc( 2 );
    rst_n = 1;
    $display( "JASCRV32 simulation started" );
    $display( "    ---------------------" );
    $display( "    RISC-V I instructions" );
    $display( "    ---------------------" );
    passed = ( riscv_I.dp_bram1.bram[1] == 0 ) && ( riscv_I.dp_bram2.bram[1] == 0 );
    gcc( 1 ); // First clock cycle after (synchronous) reset does not process opcode!
    rd_data = instruction( I_TYPE, isALUimm, 2, 1, 5'dX, 0, 7'dX, 2047 );
    gcc( 1 ); // One clock cycle after rd_data is set, opcode is valid
    rd_data = instruction( I_TYPE, isALUimm, 2, 2, 5'dX, 0, 7'dX, -2048 ); // "addi rd,rs1,imm12"
    gcc( 1 ); // Two clock cycles after rd_data is set, a single register (x1-x31) has been updated (except for isBranch, isLoad and isStore)
    passed = passed && ( riscv_I.dp_bram1.bram[2] == 2047 ) && ( riscv_I.dp_bram2.bram[2] == 2047 );
    rd_data = instruction( I_TYPE, isALUimm, 1, 2, 5'dX, 0, 7'dX, 0 ); // "mv rd,rs1"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[2] == -1 ) && ( riscv_I.dp_bram2.bram[2] == -1 );
    rd_data = instruction( I_TYPE, isALUimm, 0, 0, 5'dX, 0, 7'dX, 0 ); // "nop"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[1] == -1 ) && ( riscv_I.dp_bram2.bram[1] == -1 );
    passed = passed && ( riscv_I.rdUpdEn == 0 );
    result( "addi rd,rs1,imm12" );
    $display( "    mv rd,rs1 (pseudo)" ); // Pseudo addi instruction
    $display( "    nop (pseudo)" ); // Pseudo addi instruction
    rd_data = instruction( I_TYPE, isALUimm, 3, 1, 5'dX, 2, 7'dX, -1 ); // "slti rd,rs1,imm12", imm = x1
    gcc( 1 );
    rd_data = instruction( I_TYPE, isALUimm, 3, 1, 5'dX, 2, 7'dX, 1 ); // "slti rd,rs1,imm12", imm > x1
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[3] == 0 ) && ( riscv_I.dp_bram2.bram[3] == 0 );
    rd_data = instruction( I_TYPE, isALUimm, 3, 1, 5'dX, 2, 7'dX, -3 ); // "slti rd,rs1,imm12", imm < x1
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[3] == 1 ) && ( riscv_I.dp_bram2.bram[3] == 1 );
    rd_data = instruction( I_TYPE, isALUimm, 2, 4, 5'dX, 0, 7'dX, 2047 ); // x4 = 0!
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[3] == 0 ) && ( riscv_I.dp_bram2.bram[3] == 0 );
    result( "slti rd,rs1,imm12" );
    rd_data = instruction( I_TYPE, isALUimm, 3, 2, 5'dX, 3, 7'dX, 2047 ); // "sltiu rd,rs1,imm12", unsigned imm = x2
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[2] == 2047 ) && ( riscv_I.dp_bram2.bram[2] == 2047 );
    rd_data = instruction( I_TYPE, isALUimm, 3, 2, 5'dX, 3, 7'dX, 2048 ); // "sltiu rd,rs1,imm12", unsigned imm > x2
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[3] == 0 ) && ( riscv_I.dp_bram2.bram[3] == 0 );
    rd_data = instruction( I_TYPE, isALUimm, 3, 2, 5'dX, 3, 7'dX, 2046 ); // "sltiu rd,rs1,imm12", unsigned imm < x2
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[3] == 1 ) && ( riscv_I.dp_bram2.bram[3] == 1 );
    rd_data = instruction( I_TYPE, isALUimm, 3, 4, 5'dX, 3, 7'dX, 1 ); // "seqz rd,rs1", x4 == 0?
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[3] == 0 ) && ( riscv_I.dp_bram2.bram[3] == 0 );
    rd_data = instruction( I_TYPE, isALUimm, 1, 3, 5'dX, 7, 7'dX, 1 ); // "andi rd,rs1,imm12"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[3] == 1 ) && ( riscv_I.dp_bram2.bram[3] == 1 );
    result( "sltiu rd,rs1,imm12" );
    $display( "    seqz rd,rs1 (pseudo)" ); // Pseudo sitiu instruction
    rd_data = instruction( I_TYPE, isALUimm, 1, 2, 5'dX, 7, 7'dX, 2046 ); // "andi rd,rs1,imm12"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[1] == 1 ) && ( riscv_I.dp_bram2.bram[1] == 1 );
    rd_data = instruction( I_TYPE, isALUimm, 1, 3, 5'dX, 6, 7'dX, 2 ); // "ori rd,rs1,imm12"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[1] == 2046 ) && ( riscv_I.dp_bram2.bram[1] == 2046 );
    result( "andi rd,rs1,imm12" );
    rd_data = instruction( I_TYPE, isALUimm, 1, 2, 5'dX, 6, 7'dX, 12'h800 ); // "ori rd,rs1,imm12", sign extended!
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[1] == 3 ) && ( riscv_I.dp_bram2.bram[1] == 3 );
    rd_data = instruction( I_TYPE, isALUimm, 1, 3, 5'dX, 4, 7'dX, 3 ); // "xori rd,rs1,imm12"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[1] == -1 ) && ( riscv_I.dp_bram2.bram[1] == -1 );
    result( "ori rd,rs1,imm12" );
    rd_data = instruction( I_TYPE, isALUimm, 1, 2, 5'dX, 4, 7'dX, 12'hFFF ); // "xori rd,rs1,imm12" ,sign extended, same as -1 ("not rd,rs1")!
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[1] == 2 ) && ( riscv_I.dp_bram2.bram[1] == 2 );
    rd_data = instruction( R_TYPE, isALUimm, 1, 3, 31, 1, 0, 12'dX ); // "slli rd,rs1,uimm5"
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[1] == 32'hFFFFF800 ) && ( riscv_I.dp_bram2.bram[1] == 32'hFFFFF800 );
    result( "xori rd,rs1,imm12" );
    $display( "    not rd,rs1 (pseudo)" ); // Pseudo xori instruction
    rd_data = instruction( R_TYPE, isALUimm, 2, 1, 31, 5, 0, 12'dX ); // "srli rd,rs1,uimm5"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[1] == 32'h80000000 ) && ( riscv_I.dp_bram2.bram[1] == 32'h80000000 );
    result( "slli rd,rs1,uimm5" );
    rd_data = instruction( R_TYPE, isALUimm, 2, 1, 31, 5, 7'h20, 12'dX ); // "srai rd,rs1,uimm5"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[2] == 1 ) && ( riscv_I.dp_bram2.bram[2] == 1 );
    result( "srli rd,rs1,uimm5" );
    rd_data = instruction( U_TYPE, isLUI, 5, 5'dX, 5'dX, 3'dX, 7'dX, 32'h80001XXX ); // "lui rd,imm20"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[2] == -1 ) && ( riscv_I.dp_bram2.bram[2] == -1 );
    result( "srai rd,rs1,uimm5" );
    rd_data = instruction( U_TYPE, isAUIPC, 5, 5'dX, 5'dX, 3'dX, 7'dX, 32'h00001XXX ); // "auipc rd,imm20"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[5] == 32'h80001000 ) && ( riscv_I.dp_bram2.bram[5] == 32'h80001000 );
    result( "lui rd,imm20" );
    PC = riscv_I.pc__; // Store PC for opcode "auipc"!
    rd_data = instruction( R_TYPE, isALUreg, 2, 3, 5, 0, 0, 32'dX ); // "add rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[5] == ( PC + 13'h1000 )) && ( riscv_I.dp_bram2.bram[5] == ( PC + 13'h1000 ));
    result( "auipc rd,imm20" );
    rd_data = instruction( R_TYPE, isALUreg, 2, 5, 3, 0, 7'h20, 32'dX ); // "sub rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[2] == ( PC + 13'h1001 )) && ( riscv_I.dp_bram2.bram[2] == ( PC + 13'h1001 ));
    result( "add rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 1, 0, 2, 0, 32'dX ); // "slt rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[2] == ( PC + 13'h0FFF )) && ( riscv_I.dp_bram2.bram[2] == ( PC + 13'h0FFF ));
    result( "sub rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 1, 0, 3, 0, 32'dX ); // "sltu rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == 1 ) && ( riscv_I.dp_bram2.bram[4] == 1 );
    result( "slt rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 2, 3, 7, 0, 32'dX ); // "and rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == 0 ) && ( riscv_I.dp_bram2.bram[4] == 0 );
    result( "sltu rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 5, 3, 6, 0, 32'dX ); // "or rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == 1 ) && ( riscv_I.dp_bram2.bram[4] == 1 );
    result( "and rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 2, 3, 4, 0, 32'dX ); // "xor rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == ( PC + 13'h1001 )) && ( riscv_I.dp_bram2.bram[4] == ( PC + 13'h1001 ));
    result( "or rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 2, 3, 1, 0, 32'dX ); // "sll rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == ( PC + 13'h0FFE )) && ( riscv_I.dp_bram2.bram[4] == ( PC + 13'h0FFE ));
    result( "xor rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 2, 3, 5, 0, 32'dX ); // "srl rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == (( PC + 13'h0FFF ) << 1 )) && ( riscv_I.dp_bram2.bram[4] == (( PC + 13'h0FFF ) << 1 ));
    result( "sll rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 4, 1, 3, 5, 7'h20, 32'dX ); // "sra rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == (( PC + 13'h0FFF ) >> 1 )) && ( riscv_I.dp_bram2.bram[4] == (( PC + 13'h0FFF ) >> 1 ));
    result( "srl rd,rs1,rs2" );
    rd_data = instruction( J_TYPE, isJAL, 5, 5'dX, 5'dX, 3'dX, 7'dX, 21'h00100 ); // "jal rd,imm20" {imm20 << 1)
    gcc( 1 );
    passed = ( riscv_I.dp_bram1.bram[4] == 32'hC0000000 ) && ( riscv_I.dp_bram2.bram[4] == 32'hC0000000 );
    result( "sra rd,rs1,rs2" );
    PC = riscv_I.pc__; // Store PC for opcode "jal"!
    passed = ( addr == ( PC + 20'h00100 ));
    gcc( 1 ); // Skipped rd_data
    passed = passed && ( riscv_I.dp_bram1.bram[5] == ( PC + 4 )) && ( riscv_I.dp_bram2.bram[5] == ( PC + 4 ));
    result( "jal rd,imm20" );
    rd_data = instruction( J_TYPE, isJAL, 0, 5'dX, 5'dX, 3'dX, 7'dX, 21'h1FFF00 ); // "j imm20" {imm20 << 1)
    gcc( 1 );
    passed = ( addr == PC );
    result( "j imm20" ); // Pseud0 jal instruction
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( I_TYPE, isJALR, 4, 5, 5'dX, 0, 7'dX, -4 ); // "jalr rd,rs1,imm12"
    gcc( 1 );
    passed = ( addr == PC );
    PC = riscv_I.pc__; // Store PC for opcode "jalr"!
    gcc( 1 ); // Skipped rd_data
    passed = passed && ( riscv_I.dp_bram1.bram[4] == ( PC + 4 )) && ( riscv_I.dp_bram2.bram[4] == ( PC + 4 ));
    result( "jalr rd,rs1,imm12" );
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 7, 0, 7'dX, -4 ); // "beq rs1,rs2,imm12",  x6 = x7
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "beq"!
    passed = ( riscv_I.pc__ == PC ) && ( addr == ( PC - 4 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 7, 0, 7'dX, 12 ); // "beq rs1,rs2,imm12",  x6 = x7
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC - 4 )) && ( addr == ( PC + 8 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 1, 0, 7'dX, -8 ); // "beq rs1,rs2,imm12" x6 != x1
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "beq"!
    passed = passed && ( riscv_I.pc__ == PC ) && ( addr == ( PC + 8 ));
    result( "beq rs1,rs2,imm12" );
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 1, 1, 7'dX, -8 ); // "bne rs1,rs2,imm12" x6 != x1
    gcc( 1 );
    passed = ( addr == ( PC - 4 )); // PC is from "beq"!
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 1, 1, 7'dX, 12 ); // "bne rs1,rs2,imm12" x6 != x1
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "bne"!
    passed = passed && ( riscv_I.pc__ == PC ) && ( addr == ( PC + 12 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 7, 1, 7'dX, 12 ); // "bne rs1,rs2,imm12",  x6 = x7
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 12 )) && ( addr == ( PC + 20 ));
    result( "bne rs1,rs2,imm12" );
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 1, 0, 4, 7'dX, 12 ); // "blt rs1,rs2,imm12",  x1 < x0
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "blt"!
    passed = ( addr == ( PC + 12 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 0, 1, 4, 7'dX, -12 ); // "blt rs1,rs2,imm12",  x0 < x1
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 12 )) && ( addr == ( PC + 20 ));
    result( "blt rs1,rs2,imm12" );
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 1, 0, 4, 7'dX, -12 ); // "bgt rs1,rs2,imm12",  x0 > x1
    gcc( 1 );
    passed = passed && ( addr == ( PC + 4 ));
    $display( "    bgt rs1,rs2,imm12 (pseudo)" ); // Pseudo blt instruction
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 0, 1, 6, 7'dX, 12 ); // "bltu rs1,rs2,imm12",  x0 < x1
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "bltu"!
    passed = ( addr == ( PC + 12 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 1, 0, 6, 7'dX, -12 ); // "bltu rs1,rs2,imm12",  x1 < x0
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 12 )) && ( addr == ( PC + 20 ));
    result( "bltu rs1,rs2,imm12" );
    $display( "    bgtu rs1,rs2,imm12 (pseudo)" ); // Pseudo blt instruction
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 1, 5, 7'dX, 12 ); // "bge rs1,rs2,imm12",  x6 >= x1
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "bge"!
    passed = ( addr == ( PC + 12 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 1, 3, 5, 7'dX, -12 ); // "bge rs1,rs2,imm12",  x1 >= x3
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 12 )) && ( addr == ( PC + 20 ));
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 0, 5, 7'dX, 12 ); // "bge rs1,rs2,imm12",  x6 == x0
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 16 )) && ( addr == ( PC + 28 ));
    result( "bge rs1,rs2,imm12" );
    $display( "    ble rs1,rs2,imm12 (pseudo)" ); // Pseudo bge instruction
    $display( "    blez rs1,rs2,imm12 (pseudo)" ); // Pseudo bge instruction
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 1, 0, 7, 7'dX, 12 ); // "bgeu rs1,rs2,imm12",  x1 >= x0
    gcc( 1 );
    PC = riscv_I.pc__; // Store PC for opcode "blt"!
    passed = ( addr == ( PC + 12 ));
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 3, 1, 7, 7'dX, -12 ); // "bgeu rs1,rs2,imm12",  x1 >= x3
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 12 )) && ( addr == ( PC + 20 ));
    rd_data = instruction( B_TYPE, isBranch, 5'dX, 6, 0, 7, 7'dX, 12 ); // "bgeu rs1,rs2,imm12",  x6 == x0
    gcc( 1 );
    passed = passed && ( riscv_I.pc__ == ( PC + 16 )) && ( addr == ( PC + 28 ));
    result( "bgeu rs1,rs2,imm12" );
    $display( "    bleu rs1,rs2,imm12 (pseudo)" ); // Pseudo bgeu instruction
    gcc( 1 ); // Skipped rd_data
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 2, 7'dX, 100 ); // "lw rd,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 100 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 1, 7'dX, 104 ); // "lh rd,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 104 );
    rd_data = 32'h01010101;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h01010101 ) && ( riscv_I.dp_bram2.bram[5] == 32'h01010101 );
    result( "lw rd,imm12(rs1)" );
    rd_data = 32'h01010202;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h00000202 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00000202 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 1, 7'dX, 106 ); // "lh rd,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 106 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 5, 7'dX, 106 ); // "lhu rd,imm12(rs1)"
    gcc( 1 );
    rd_data = 32'h80010202;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'hFFFF8001 ) && ( riscv_I.dp_bram2.bram[5] == 32'hFFFF8001 );
    result( "lh rd,imm12(rs1)" );
    gcc( 1 ); // Keep rd_data
    passed = ( riscv_I.dp_bram1.bram[5] == 32'h00008001 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00008001 );
    result( "lhu rd,imm12(rs1)" );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 0, 7'dX, 104 ); // "lb rd,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 104 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 0, 7'dX, 105 ); // "lb rd,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 105 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    rd_data = 32'h04030281;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'hFFFFFF81 ) && ( riscv_I.dp_bram2.bram[5] == 32'hFFFFFF81 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    gcc( 1 ); // Keep rd_data
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h00000002 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00000002 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 0, 7'dX, 106 ); // "lb rd,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 106 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 0, 7'dX, 107 ); // "lb rd,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 107 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    rd_data = 32'h04830281;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'hFFFFFF83 ) && ( riscv_I.dp_bram2.bram[5] == 32'hFFFFFF83 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    gcc( 1 ); // Keep rd_data
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h00000004 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00000004 );
    result( "lb rd,imm12(rs1)" );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 4, 7'dX, 104 ); // "lbu rd,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 104 );
    rd_data = instruction( I_TYPE, isLoad, 5, 6, 5'dX, 4, 7'dX, 107 ); // "lbu rd,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 107 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    rd_data = 32'h84030281;
    gcc( 1 );
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h00000081 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00000081 );
    passed = passed && !riscv_I.fetch_decode; // rd_data = load_data
    gcc( 1 ); // Keep rd_data
    passed = passed && ( riscv_I.dp_bram1.bram[5] == 32'h00000084 ) && ( riscv_I.dp_bram2.bram[5] == 32'h00000084 );
    result( "lbu rd,imm12(rs1)" );
    riscv_I.dp_bram1.bram[6] = 4;
    riscv_I.dp_bram2.bram[6] = 4;
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 2, 7'dX, 104 ); // "sw rs2,imm12(rs1)"
    gcc( 1 ); // rs1 = rd_data[19:15], rs2 = rd_data[24:20]
    passed = ( addr == 108 );
    passed = passed && ( wr_mask == 4'hF );
    passed = passed && ( wr_data == 32'h00001057 );
    result( "sw rs2,imm12(rs1)" );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 1, 7'dX, 106 ); // "sh rs2,imm12(rs1)"
    gcc( 1 );
    passed = ( addr == 110 );
    passed = passed && ( wr_mask == 4'hC );
    passed = passed && (( wr_data & 32'hFFFF0000 ) == 32'h10570000 );
    passed = passed && !riscv_I.fetch_decode; // addr = loadstore_addr
    gcc( 1 );
    passed = passed && !riscv_I.fetch_decode; // addr = PC
    gcc( 1 );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 5, 1, 7'dX, 104 ); // "sh rs2,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 108 );
    passed = passed && ( wr_mask == 4'h3 );
    passed = passed && (( wr_data & 32'h0000FFFF ) == 32'h00000084 );
    result( "sh rs2,imm12(rs1)" );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 0, 7'dX, 107 ); // "sb rs2,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 111 );
    passed = passed && ( wr_mask == 4'h8 );
    passed = passed && (( wr_data & 32'hFF000000 ) == 32'h57000000 );
    passed = passed && !riscv_I.fetch_decode; // addr = loadstore_addr
    gcc( 1 );
    passed = passed && !riscv_I.fetch_decode; // addr = PC
    gcc( 1 );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 0, 7'dX, 106 ); // "sb rs2,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 110 );
    passed = passed && ( wr_mask == 4'h4 );
    passed = passed && (( wr_data & 32'h00FF0000 ) == 32'h00570000 );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 0, 7'dX, 105 ); // "sb rs2,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 109 );
    passed = passed && ( wr_mask == 4'h2 );
    passed = passed && (( wr_data & 32'h0000FF00 ) == 32'h00005700 );
    passed = passed && !riscv_I.fetch_decode; // addr = loadstore_addr
    gcc( 1 );
    passed = passed && !riscv_I.fetch_decode; // addr = PC
    gcc( 1 );
    rd_data = instruction( S_TYPE, isStore, 5'dX, 6, 2, 0, 7'dX, 104 ); // "sb rs2,imm12(rs1)"
    gcc( 1 );
    passed = passed && ( addr == 108 );
    passed = passed && ( wr_mask == 4'h1 );
    passed = passed && (( wr_data & 32'h000000FF ) == 32'h00000057 );
    result( "sb rs2,imm12(rs1)" );
    $display( "    ---------------------" );
    $display( "    RISC-V M instructions" );
    $display( "    ---------------------" );
    rvim = 1;
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 2, 0, 1, 32'dX ); // "mul rd,rs1,rs2"
    riscv_IM.dp_bram1.bram[1] = -100;
    riscv_IM.dp_bram2.bram[1] = -100;
    riscv_IM.dp_bram1.bram[2] = 5;
    riscv_IM.dp_bram2.bram[2] = 5;
    riscv_IM.dp_bram1.bram[3] = -200;
    riscv_IM.dp_bram2.bram[3] = -200;
    riscv_IM.dp_bram1.bram[4] = 6;
    riscv_IM.dp_bram2.bram[4] = 6;
    gcc( 1 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 2, 1, 1, 32'dX ); // "mulh rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_IM.dp_bram1.bram[5] == -500 ) && ( riscv_IM.dp_bram2.bram[5] == -500 );
    result( "mul rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 2, 3, 1, 32'dX ); // "mulhu rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_IM.dp_bram1.bram[5] == -1 ) && ( riscv_IM.dp_bram2.bram[5] == -1 );
    result( "mulh rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 4, 2, 1, 32'dX ); // "mulhsu rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_IM.dp_bram1.bram[5] == 4 ) && ( riscv_IM.dp_bram2.bram[5] == 4 );
    result( "mulhu rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 3, 2, 4, 1, 32'dX ); // "div rd,rs1,rs2"
    gcc( 1 );
    passed = ( riscv_IM.dp_bram1.bram[5] == 5 ) && ( riscv_IM.dp_bram2.bram[5] == 5 );
    result( "mulhsu rd,rs1,rs2" );
    passed = riscv_IM.RVM1.isDivide_ && !riscv_IM.aluBusy;
    gcc( 1 );
    passed = passed && !riscv_IM.isALUreg && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    passed = passed && !riscv_IM.aluBusy && riscv_IM.aluFinished;
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == -40 ) && ( riscv_IM.dp_bram2.bram[5] == -40 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 4, 0, 4, 1, 32'dX ); // "div rd,rs1,rs2" pos rs1 division by zero!
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == -1 ) && ( riscv_IM.dp_bram2.bram[5] == -1 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 3, 0, 4, 1, 32'dX ); // "div rd,rs1,rs2" neg rs1 division by zero!
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == 1 ) && ( riscv_IM.dp_bram2.bram[5] == 1 ); // Does not match specification!
    result( "div rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 4, 5, 1, 32'dX ); // "divu rd,rs1,rs2"
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == 32'h2AAAAA9A ) && ( riscv_IM.dp_bram2.bram[5] == 31'h2AAAAA9A );
    rd_data = instruction( R_TYPE, isALUreg, 5, 1, 0, 5, 1, 32'dX ); // "divu rd,rs1,rs2" diviaion by zero!
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == -1 ) && ( riscv_IM.dp_bram2.bram[5] == -1 );
    result( "divu rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 3, 4, 6, 1, 32'dX ); // "rem rd,rs1,rs2"
    gcc( 2 );
    passed = riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == -2 ) && ( riscv_IM.dp_bram2.bram[5] == -2 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 3, 0, 6, 1, 32'dX ); // "rem rd,rs1,rs2" neg rs1 division by zero!
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == -200 ) && ( riscv_IM.dp_bram2.bram[5] == -200 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 4, 0, 6, 1, 32'dX ); // "rem rd,rs1,rs2" pos rs1 division by zero!
    gcc( 2 );
    passed = passed && riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == 6 ) && ( riscv_IM.dp_bram2.bram[5] == 6 );
    result( "rem rd,rs1,rs2" );
    rd_data = instruction( R_TYPE, isALUreg, 5, 4, 2, 7, 1, 32'dX ); // "remu rd,rs1,rs2"
    gcc( 2 );
    passed = riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == 1 ) && ( riscv_IM.dp_bram2.bram[5] == 1 );
    rd_data = instruction( R_TYPE, isALUreg, 5, 4, 0, 7, 1, 32'dX ); // "remu rd,rs1,rs2" division by zero!
    gcc( 2 );
    passed = riscv_IM.aluBusy;
    while ( riscv_IM.aluBusy ) gcc( 1 );
    gcc( 1 );
    passed = passed && ( riscv_IM.dp_bram1.bram[5] == 6 ) && ( riscv_IM.dp_bram2.bram[5] == 6 );
    result( "remu rd,rs1,rs2" );
    gcc( 1 );
   #10
    $display( "    ---------------------" );
    $display( "    %0d passed, %0d failed", nbPassed, nbFailed );
    $display( "    ---------------------" );
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "jascRV32_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // jascRV32_tb
