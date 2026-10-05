/**
 *  Copyright (c) 2020-2021 Bruno Levy, Matthias Koch (FemtoRV32)
 *  Copyright (c) 2026 Kees Krijnen (JascRV32)
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its
 *     contributors may be used to endorse or promote products derived from this
 *     software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 *  BSD 3-Clause License, see https://opensource.org/license/BSD-3-clause
 *
 *  Description: JascRV32, Just Another Soft Core (Single Cycle) RISC-V 32-bit
 *               processor. Inspired by FemtoRV32. Differences are:
 *
 *  - Verilog 2001 compliant - ISE 14.7 synthesis
 *  - RISC-V registers R0-R31 are (synchronous) dual port block ram based
 *  - Usage (optionally) multiple R0-R31 register sets to support interrupt,
 *    subroutine, thread handling. Four clock cycle context switch.
 *    PC stored in / retrieved from R0 during context switch.
 *  - Reset address can be defined using PC_RESET (default is 0).
 *  - The SP_RESET parameter sets the stack pointer register (R2). Default zero,
 *    when not defined the register R2 could be initialized by programming,
 *    otherwise the stack top is located at the end of the address space.
 *  - The AW parameter sets the internal address bus (and address
 *    computation logic).
 *  - The RVM parameter adds multiply-divide instructions.
 *  - When RVM = 1, the DELAY_MULTIPLY parameter delays the multiply operation
 *    with one clock cycle (if required to meet timing constraints).
 *
 *  In general, instructions take one clock cycle, except for instructions (two
 *  clock cycles) following branch/jump/load/store instructions (sets the cpu
 *  address bus) or multiple clock ALU operations (division).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module jascRV32 #( // No inout (bus) interface!
/*============================================================================*/
    parameter PC_RESET = 32'h00000000, // Program counter reset address
    parameter SP_RESET = 0, // Stack pointer register (R2) reset address
    parameter [5:0] AW = 24, // S(D)RAM Address Width (32-bit aligned for PC)
    parameter [0:0] RVM = 0, // RISC-V Multiply-divide instruction extension
    parameter [0:0] DELAY_MULTIPLY = 0, // Delay multiply one clock cycle
    parameter R0R31MEM = "" ) // Register set R0-R31 (0-15) initialization
    (
    input  wire clk,
    input  wire rst_n, // Synchronous reset, high when clk is stable!
    output wire [AW-1:0] addr, // Address bus
    input  wire [31:0] rd_data, // Input data and instructions
    output wire rd, // Read memory (mapped I/O)
    output wire [31:0] wr_data, // Data to be written
    output wire [3:0]  wr_mask, // Write mask (4 bytes) memory (mapped I/O)
    output wire [31:0] sccc, // System clock cycle counter
    input  wire hold, // Data bus locked or external reading/writing busy
    input  wire [3:0] r0r31_sel // Select register set R0-R31 (0-15)
);

localparam R0R31SETS = 16; // Maximal BRAM utilization!
// Parameter checks
/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( R0R31SETS != 16 ) begin
        $display( "R0R31SETS invalid value %d!", R0R31SETS );
        $finish;
    end
    if ( AW > 32 ) begin
        $display( "AW > 32!" );
        $finish;
    end
    if ( !RVM && DELAY_MULTIPLY ) begin // RVM = 0
        $display( "DELAY_MULTIPLY invalid!" );
        $finish;
    end
end // param_check

// Base RISC-V (RV32I) instructions
reg  isALUimm = 0;
reg  isAUIPC = 0;
reg  isBranch = 0;
reg  isALUreg = 0;
reg  isLoad = 0;
reg  isLoad_ = 0; // isLoad, one clock cycle delayed!
reg  isLoad__ = 0; // isLoad, two clock cycles delayed!
reg  isLUI = 0;
reg  isJAL = 0 ;
reg  isJALR = 0;
reg  isStore = 0;
reg  isStore_ = 0; // isStore, one clock cycle delayed!
reg  isStore__ = 0; // isStore, two clock cycles delayed!
reg  isSYSTEM = 0;
wire isALU = isALUimm | isALUreg;

assign rd = isLoad;

reg  [AW-1:0] PC = PC_RESET[AW-1:0]; // The program counter.
reg  [AW-1:0] pc_ = 0; // PC, one clock cycle delayed!
reg  [AW-1:0] pc__ = 0; // PC, two clock cycles delayed!

