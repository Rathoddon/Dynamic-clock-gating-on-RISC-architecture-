
module project_ca (
    input  wire clk,
    input  wire reset,
    output wire [15:0] alu_out,
    output wire [15:0] pc_out,
    output wire mem_rd_out,
    output wire mem_wt_out,
    output wire reg_wt_out
);

    wire pc_en, reg_wt, mem_rd, mem_wt, jmp;
    wire [15:0] pc, alu_result, regA, regB, immediate, mem_data, write_data;
    wire [23:0] instruction;
    wire [3:0] opcode, rz, rx, ry;
    wire [1:0] wb_sel;
    wire carry, zero, parity;

    assign alu_out    = alu_result;
    assign pc_out     = pc;
    assign mem_rd_out = mem_rd;
    assign mem_wt_out = mem_wt;
    assign reg_wt_out = reg_wt;

    program_counter PC(.clk(clk), .reset(reset), .pc_en(pc_en), .jmp(jmp),
                       .jmp_address(immediate), .address(pc));

    instruction_memory IM(.address(pc), .instruction(instruction));

    instruction_register IR(.instruction(instruction), .clk(clk), .reset(reset),
                            .opcode(opcode), .rz(rz), .rx(rx), .ry(ry), .immediate(immediate));

    data_memory DM(.clk(clk), .mem_rd(mem_rd), .mem_wt(mem_wt),
                   .address(alu_result), .write_data(regB), .data(mem_data));

    Write_data WR(.immediate(immediate), .data(mem_data), .ALU_op(alu_result),
                  .sel(wb_sel), .out_data(write_data));

    registers R(.clk(clk), .reset(reset), .rz(rz), .rx(rx), .ry(ry),
                .out_data(write_data), .reg_wt(reg_wt),
                .rx_value(regA), .ry_value(regB));

    alu ALU(.rx_value(regA), .ry_value(regB), .opcode(opcode),
            .ALU_op(alu_result), .carry(carry), .zero(zero), .parity(parity));

    control_unit CU(.clk(clk), .reset(reset), .opcode(opcode),
                    .pc_en(pc_en), .jmp(jmp), .reg_wt(reg_wt),
                    .mem_rd(mem_rd), .mem_wt(mem_wt), .wb_sel(wb_sel));

endmodule

module control_unit(input clk,reset,input [3:0]opcode,
    output reg jmp,reg_wt,mem_rd,mem_wt,output reg pc_en,output reg [1:0]wb_sel);

    reg [2:0]state;
    parameter s0=3'b000,s1=3'b001,s2=3'b010,s3=3'b011,s4=3'b100;
    parameter LOAD=4'b1001, STORE=4'b1010, JUMP=4'b1011;

    always @(posedge clk or posedge reset) begin
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
    end

    always @(*) begin
        mem_rd=0; mem_wt=0; reg_wt=0; jmp=0; pc_en=0; wb_sel=2'b00;
        case(state)
            s1: begin if(opcode==JUMP) jmp=1; pc_en=1; end
            s2: wb_sel=2'b10;
            s3: begin if(opcode==LOAD) begin mem_rd=1; wb_sel=2'b01; end
                      else if(opcode==STORE) mem_wt=1; end
            s4: if(opcode!=STORE && opcode!=JUMP) reg_wt=1;
        endcase
    end
endmodule

module program_counter(input clk,reset,pc_en,jmp,input [15:0]jmp_address,output reg [15:0]address);
    always @(posedge clk or posedge reset) begin
        if(reset) address<=16'h0000;
        else if(jmp) address<=jmp_address;
        else if(pc_en) address<=address+1;
    end
endmodule

module instruction_memory(input [15:0]address,output reg [23:0]instruction);
    reg [23:0]inst_mem[0:255];
    initial begin
        $readmemh("program.mem", inst_mem); // preload instructions
    end
    always @(*) instruction = inst_mem[address[7:0]];
endmodule

module instruction_register(input [23:0]instruction,input clk,reset,
    output reg [3:0]opcode,rz,rx,ry,output reg [15:0]immediate);
    always @(posedge clk or posedge reset) begin
        if(reset) begin opcode<=0;rz<=0;rx<=0;ry<=0;immediate<=0; end
        else begin opcode<=instruction[23:20]; rz<=instruction[19:16];
                  rx<=instruction[15:12]; ry<=instruction[11:8];
                  immediate<={8'b0,instruction[7:0]}; end
    end
endmodule

module data_memory(input clk,input mem_rd,input mem_wt,
    input [15:0]address,input [15:0]write_data,output reg [15:0]data);
    reg [15:0]mem[0:511];
    always @(posedge clk) begin
        if(mem_wt) mem[address[8:0]] <= write_data;
        if(mem_rd) data <= mem[address[8:0]];
    end
endmodule

module Write_data(input [15:0]immediate,data,ALU_op,input [1:0]sel,output reg [15:0]out_data);
    always @(*) case(sel)
        2'b00: out_data=immediate;
        2'b01: out_data=data;
        2'b10: out_data=ALU_op;
        default: out_data=16'h0000;
    endcase
endmodule

module registers(input clk,input reset,input reg_wt,
    input [3:0]rz,rx,ry,input [15:0]out_data,
    output [15:0]rx_value,ry_value);
    reg [15:0]reg_array[0:31];
    integer i;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            for(i=0;i<32;i=i+1) reg_array[i] <= 16'h0000;
        end else if(reg_wt) begin
            reg_array[rz] <= out_data;
        end
    end
    assign rx_value=reg_array[rx];
    assign ry_value=reg_array[ry];
endmodule

module alu(input [15:0]rx_value,ry_value,input [3:0]opcode,
    output reg [15:0]ALU_op,output reg carry,zero,parity);
    always @(*) begin
        case(opcode)
            4'b0000: {carry,ALU_op}=rx_value+ry_value;
            4'b0001: {carry,ALU_op}=rx_value-ry_value;
            4'b0010: ALU_op=rx_value*ry_value;
            4'b0011: ALU_op=rx_value & ry_value;
            4'b0100: ALU_op=rx_value | ry_value;
            4'b0101: ALU_op=rx_value ^ ry_value;
            4'b0110: ALU_op=~rx_value;
            4'b0111: ALU_op=rx_value<<1;
            4'b1000: ALU_op=rx_value>>1;
            default: ALU_op=16'h0000;
        endcase
        zero=(ALU_op==16'h0000); parity=~^ALU_op;
    end
endmodule
