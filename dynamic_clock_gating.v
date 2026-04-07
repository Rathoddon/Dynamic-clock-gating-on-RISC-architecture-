
module project_ca(
    input  wire clk,
    input  wire reset
);

// Control signals
wire decode_en, execute_en, mem_en, pc_en, reg_wt, mem_rd, mem_wt, jmp;
wire carry_int,zero_int,parity_int;
wire [1:0] wb_sel;

// Clock gating 
wire clk_decode, clk_execute, clk_mem, clk_reg, clk_pc;
clock_gate CG1(.clk(clk), .enable(decode_en), .gclk(clk_decode));
clock_gate CG2(.clk(clk), .enable(execute_en), .gclk(clk_execute));
clock_gate CG3(.clk(clk), .enable(mem_en),    .gclk(clk_mem));
clock_gate CG4(.clk(clk), .enable(reg_wt),    .gclk(clk_reg));
clock_gate CG5(.clk(clk), .enable(pc_en),     .gclk(clk_pc));

// Datapath wires
wire [15:0] pc, alu_result, regA, regB, immediate, mem_data, write_data;
wire [23:0] instruction;
wire [3:0] opcode, rz, rx, ry;

// Modules
program_counter PC(.clk(clk_pc), .reset(reset), .pc_en(pc_en), .jmp(jmp),
                   .jmp_address(immediate), .address(pc));

instruction_memory IM(.address(pc), .instruction(instruction));

instruction_register IR(.instruction(instruction), .clk(clk_decode),
                        .reset(reset), .decode_en(decode_en),
                        .opcode(opcode), .rz(rz), .rx(rx), .ry(ry),
                        .immediate(immediate));

data_memory DM(.address(alu_result), .clk(clk_mem), .mem_rd(mem_rd),
               .mem_wt(mem_wt), .mem_en(mem_en), .write_data(regB),
               .data(mem_data));

Write_data WR(.immediate(immediate), .data(mem_data), .ALU_op(alu_result),
              .sel(wb_sel), .out_data(write_data));

registers R(.rz(rz), .rx(rx), .ry(ry), .out_data(write_data),
            .reg_wt(reg_wt), .clk(clk_reg),
            .rx_value(regA), .ry_value(regB));

alu ALU(.rx_value(regA), .ry_value(regB), .opcode(opcode),
        .execute_en(execute_en), .clk(clk_execute),
        .ALU_op(alu_result), .carry(carry_int), .zero(zero_int), .parity(parity_int));

control_unit CU(.clk(clk), .reset(reset), .opcode(opcode), .jmp(jmp),
                .reg_wt(reg_wt), .mem_rd(mem_rd), .mem_wt(mem_wt),
                .pc_en(pc_en), .decode_en(decode_en),
                .execute_en(execute_en), .mem_en(mem_en), .wb_sel(wb_sel));

endmodule

module control_unit(input clk,reset,input [3:0]opcode,
    output reg jmp,reg_wt,mem_rd,mem_wt,
    output reg pc_en,decode_en,execute_en,mem_en,
    output reg [1:0]wb_sel);

reg [2:0]state;
parameter s0=3'b000,s1=3'b001,s2=3'b010,s3=3'b011,s4=3'b100;
parameter LOAD=4'b1001, STORE=4'b1010, JUMP=4'b1011;

always @(posedge clk or posedge reset)
    if(reset) state<=s0;
    else case(state)
        s0: state<=s1;
        s1: if(opcode==JUMP) state<=s0;
            else if(opcode==LOAD||opcode==STORE) state<=s3;
            else state<=s2;
        s2: state<=s4;
        s3: state<=s4;
        s4: state<=s0;
    endcase

always @(*) begin
    mem_rd=0; mem_wt=0; reg_wt=0; jmp=0;
    pc_en=0; decode_en=0; execute_en=0; mem_en=0; wb_sel=2'b00;
    case(state)
        s1: begin decode_en=1; if(opcode==JUMP) jmp=1; end
        s2: begin execute_en=1; wb_sel=2'b10; end
        s3: begin mem_en=1;
              if(opcode==LOAD) begin mem_rd=1; wb_sel=2'b01; end
              else if(opcode==STORE) mem_wt=1;
            end
        s4: begin pc_en=1; if(opcode!=STORE && opcode!=JUMP) reg_wt=1; end
    endcase
