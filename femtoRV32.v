/**
 *  Copyright (c) 2020-2021 Bruno Levy, Matthias Koch
 *                2026      Kees Krijnen (Verilog 2001 - ISE14.7 synthesis)
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
 *  Description: FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
 *
 *  Version: The "quark/electron", the most elementary versions of FemtoRV32.
 *           A single VERILOG file, compact & understandable code.
 *
 *  Instruction set: RV32I(M) + RDCYCLES
 *
 *  Parameters:
 *
 *  - Reset address can be defined using PC_RESET (default is 0).
 *  - The SP_RESET parameter sets the stack pointer register (R2). Default zero,
 *    when not defined the register R2 could be initialized by programming,
 *    otherwise the stack top is located at the end of the address space.
 *  - The ADDR_WIDTH parameter sets the internal address bus (and address
 *    computation logic).
 *  - The RVM parameter adds multiply-divide instructions.
 *  - When RVM = 1, the DELAY_MULTIPLY parameter delays the multiply operation
 *    with one clock cycle (if required to meet timing constraints).
 *  - In general, instructions take two clock cycles, except for load/store
 *    branch instructions (three clock cycles) or multiple clock ALU operations
 *    (division).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Firmware generation flags for this processor
// `define NRV_ARCH     "rv32i" or "rv32im"
// `define NRV_ABI      "ilp32"
// `define NRV_OPTIMIZE "-Os" or "-O3"

/*============================================================================*/
module FemtoRV32 #(
/*============================================================================*/
    parameter PC_RESET = 0, // Program counter reset address
    parameter SP_RESET = 0, // Stack pointer register (R2) reset address
    parameter ADDR_WIDTH = 24, // S(D)RAM Address Width (32-bit aligned for PC)
    parameter [0:0] RVM = 0, // RISC-V Multiply-divide instruction extension
    parameter [0:0] DELAY_MULTIPLY = 0 ) // Delay multiply one clock cycle
    (
    input  wire clk,
    input  wire rst_n, // Set to 0 to reset the processor
    output wire [ADDR_WIDTH-1:0] mem_addr, // Address bus
    output wire [31:0] mem_wdata, // Data to be written
    output wire [3:0]  mem_wmask, // Write mask for the 4 bytes of each word
    input  wire [31:0] mem_rdata, // Input lines for both data and instr
    output wire mem_rstrb, // Active to initiate memory read (used by IO)
    input  wire mem_rbusy, // Asserted if memory is busy reading value
    input  wire mem_wbusy  // Asserted if memory is busy writing value
);

// Parameter checks
/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( ADDR_WIDTH > 32 ) begin
        $display( "ADDR_WIDTH > 32!" );
        $finish;
    end
    if ( !RVM && DELAY_MULTIPLY ) begin // RVM = 0
        $display( "DELAY_MULTIPLY invalid!" );
        $finish;
    end
end // param_check

reg [31:0] instr; // Latched instruction. Note that bits 0 and 1 are
                  // ignored (not used in RV32I(M) base instr set).

// Extracts rd,rs1,rs2,funct3,imm and opcode from instruction.
// Reference: Table page 104 of:
// https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

// The ALU function, decoded in 1-hot form (doing so reduces LUT count)
// It is used as follows: funct3Is[val] <=> funct3 == val

reg  [7:0] funct3Is = 0;

// The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
wire [31:0] Bimm = {{20{instr[31]}}, instr[7],instr[30:25], instr[11:8],1'b0};
wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21],1'b0};

// Base RISC-V (RV32I) has only 10 different instructions !
reg  isALUimm = 0;
reg  isAUIPC = 0;
reg  isBranch = 0;
reg  isALUreg = 0;
reg  isLoad = 0;
reg  isLUI = 0;
reg  isJAL = 0 ;
reg  isJALR = 0;
reg  isStore = 0;
reg  isSYSTEM = 0;
wire isALU = isALUimm | isALUreg;

reg  [ADDR_WIDTH-1:0] PC; // The program counter.
wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

// An adder used to compute branch address, JAL address and AUIPC.
// branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
// Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
wire [ADDR_WIDTH-1:0] PCplusImm =
    PC + ( instr[3] ? Jimm[ADDR_WIDTH-1:0] :
           instr[4] ? Uimm[ADDR_WIDTH-1:0] :
                      Bimm[ADDR_WIDTH-1:0] );

