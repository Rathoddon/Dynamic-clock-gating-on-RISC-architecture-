`timescale 1ns/1ps

module project_ca(
    input  wire clk,
    input  wire reset,
    output wire debug_clk
);

assign debug_clk = clk;

// Control signals
wire decode_en, pc_en, reg_wt, mem_rd, mem_wt, jmp;
wire carry_int, zero_int, parity_int;
wire [1:0] wb_sel;

// Gating signals
wire mem_en, reg_en_gated_ctrl;
wire cg_reg;
wire [2:0] cu_state;

// Datapath wires
wire [15:0] pc, alu_result, regA, regB, immediate, mem_data, write_data;
wire [23:0] instruction;
wire [3:0] opcode, rz, rx, ry;

// =======================================================
// GATING CONTROLLER (register-file gating only - IR is ungated)
// =======================================================
gating_controller GCTRL (
    .state(cu_state),
    .opcode(opcode),
    .reg_wt(reg_wt),
    .mem_en(mem_en),
    .reg_en(reg_en_gated_ctrl)
);

// Proven BUFGCE-based clock gate for the register file

clock_gate CG_REG (.clk(clk), .enable(reg_en_gated_ctrl), .gclk(reg_gclk));
clock_gate CG_DM  (.clk(clk), .enable(mem_en),            .gclk(dm_gclk));

registers R(.rz(rz), .rx(rx), .ry(ry), .out_data(write_data),
            .reg_wt(reg_wt), .clk(reg_gclk),
            .rx_value(regA), .ry_value(regB));

data_memory DM(.address(alu_result), .clk(dm_gclk), .mem_rd(mem_rd),
               .mem_wt(mem_wt), .write_data(regB),
               .data(mem_data));
// Modules
program_counter PC(.clk(clk), .reset(reset), .pc_en(pc_en), .jmp(jmp),
                   .jmp_address(immediate), .address(pc));

instruction_memory IM(.address(pc), .instruction(instruction));

// Instruction register runs on plain clk - no gating.
// This removes the same-edge race that was corrupting opcode/immediate
// and causing X-lockup after JUMP/BEQ/BNE.
instruction_register IR(.instruction(instruction), .clk(clk),
                        .reset(reset), .opcode(opcode), .rz(rz), .rx(rx), .ry(ry),
                        .immediate(immediate));

Write_data WR(.immediate(immediate), .data(mem_data), .ALU_op(alu_result),
              .sel(wb_sel), .out_data(write_data));

alu ALU(.rx_value(regA), .ry_value(regB), .opcode(opcode),
        .ALU_op(alu_result), .carry(carry_int), .zero(zero_int), .parity(parity_int));

control_unit CU(.clk(clk), .reset(reset), .opcode(opcode), .zero(zero_int), .jmp(jmp),
                .reg_wt(reg_wt), .mem_rd(mem_rd), .mem_wt(mem_wt),
                .pc_en(pc_en), .wb_sel(wb_sel), .state_out(cu_state));

endmodule


// =======================================================
// SIMPLE, PROVEN CLOCK GATE (BUFGCE-based)
// =======================================================
module clock_gate(
    input  clk,
    input  enable,
    output gclk
);
    BUFGCE buf_gate (
        .I(clk),
        .CE(enable),
        .O(gclk)
    );
endmodule


// =======================================================
// GATING CONTROLLER (drives register-file enable only)
// =======================================================
module gating_controller(
    input wire [2:0] state,
    input wire [3:0] opcode,
    input wire reg_wt,
    output reg mem_en,
    output reg reg_en
);
    parameter s0=3'b000, s1=3'b001, s2=3'b010, s3=3'b011, s4=3'b100;
    parameter LOAD=4'b1001, STORE=4'b1010;

    always @(*) begin
        mem_en = 1'b0;
        reg_en = 1'b0;

        case (state)
            s3: begin
                if (opcode == LOAD || opcode == STORE)
                    mem_en = 1'b1;
            end
            s4: reg_en = reg_wt;
            default: begin
                mem_en = 1'b0;
                reg_en = 1'b0;
            end
        endcase
    end
endmodule


// =======================================================
// CONTROL UNIT
// =======================================================
module control_unit(input clk, reset, input [3:0] opcode, input zero,
    output reg jmp, reg_wt, mem_rd, mem_wt,
    output reg pc_en,
    output reg [1:0] wb_sel,
    output [2:0] state_out);

reg [2:0] state;
parameter s0=3'b000, s1=3'b001, s2=3'b010, s3=3'b011, s4=3'b100;
parameter LOAD=4'b1001, STORE=4'b1010, JUMP=4'b1011, BEQ = 4'b1100, BNE = 4'b1101;

assign state_out = state;

always @(posedge clk or posedge reset)
    if(reset) state <= s0;
    else case(state)
        s0: state <= s1;
        s1: begin
            if (opcode == JUMP) state <= s0;
            else if (opcode == LOAD || opcode == STORE) state <= s3;
            else if (opcode == BEQ) begin
                if (zero) state <= s0;
                else state <= s2;
            end
            else if (opcode == BNE) begin
                if (!zero) state <= s0;
                else state <= s2;
            end
            else state <= s2;
        end
        s2: state <= s4;
        s3: state <= s4;
        s4: state <= s0;
        default: state <= s0;
    endcase

always @(*) begin
    mem_rd = 0; mem_wt = 0; reg_wt = 0; jmp = 0;
    pc_en = 0; wb_sel = 2'b00;
    case(state)
        s1: begin
            if(opcode == JUMP) jmp = 1;
            else if(opcode == BEQ && zero) jmp = 1;
            else if(opcode == BNE && !zero) jmp = 1;
        end
        s2: begin wb_sel = 2'b10; end
        s3: begin
            if(opcode == LOAD) begin mem_rd = 1; wb_sel = 2'b01; end
            else if(opcode == STORE) begin mem_wt = 1; end
        end
        s4: begin
            pc_en = 1;
            if(opcode == LOAD) begin wb_sel = 2'b01; reg_wt = 1; end
            else if(opcode == STORE) begin end
            else if(opcode == JUMP) begin end
            else if(opcode == BEQ || opcode == BNE) begin end
            else begin wb_sel = 2'b10; reg_wt = 1; end
        end
        default: begin
            mem_rd = 0; mem_wt = 0; reg_wt = 0; jmp = 0;
            pc_en = 0; wb_sel = 2'b00;
        end
    endcase
end
endmodule


// =======================================================
// PROGRAM COUNTER (guarded against latching an unknown address)
// =======================================================
module program_counter(input clk, reset, pc_en, jmp,
    input [15:0] jmp_address, output reg [15:0] address);
always @(posedge clk or posedge reset)
    if(reset) address <= 16'd0;
    else if(jmp && !(^jmp_address === 1'bx)) address <= jmp_address;
    else if(pc_en) address <= address + 16'd1;
endmodule


// =======================================================
// INSTRUCTION MEMORY
// =======================================================
module instruction_memory(input [15:0] address, output [23:0] instruction);
reg [23:0] inst_mem [63:0];
integer i;
initial begin
    for(i=0; i<64; i=i+1) inst_mem[i] = 24'h000000;
    $readmemh("program.mem", inst_mem);
end
assign instruction = inst_mem[address[5:0]];
endmodule


// =======================================================
// INSTRUCTION REGISTER (ungated - clocks every cycle)
// =======================================================
module instruction_register(input [23:0] instruction, input clk, reset,
    output reg [3:0] opcode, rz, rx, ry, output reg [15:0] immediate);
always @(posedge clk or posedge reset)
    if(reset) begin
        opcode <= 4'd0; rz <= 4'd0; rx <= 4'd0; ry <= 4'd0; immediate <= 16'd0;
    end
    else begin
        opcode <= instruction[23:20];
        rz <= instruction[19:16];
        rx <= instruction[15:12];
        ry <= instruction[11:8];
        immediate <= {8'b0, instruction[7:0]};
    end
endmodule


// =======================================================
// DATA MEMORY
// =======================================================
module data_memory(
    input [15:0] address,
    input clk,
    input mem_rd,
    input mem_wt,
    input [15:0] write_data,
    output reg [15:0] data
);

reg [15:0] mem [127:0];
integer i;

initial begin
    for(i=0; i<128; i=i+1) mem[i] = 16'd0;
    mem[0] = 16'd5;
    mem[1] = 16'd10;
    mem[2] = 16'd15;
end

wire [6:0] raw_addr = address[6:0];
wire [6:0] clean_addr = ((mem_rd || mem_wt) && (raw_addr !== 7'bx) && (raw_addr !== 7'bz)) ? raw_addr : 7'd0;

always @(posedge clk) begin
    if (mem_rd === 1'b1)
        data <= mem[clean_addr];
    if (mem_wt === 1'b1)
        mem[clean_addr] <= write_data;
end

endmodule

// =======================================================
// WRITE-BACK MUX
// =======================================================
module Write_data(input [15:0] immediate, data, ALU_op, input [1:0] sel,
    output reg [15:0] out_data);
always @(*) begin
    out_data = 16'd0;
    case(sel)
        2'b00: out_data = immediate;
        2'b01: out_data = data;
        2'b10: out_data = ALU_op;
        default: out_data = 16'd0;
    endcase
end
endmodule


// =======================================================
// REGISTER FILE
// =======================================================
module registers(input [3:0] rz, rx, ry, input [15:0] out_data,
    input reg_wt, clk, output [15:0] rx_value, ry_value);
reg [15:0] reg_array [15:0];
integer i;
initial for(i=0; i<16; i=i+1) reg_array[i] = 16'd0;

always @(posedge clk)
    if(reg_wt === 1'b1) reg_array[rz] <= out_data;

assign rx_value = reg_array[rx];
assign ry_value = reg_array[ry];
endmodule


// =======================================================
// ALU
// =======================================================
module alu(
    input  [15:0] rx_value,
    input  [15:0] ry_value,
    input  [3:0]  opcode,
    output reg [15:0] ALU_op,
    output reg carry,
    output reg zero,
    output reg parity
);
always @(*) begin
    ALU_op = 16'h0000;
    carry  = 1'b0;
    zero   = 1'b0;
    parity = 1'b0;

    case (opcode)
        4'b0000: {carry, ALU_op} = rx_value + ry_value;
        4'b0001: {carry, ALU_op} = rx_value - ry_value;
        4'b0010: ALU_op = rx_value * ry_value;
        4'b0011: ALU_op = rx_value & ry_value;
        4'b0100: ALU_op = rx_value | ry_value;
        4'b0101: ALU_op = rx_value ^ ry_value;
        4'b0110: ALU_op = ~rx_value;
        4'b0111: ALU_op = rx_value << 1;
        4'b1000: ALU_op = rx_value >> 1;
        4'b1100: {carry, ALU_op} = rx_value - ry_value;
        4'b1101: {carry, ALU_op} = rx_value - ry_value;
        default: ALU_op = 16'h0000;
    endcase
    zero   = (ALU_op == 16'd0);
    parity = ~^ALU_op;
end
endmodule