end
endmodule

module program_counter(input clk,reset,pc_en,jmp,
    input [15:0]jmp_address, output reg [15:0]address);
always @(posedge clk or posedge reset)
    if(reset) address<=0;
    else if(jmp) address<=jmp_address;
    else if(pc_en) address<=address+1;
endmodule

module instruction_memory(input [15:0]address, output [23:0]instruction);
reg [23:0]inst_mem[63:0];
initial $readmemh("program.mem", inst_mem);
assign instruction=inst_mem[address[5:0]];
endmodule

module instruction_register(input [23:0]instruction,input clk,reset,decode_en,
    output reg [3:0]opcode,rz,rx,ry, output reg [15:0]immediate);
always @(posedge clk or posedge reset)
    if(reset) begin opcode<=0;rz<=0;rx<=0;ry<=0;immediate<=0; end
    else if(decode_en) begin
        opcode<=instruction[23:20];
        rz<=instruction[19:16]; rx<=instruction[15:12]; ry<=instruction[11:8];
        immediate<={8'b0,instruction[7:0]};
    end
endmodule

module data_memory(input [15:0]address,input clk,mem_rd,mem_wt,mem_en,
    input [15:0]write_data, output reg [15:0]data);
reg [15:0]mem[127:0];
always @(posedge clk)
    if(mem_en) begin
        if(mem_rd) data<=mem[address[6:0]];
        else if(mem_wt) mem[address[6:0]]<=write_data;
    end
endmodule

module Write_data(input [15:0]immediate,data,ALU_op,input [1:0]sel,
    output reg [15:0]out_data);
always @(*) case(sel)
    2'b00: out_data=immediate;
    2'b01: out_data=data;
    2'b10: out_data=ALU_op;
    default: out_data=0;
endcase
endmodule

module registers(input [3:0]rz,rx,ry,input [15:0]out_data,
    input reg_wt,clk, output [15:0]rx_value,ry_value);
reg [15:0]reg_array[15:0]; integer i;
initial for(i=0;i<16;i=i+1) reg_array[i]=0;
always @(posedge clk) if(reg_wt) reg_array[rz]<=out_data;
assign rx_value=reg_array[rx]; assign ry_value=reg_array[ry];
endmodule

module alu(
    input  [15:0] rx_value,
    input  [15:0] ry_value,
    input  [3:0]  opcode,
    input         execute_en,
    input         clk,
    output reg [15:0] ALU_op,
    output reg carry,
    output reg zero,
    output reg parity
);

always @(posedge clk) begin
    if (execute_en) begin
        case (opcode)
            4'b0000: {carry, ALU_op} = rx_value + ry_value;   // ADD
            4'b0001: {carry, ALU_op} = rx_value - ry_value;   // SUB
            4'b0010: ALU_op = rx_value * ry_value;            // MUL
            4'b0011: ALU_op = rx_value & ry_value;            // AND
            4'b0100: ALU_op = rx_value | ry_value;            // OR
            4'b0101: ALU_op = rx_value ^ ry_value;            // XOR
            4'b0110: ALU_op = ~rx_value;                      // NOT
            4'b0111: ALU_op = rx_value << 1;                  // SHL
            4'b1000: ALU_op = rx_value >> 1;                  // SHR
            default: ALU_op = 16'h0000;
        endcase

        zero   = (ALU_op == 0);
        parity = ~^ALU_op;   // parity = XOR reduction inverted
    end
end

endmodule

module clock_gate(
    input  clk,
    input  enable,
    output gclk
);

    BUFGCE buf_gate (
        .I(clk),   // input clock
        .CE(enable), // clock enable
        .O(gclk)   // gated clock output
    );

endmodule