// The destination register
wire [4:0] rdId = instr[11:7];
// Register source
wire [4:0] rs1Id = mem_rdata[19:15]; // Not connected!
wire [4:0] rs2Id = mem_rdata[24:20]; // Not connected!
reg [31:0] rs1;
reg [31:0] rs2;
// First ALU source, always rs1
wire [31:0] aluIn1 = rs1;

// Second ALU source, depends on opcode:
//    ALUreg, Branch:     rs2
//    ALUimm, Load, JALR: Iimm
wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;
// The adder is used by both arithmetic instructions and JALR.
wire [31:0] aluPlus = aluIn1 + aluIn2;
// Use a single 33 bits subtract to do subtraction and all comparisons
// (trick borrowed from swapforth/J1)
wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0, aluIn1} + 33'b1;
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

wire jumpToPCplusImm = isJAL | (isBranch & predicate);

wire [ADDR_WIDTH-1:0] PC_new =
    isJALR          ? {aluPlus[ADDR_WIDTH-1:1],1'b0} :
    jumpToPCplusImm ? PCplusImm :
                      PCplus4;

// Use the same shifter both for left and right shifts by applying bit reversal
wire [31:0] shifter_in = funct3Is[1] ? {
    aluIn1[0],  aluIn1[1],  aluIn1[2],  aluIn1[3],  aluIn1[4],  aluIn1[5],
    aluIn1[6],  aluIn1[7],  aluIn1[8],  aluIn1[9],  aluIn1[10], aluIn1[11],
    aluIn1[12], aluIn1[13], aluIn1[14], aluIn1[15], aluIn1[16], aluIn1[17],
    aluIn1[18], aluIn1[19], aluIn1[20], aluIn1[21], aluIn1[22], aluIn1[23],
    aluIn1[24], aluIn1[25], aluIn1[26], aluIn1[27], aluIn1[28], aluIn1[29],
    aluIn1[30], aluIn1[31]} : aluIn1;

wire [31:0] shifter = $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];

wire [31:0] leftshift = {
    shifter[0],  shifter[1],  shifter[2],  shifter[3],  shifter[4],
    shifter[5],  shifter[6],  shifter[7],  shifter[8],  shifter[9],
    shifter[10], shifter[11], shifter[12], shifter[13], shifter[14],
    shifter[15], shifter[16], shifter[17], shifter[18], shifter[19],
    shifter[20], shifter[21], shifter[22], shifter[23], shifter[24],
    shifter[25], shifter[26], shifter[27], shifter[28], shifter[29],
    shifter[30], shifter[31]};