reg  [31:0] opcode = 0;
reg  [4:0] rdId_ = 0; // rdId, , one clock cycle delayed!
wire [4:0] rdId = isLoad_ ? rdId_ : opcode[11:7]; // The destination register
reg  [7:0] funct3Is = 0;
wire [4:0] rs1Id = opcode[19:15]; // The source 1 register
wire [4:0] rs2Id = opcode[24:20]; // The source 2 register

// The five immediate formats
wire [31:0] Uimm = {opcode[31:12], {12{1'b0}}};
wire [31:0] Iimm = {{21{opcode[31]}}, opcode[30:20]};
wire [31:0] Simm = {{21{opcode[31]}}, opcode[30:25], opcode[11:7]};
wire [31:0] Bimm = {{20{opcode[31]}}, opcode[7], opcode[30:25], opcode[11:8], 1'b0};
wire [31:0] Jimm = {{12{opcode[31]}}, opcode[19:12], opcode[20], opcode[30:21], 1'b0};

wire [31:0] load_data; // The data retreived from isLoad
reg  [31:0] rdUpdate_ = 0; // The (last) value written back to the destination register rdId
wire [31:0] eqIdRdUpdate = isLoad_ ? load_data : rdUpdate_;
reg  eqId_rd_rs1 = 0; // rdId_ == rs1Id
reg  eqId_rd_rs2 = 0; // rdId_ == rs2Id
wire [31:0] dp_bram1_data_bo;
wire [31:0] dp_bram2_data_bo;
wire [31:0] rs1 = |rs1Id ? ( eqId_rd_rs1 ? eqIdRdUpdate : dp_bram1_data_bo ) : 0; // The value read from source register rs1Id
wire [31:0] rs2 = |rs2Id ? ( eqId_rd_rs2 ? eqIdRdUpdate : dp_bram2_data_bo ) : 0; // The value read from source register rs2Id

wire [31:0] aluIn1 = rs1;
wire [31:0] aluIn2 =  ( isALUreg | isBranch ) ? rs2 : Iimm;
wire [31:0] aluPlus = aluIn1 + aluIn2;

// Use a single 33 bits subtract to do subtraction and all comparisons (trick borrowed from swapforth/J1)
wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
wire LT = ( aluIn1[31] ^ aluIn2[31] ) ? aluIn1[31] : aluMinus[32];
wire LTU = aluMinus[32];
wire EQ = ( aluMinus[31:0] == 0 );

wire predicate =
    funct3Is[0] &  EQ  | // BEQ
    funct3Is[1] & ~EQ  | // BNE
    funct3Is[4] &  LT  | // BLT
    funct3Is[5] & ~LT  | // BGE
    funct3Is[6] &  LTU | // BLTU
    funct3Is[7] & ~LTU;  // BGEU

// Use the same shifter both for left and right shifts by applying bit reversal
wire [31:0] shifter_in = funct3Is[1] ? {
    aluIn1[0],  aluIn1[1],  aluIn1[2],  aluIn1[3],  aluIn1[4],  aluIn1[5],
    aluIn1[6],  aluIn1[7],  aluIn1[8],  aluIn1[9],  aluIn1[10], aluIn1[11],
    aluIn1[12], aluIn1[13], aluIn1[14], aluIn1[15], aluIn1[16], aluIn1[17],
    aluIn1[18], aluIn1[19], aluIn1[20], aluIn1[21], aluIn1[22], aluIn1[23],
    aluIn1[24], aluIn1[25], aluIn1[26], aluIn1[27], aluIn1[28], aluIn1[29],
    aluIn1[30], aluIn1[31]} : aluIn1;

wire [31:0] shifter = $signed({opcode[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];

wire [31:0] leftshift = {
    shifter[0],  shifter[1],  shifter[2],  shifter[3],  shifter[4],
    shifter[5],  shifter[6],  shifter[7],  shifter[8],  shifter[9],
    shifter[10], shifter[11], shifter[12], shifter[13], shifter[14],
    shifter[15], shifter[16], shifter[17], shifter[18], shifter[19],
    shifter[20], shifter[21], shifter[22], shifter[23], shifter[24],
    shifter[25], shifter[26], shifter[27], shifter[28], shifter[29],
    shifter[30], shifter[31]};

// Notes:
// - opcode[30] is 1 for SUB and 0 for ADD
// - for SUB, need to test also opcode[5] to discriminate ADDI:
//    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
// - opcode[30] is 1 for SRA (do sign extension) and 0 for SRL
wire [31:0] aluOut_base =
    ( funct3Is[0] ? ( opcode[30] & opcode[5] ) ? aluMinus[31:0] : aluPlus : 32'b0 ) |
    ( funct3Is[1] ? leftshift                                             : 32'b0 ) |
    ( funct3Is[2] ? {31'b0, LT}                                           : 32'b0 ) |
    ( funct3Is[3] ? {31'b0, LTU}                                          : 32'b0 ) |
    ( funct3Is[4] ? aluIn1 ^ aluIn2                                       : 32'b0 ) |
    ( funct3Is[5] ? shifter                                               : 32'b0 ) |
    ( funct3Is[6] ? aluIn1 | aluIn2                                       : 32'b0 ) |
    ( funct3Is[7] ? aluIn1 & aluIn2                                       : 32'b0 );

wire [31:0] aluOut;
wire isDivide;
wire isMultiplyDelayed;
wire aluBusy;

localparam CCW = RVM ? 64 : 32; // Cycle Counter Width
reg  [CCW-1:0] cycles = 0;
wire [31:0] CSR_read;

/*============================================================================*/
always @(posedge clk) begin : cycle_counter
/*============================================================================*/
    cycles <= cycles + 1;
end // cycle_counter

assign sccc = cycles[31:0];

generate
/*============================================================================*/
if ( RVM ) begin : RVM1 // Conditional systhesis!
/*============================================================================*/
    // funct3: 1->MULH, 2->MULHSU  3->MULHU
    wire isMULH = funct3Is[1];
    wire isMULHSU = funct3Is[2];

    wire sign1 = aluIn1[31] & isMULH;
    wire sign2 = aluIn2[31] & ( isMULH | isMULHSU );

    wire signed [32:0] signed1 = {sign1, aluIn1};
    wire signed [32:0] signed2 = {sign2, aluIn2};
    wire signed [63:0] multiply = signed1 * signed2;

    reg  [31:0] dividend = 0;
    reg  [62:0] divisor = 0;
    reg  [31:0] quotient = 0;
    reg  [31:0] quotient_msk = 0;

    wire divstep_do = divisor <= {31'b0, dividend};
    wire [31:0] dividendN = divstep_do ? dividend - divisor[31:0] : dividend;
    wire [31:0] quotientN = divstep_do ? quotient | quotient_msk  : quotient;
    wire div_sign = ~opcode[12] & ( opcode[13] ? aluIn1[31] : ( aluIn1[31] != aluIn2[31] ) & |aluIn2 );
    reg  [31:0] divResult = 0;

    /*============================================================================*/
    always @(posedge clk) begin : div_rem_process // Highly inspired by PicoRV32
    /*============================================================================*/
        if ( isDivide && !aluBusy ) begin
            dividend <= ~opcode[12] & aluIn1[31] ? -aluIn1 : aluIn1;
            divisor  <= {( ~opcode[12] & aluIn2[31] ? -aluIn2 : aluIn2 ), 31'b0};
            quotient <= 0;
            quotient_msk <= 1 << 31;
        end else begin
            dividend     <= dividendN;
            divisor      <= divisor >> 1;
            quotient     <= quotientN;
            quotient_msk <= quotient_msk >> 1;
        end

        divResult <= opcode[13] ? dividendN : quotientN;
    end // div_rem_process

    wire [31:0] aluOut_muldiv =
        (  funct3Is[0]   ? multiply[31:0]  : 32'b0 ) | // 0:MUL
        ( |funct3Is[3:1] ? multiply[63:32] : 32'b0 ) | // 1:MULH, 2:MULHSU, 3:MULHU
        (  opcode[14]     ? div_sign ? -divResult : divResult : 32'b0 ); // 4:DIV, 5:DIVU, 6:REM, 7:REMU

    wire isALUregFuncM = isALUreg & opcode[25];
    assign isDivide = isALUregFuncM & opcode[14]; // |funct3Is[7:4];
    assign isMultiplyDelayed = DELAY_MULTIPLY & isALUregFuncM & ~isDivide;
    assign aluBusy = |quotient_msk; // ALU is busy if division is in progress.
    assign aluOut = isALUregFuncM ? aluOut_muldiv : aluOut_base;

    wire sel_cyclesh = ( opcode[31:20] == 12'hC80 );
    assign CSR_read = sel_cyclesh ? cycles[63:32] : cycles[31:0];
/*============================================================================*/
end else begin : RVM0 // Conditional systhesis!
/*============================================================================*/
    assign isDivide = 0;
    assign isMultiplyDelayed = 0;
    assign aluBusy = 0;
    assign aluOut = aluOut_base;
    assign CSR_read = cycles;
end
/*============================================================================*/
endgenerate

// All memory accesses are aligned on 32 bits boundary. For this reason, we need
// some circuitry that does unaligned halfword and byte load/store, based on:
// - funct3[1:0]:  00->byte 01->halfword 10->word
// - mem_addr[1:0]: indicates which byte/halfword is accessed
reg  mem_byteAccess = 0;
reg  mem_byteAccess_ = 0; // mem_byteAccess, one clock cycle delayed!
reg  mem_halfwordAccess = 0;
reg  mem_halfwordAccess_ = 0; // mem_halfwordAccess, one clock cycle delayed!
reg  opcode_14_n = 0; // ~opcode[14], one clock cycle delayed!

// A separate adder to compute the destination of load/store.
wire [AW-1:0] loadstore_addr = rs1[AW-1:0] + ( isStore ? Simm[AW-1:0] : Iimm[AW-1:0] );
reg  [1:0] loadstore_addr_ = 0;

// isLoad, in addition to funct3[1:0], depends on funct3[2] (opcode[14]): 0->do sign expansion   1->no sign expansion
wire [15:0] load_halfword = loadstore_addr_[1] ? rd_data[31:16] : rd_data[15:0];
wire [7:0] load_byte = loadstore_addr_[0] ? load_halfword[15:8] : load_halfword[7:0];
wire load_sign = opcode_14_n & ( mem_byteAccess_ ? load_byte[7] : load_halfword[15] );

assign load_data =
        mem_byteAccess_ ? {{24{load_sign}},     load_byte} :
    mem_halfwordAccess_ ? {{16{load_sign}}, load_halfword} :
                          rd_data;
// isStore
assign wr_data[7:0] = rs2[7:0];
assign wr_data[15:8] = loadstore_addr[0] ? rs2[7:0] : rs2[15:8];
assign wr_data[23:16] = loadstore_addr[1] ? rs2[7:0] : rs2[23:16];
assign wr_data[31:24] = loadstore_addr[0] ? rs2[7:0] : loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

// The memory write mask:
//    1111                     if writing a word
//    0011 or 1100             if writing a halfword (depending on loadstore_addr[1])
//    0001, 0010, 0100 or 1000 if writing a byte (depending on loadstore_addr[1:0])
assign wr_mask = {4{isStore}} & (
    mem_byteAccess      ?
    ( loadstore_addr[1] ?
    ( loadstore_addr[0] ? 4'b1000 : 4'b0100 ) :
    ( loadstore_addr[0] ? 4'b0010 : 4'b0001 )) :
    mem_halfwordAccess  ?
    ( loadstore_addr[1] ? 4'b1100 : 4'b0011 ) :
                          4'b1111 );

// An adder used to compute branch address, JAL address and AUIPC.
wire [AW-1:0] PCplusImm = pc__ + ( isJAL ? Jimm[AW-1:0] : ( isAUIPC ? Uimm[AW-1:0] : Bimm[AW-1:0] ));
wire jumpToPCplusImm = isJAL | ( isBranch & predicate );
wire isJump = isJALR | jumpToPCplusImm;
reg  isJump_ = 0; // isJump, one clock clycle delayed!

wire [AW-1:0] PC_addr = isJALR ? {aluPlus[AW-1:1], 1'b0} : ( jumpToPCplusImm ? PCplusImm : PC );
wire [AW-1:0] PC_next = PC_addr + {{(AW-3){1'b0}}, 3'd4}; // + 4
wire [31:0] dp_bram1_data_ao;

assign addr = ( isLoad | isStore ) ? loadstore_addr[AW-1:0] : PC_addr; // Memory (I/O) address

// The value written back into the destination register.
wire [31:0] rdUpdate = |rdId ? // rdId > 0
         (( isALU            ? aluOut     : 32'b0 ) |  // ALUreg, ALUimm
          ( isAUIPC          ? PCplusImm  : 32'b0 ) |  // AUIPC
          ( isJAL   | isJALR ? pc_        : 32'b0 ) |  // JAL, JALR (PCplus4)
          ( isLUI            ? Uimm       : 32'b0 ) |  // LUI
          ( isSYSTEM         ? CSR_read   : 32'b0 ))   // SYSTEM
                                          : {{(32-AW){1'b0}}, PC};

wire [31:0] dp_bram_data_ai = isLoad_ ? load_data : isLoad__ ? rdUpdate_ : rdUpdate;
reg  [3:0] r0r31_set = 0;
reg  aluBusy_ = 0; // aluBusy, one clock cycle delayed!
reg  isMultiplyDelayed_ = 0; // isMultiplyDelayed, one clock cycle delayed!
reg  [1:0] cs_ws = 0; // Context switch wait states
wire zero_cs_ws = ( cs_ws == 0 );
wire fetch_decode = ~( aluBusy | hold | isJump | isLoad_ | isStore_ | isMultiplyDelayed );

/*============================================================================*/
always @(posedge clk) begin : execute
/*============================================================================*/
    if ( !rst_n ) begin
        isStore_ <= 1'b1; // Delay start of processing opcode one clock cycle!
        PC <= PC_RESET[AW-1:0];
    end else begin
        aluBusy_ <= aluBusy;
        isMultiplyDelayed_ <= isMultiplyDelayed;
        // isLoad and isStore related flags, one clock cycle delayed!
        mem_byteAccess_ <= mem_byteAccess;
        mem_halfwordAccess_ <= mem_halfwordAccess;
        // isLoad related flags and registers, one clock cycle delayed!
        opcode_14_n <= ~opcode[14];
        loadstore_addr_ <= loadstore_addr[1:0];
        rdId_ <= rdId;
        rdUpdate_ <= isLoad_ ? rdUpdate : dp_bram_data_ai; // isLoad_ => dp_bram_data_ai = load_data
        // Pulse (single clock clycle) flags for single clock cycle fetch_decode!
        isLoad <= 0;
        isLoad_ <= isLoad;
        isLoad__ <= isLoad_;
        isALUimm <= 0;
        isAUIPC <= 0;
        isStore <= 0;
        isStore_ <= isStore;
        isStore__ <= isStore_;
        isALUreg <= 0; // isMultiplyDelayed
        isLUI <= 0;
        isBranch <= 0;
        isJAL <= 0;
        isJALR <= 0;
        isJump_ <= isJump;
        isSYSTEM <= 0;

        if ( fetch_decode )  begin
            isLoad    <= ( rd_data[6:2] == 5'b00000 ); // rd <- mem[rs1Id+Iimm]
            isALUimm  <= ( rd_data[6:2] == 5'b00100 ); // rd <- rs1Id OP Iimm
            isAUIPC   <= ( rd_data[6:2] == 5'b00101 ); // rd <- PC + Uimm
            isStore   <= ( rd_data[6:2] == 5'b01000 ); // rd <- mem[rs1Id+Iimm] <= rs2
            isALUreg  <= ( rd_data[6:2] == 5'b01100 ); // rd <- rs1Id OP rs2Id
            isLUI     <= ( rd_data[6:2] == 5'b01101 ); // rd <- Uimm
            isBranch  <= ( rd_data[6:2] == 5'b11000 ); // if ( rs1Id OP rs2Id ) PC <- PC + Bimm
            isJALR    <= ( rd_data[6:2] == 5'b11001 ); // rd <- PC + 4; PC <- rs1Id + Iimm
            isJAL     <= ( rd_data[6:2] == 5'b11011 ); // rd <- PC + 4; PC <- PC + Jimm
            isSYSTEM  <= ( rd_data[6:2] == 5'b11100 ); // rd <- cycles
            funct3Is  <= 8'b00000001 << rd_data[14:12];
            mem_byteAccess     <= ( rd_data[13:12] == 2'b00 ); // funct3[1:0] == 2'b00;
            mem_halfwordAccess <= ( rd_data[13:12] == 2'b01 ); // funct3[1:0] == 2'b01;
            eqId_rd_rs1 <= ( rdId == rd_data[19:15] ); // rdId_ == rs1Id
            eqId_rd_rs2 <= ( rdId == rd_data[24:20] ); // rdId_ == rs2Id
            opcode[31:2] <= rd_data[31:2]; // Bits 0 and 1 are ignored.
        end

        if ( zero_cs_ws ) begin
             pc_ <= PC_addr;
             pc__ <= pc_;
            if ( !( isLoad | isStore )) begin
                PC <= PC_next;
            end
        end

        if ( !zero_cs_ws || ( r0r31_set != r0r31_sel )) begin
            case ( cs_ws )
            2'd3 : begin
                opcode[31:2] <= {{(25){1'b0}}, 05'b11000}; // isBranch, rdId = 0!
                r0r31_set <= r0r31_sel; // Also store PC into R0
            end
            // cs_ws = 2, dp_bram1_data_ao valid next clock cycle
            2'd1 : PC <= dp_bram1_data_ao[AW-1:0];
            default :;
            endcase
            isStore_ <= 1'b1; // Stop processing opcode!
            cs_ws <= cs_ws - 1; // Wrap around 0 -> 3!
        end
    end
end // execute

wire needToWait = hold | isBranch | isDivide | isJump_ | isLoad | isMultiplyDelayed | isStore | isStore__;
wire rdUpdEn =  ( |rdId | |cs_ws ) & ( ~needToWait | ( aluBusy_ & ~aluBusy ) | isLoad_ | isMultiplyDelayed_ );

dp_bram #(
    .AW(9),
    .DW(32),
    .BRAMMEM(R0R31MEM))
/*============================================================================*/
dp_bram1(
/*============================================================================*/
    .clk_a(clk),
    .en_a(rst_n),
    .we_a(rdUpdEn),
    .addr_a({r0r31_set, rdId}),
    .data_ai(dp_bram_data_ai),
    .data_ao(dp_bram1_data_ao),
    .clk_b(clk),
    .en_b(rst_n),
    .we_b(1'b0), // Never write to BRAM B port!
    .addr_b({r0r31_set, rd_data[19:15]}),
    .data_bi(32'd0), // Tie to zero
    .data_bo(dp_bram1_data_bo)
    );

dp_bram #(
    .AW(9),
    .DW(32),
    .BRAMMEM(R0R31MEM))
/*============================================================================*/
dp_bram2(
/*============================================================================*/
    .clk_a(clk),
    .en_a(rst_n),
    .we_a(rdUpdEn),
    .addr_a({r0r31_set, rdId}),
    .data_ai(dp_bram_data_ai),
    .data_ao(), // Ignore BRAM A output port!
    .clk_b(clk),
    .en_b(rst_n),
    .we_b(1'b0), // Never write to BRAM B port!
    .addr_b({r0r31_set, rd_data[24:20]}),
    .data_bi(32'd0), // Tie to zero
    .data_bo(dp_bram2_data_bo)
    );

endmodule // jascRV32

`ifndef JASCRV32_EXT_DP_BRAM
/*============================================================================*/
module dp_bram #( // Dual Port Block RAM
/*============================================================================*/
    parameter AW = 9, // Address Width
    parameter DW = 32, // Data Width
    parameter BRAMMEM = "" ) // BRAM initialization
    (
    input  wire clk_a,
    input  wire en_a,
    input  wire we_a,
    input  wire [AW-1:0] addr_a,
    input  wire [DW-1:0] data_ai,
    output reg  [DW-1:0] data_ao = 0,
    input  wire clk_b,
    input  wire en_b,
    input  wire we_b,
    input  wire [AW-1:0] addr_b,
    input  wire [DW-1:0] data_bi,
    output reg  [DW-1:0] data_bo = 0
    );

localparam MD = 2 ** AW; // Memory Depth

reg [DW-1:0] bram[0:MD-1];

/*============================================================================*/
always @(posedge clk_a) begin : dp_bram_a
/*============================================================================*/
    if ( en_a ) begin
        if ( we_a ) bram[addr_a] <= data_ai;
        data_ao <= bram[addr_a];
    end
end

/*============================================================================*/
always @(posedge clk_b) begin : dp_bram_b
/*============================================================================*/
    if ( en_b ) begin
        if ( we_b ) bram[addr_b] <= data_bi;
        data_bo <= bram[addr_b];
    end
end

reg [AW:0] i;
/*============================================================================*/
initial begin : init_bram
/*============================================================================*/
    for ( i = 0; i < MD; i = i + 1 ) bram[i] = 0;
    if ( BRAMMEM != "" ) $readmemh( BRAMMEM, bram );
end // init_ram

endmodule // dp_bram
`endif