// Notes:
// - instr[30] is 1 for SUB and 0 for ADD
// - for SUB, need to test also instr[5] to discriminate ADDI:
//    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
// - instr[30] is 1 for SRA (do sign extension) and 0 for SRL
wire [31:0] aluOut_base =
    ( funct3Is[0] ? ( instr[30] & instr[5] ) ? aluMinus[31:0] : aluPlus : 32'b0 ) |
    ( funct3Is[1] ? leftshift                                           : 32'b0 ) |
    ( funct3Is[2] ? {31'b0, LT}                                         : 32'b0 ) |
    ( funct3Is[3] ? {31'b0, LTU}                                        : 32'b0 ) |
    ( funct3Is[4] ? aluIn1 ^ aluIn2                                     : 32'b0 ) |
    ( funct3Is[5] ? shifter                                             : 32'b0 ) |
    ( funct3Is[6] ? aluIn1 | aluIn2                                     : 32'b0 ) |
    ( funct3Is[7] ? aluIn1 & aluIn2                                     : 32'b0 );

wire aluWr; // ALU write strobe, starts dividing.
wire [31:0] aluOut;
wire isDivide;
wire isMultiplyDelayed;
reg  isMultiplyDelayed_ = 0;
wire aluBusy;
reg  aluBusy_ = 0;

localparam CCW = RVM ? 64 : 32; // Cycle Counter Width
reg  [CCW-1:0] cycles = 0;
wire [31:0] CSR_read;

/*============================================================================*/
always @(posedge clk) begin : cycle_counter
/*============================================================================*/
    cycles <= cycles + 1;
end // cycle_counter

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
    wire div_sign = ~instr[12] & ( instr[13] ? aluIn1[31] : ( aluIn1[31] != aluIn2[31] ) & |aluIn2 );
    reg  [31:0] divResult = 0;

    /*============================================================================*/
    always @(posedge clk) begin : div_rem_process // Highly inspired by PicoRV32
    /*============================================================================*/
        if ( isDivide & aluWr ) begin
            dividend <= ~instr[12] & aluIn1[31] ? -aluIn1 : aluIn1;
            divisor  <= {( ~instr[12] & aluIn2[31] ? -aluIn2 : aluIn2 ), 31'b0};
            quotient <= 0;
            quotient_msk <= 1 << 31;
        end else begin
            dividend     <= dividendN;
            divisor      <= divisor >> 1;
            quotient     <= quotientN;
            quotient_msk <= quotient_msk >> 1;
        end

        divResult <= instr[13] ? dividendN : quotientN;
        // Hold isMultiplyDelayed and aluBusy for rdUpdEn!
        isMultiplyDelayed_ <= isMultiplyDelayed;
        aluBusy_ <= aluBusy;
    end // div_rem_process

    wire [31:0] aluOut_muldiv =
        (  funct3Is[0]   ? multiply[31:0]  : 32'b0 ) | // 0:MUL
        ( |funct3Is[3:1] ? multiply[63:32] : 32'b0 ) | // 1:MULH, 2:MULHSU, 3:MULHU
        (  instr[14]     ? div_sign ? -divResult : divResult : 32'b0 ); // 4:DIV, 5:DIVU, 6:REM, 7:REMU

    wire isALUregFuncM = isALUreg & instr[25];
    assign isDivide = isALUregFuncM & instr[14]; // |funct3Is[7:4];
    assign isMultiplyDelayed = DELAY_MULTIPLY & isALUregFuncM & ~isDivide;
    assign aluBusy = |quotient_msk; // ALU is busy if division is in progress.
    assign aluOut = isALUregFuncM ? aluOut_muldiv : aluOut_base;

    wire sel_cyclesh = ( instr[31:20] == 12'hC80 );
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
reg  mem_halfwordAccess = 0;

// A separate adder to compute the destination of load/store.
// testing instr[5] is equivalent to testing isStore in this context.
wire [ADDR_WIDTH-1:0] loadstore_addr = rs1[ADDR_WIDTH-1:0] + (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

// isLoad, in addition to funct3[1:0], isLoad depends on:
// - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion
wire [15:0] LOAD_halfword = loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];
wire [7:0] LOAD_byte = loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];
wire LOAD_sign = !instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

wire [31:0] load_data =
        mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
    mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                         mem_rdata;

reg [31:0] registerFile[0:31];
reg [5:0] i;
/*============================================================================*/
initial begin : initialize_registers
/*============================================================================*/
    for ( i = 0; i < 32; i = i + 1 ) registerFile[i] = 0;

    registerFile[2] = SP_RESET; // R2 stack pointer register initialization.
end // initialize_registers

localparam FETCH_INSTR_bit = 0;
localparam EXECUTE_bit     = 1;
localparam WAIT_INSTR_bit  = 2;
localparam NB_STATES       = 3;

localparam [NB_STATES-1:0] FETCH_INSTR = 1 << FETCH_INSTR_bit;
localparam [NB_STATES-1:0] EXECUTE     = 1 << EXECUTE_bit;
localparam [NB_STATES-1:0] WAIT_INSTR  = 1 << WAIT_INSTR_bit;

// (* onehot *)
reg [NB_STATES-1:0] state;

// aluWr starts computation (shift/divide) in the ALU.
assign aluWr = state[EXECUTE_bit] & isALU;

wire needToWait = isBranch | isLoad | isMultiplyDelayed | isDivide | isStore;
wire rdUpdEn = ( ~needToWait & state[EXECUTE_bit] ) |
               ((( aluBusy_ & ~aluBusy ) | isLoad | isMultiplyDelayed_ ) & state[WAIT_INSTR_bit] );
// The value written back into the destination register.
wire [31:0] rdUpdate =
    ( isALU            ? aluOut     : 32'b0 ) |  // ALUreg, ALUimm
    ( isAUIPC          ? PCplusImm  : 32'b0 ) |  // AUIPC
    ( isJAL   | isJALR ? PCplus4    : 32'b0 ) |  // JAL, JALR
    ( isLoad           ? load_data  : 32'b0 ) |  // Load
    ( isLUI            ? Uimm       : 32'b0 ) |  // LUI
    ( isSYSTEM         ? CSR_read   : 32'b0 );   // SYSTEM

/*============================================================================*/
always @(posedge clk) begin : update_registerFile
/*============================================================================*/
    if ( rdUpdEn ) begin
        if ( rdId != 0 ) registerFile[rdId] <= rdUpdate;
    end
end // update_registerFile

// isStore
assign mem_wdata[7:0]   = rs2[7:0];
assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0] : rs2[15:8];
assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0] : rs2[23:16];
assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0] : loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

// The memory write mask:
//    1111                     if writing a word
//    0011 or 1100             if writing a halfword (depending on loadstore_addr[1])
//    0001, 0010, 0100 or 1000 if writing a byte (depending on loadstore_addr[1:0])

wire [3:0] STORE_wmask = {4{isStore}} & (
    mem_byteAccess      ?
    ( loadstore_addr[1] ?
    ( loadstore_addr[0] ? 4'b1000 : 4'b0100 ) :
    ( loadstore_addr[0] ? 4'b0010 : 4'b0001 )) :
    mem_halfwordAccess  ?
    ( loadstore_addr[1] ? 4'b1100 : 4'b0011 ) :
                          4'b1111 );

assign mem_addr = state[EXECUTE_bit] & ( isLoad | isStore ) ? loadstore_addr :
                  state[EXECUTE_bit]                        ? PC_new :
                                                              PC;
// The memory-read signal.
assign mem_rstrb = state[EXECUTE_bit] & isLoad;
// The mask for memory-write.
assign mem_wmask = {4{state[EXECUTE_bit]}} & STORE_wmask;

/*============================================================================*/
always @(posedge clk) begin : state_machine
/*============================================================================*/
    if ( state[FETCH_INSTR_bit] ) begin
        if ( !( mem_rbusy | mem_wbusy )) begin
            state <= EXECUTE;
            isLoad    <= ( mem_rdata[6:2] == 5'b00000 ); // rd <- mem[rs1+Iimm]
            isALUimm  <= ( mem_rdata[6:2] == 5'b00100 ); // rd <- rs1 OP Iimm
            isAUIPC   <= ( mem_rdata[6:2] == 5'b00101 ); // rd <- PC + Uimm
            isStore   <= ( mem_rdata[6:2] == 5'b01000 ); // rd <- mem[rs1+Iimm]
            isALUreg  <= ( mem_rdata[6:2] == 5'b01100 ); // rd <- rs1 OP rs2
            isLUI     <= ( mem_rdata[6:2] == 5'b01101 ); // rd <- Uimm
            isBranch  <= ( mem_rdata[6:2] == 5'b11000 ); // if ( rs1 OP rs2 ) PC <- PC + Bimm
            isJALR    <= ( mem_rdata[6:2] == 5'b11001 ); // rd <- PC + 4; PC <- rs1 + Iimm
            isJAL     <= ( mem_rdata[6:2] == 5'b11011 ); // rd <- PC + 4; PC <- PC + Jimm
            isSYSTEM  <= ( mem_rdata[6:2] == 5'b11100 ); // rd <- cycles
            funct3Is  <= ( 8'b00000001 << mem_rdata[14:12] );
            mem_byteAccess     <= ( mem_rdata[13:12] == 2'b00 ); // funct3[1:0] == 2'b00;
            mem_halfwordAccess <= ( mem_rdata[13:12] == 2'b01 ); // funct3[1:0] == 2'b01;
            rs1 <= registerFile[mem_rdata[19:15]];
            rs2 <= registerFile[mem_rdata[24:20]];
            instr[31:2] <= mem_rdata[31:2]; // Bits 0 and 1 are ignored.
        end
    end

    if ( state[EXECUTE_bit] ) begin
       state <= needToWait ? WAIT_INSTR : FETCH_INSTR;
       PC <= PC_new;
    end

    if ( state[WAIT_INSTR_bit] ) begin
        if ( !aluBusy ) state <= FETCH_INSTR;
    end

    if ( !rst_n ) begin
        state <= WAIT_INSTR;
        PC <= PC_RESET[ADDR_WIDTH-1:0];
    end
end // state_machine

endmodule // FemtoRV32
