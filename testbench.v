`timescale 1ns/1ps

module tb_project_ca;

reg clk;
reg reset;
wire debug_clk;

project_ca DUT (
    .clk(clk),
    .reset(reset),
    .debug_clk(debug_clk)
);

initial begin 
    clk = 0;
    forever #5 clk = ~clk;   // 100 MHz clock
end 

initial begin 
    reset = 1;
    #20;
    reset = 0;
end

// Initialize registers inside DUT
initial begin
    DUT.R.reg_array[0] = 16'd1;
    DUT.R.reg_array[1] = 16'd2;
    DUT.R.reg_array[2] = 16'd5;
    DUT.R.reg_array[3] = 16'd10;
    DUT.R.reg_array[4] = 16'd0;
    DUT.R.reg_array[5] = 16'd0;
end

// Initialize instruction memory
initial begin
    DUT.IM.inst_mem[0] = 24'b0000_0001_0010_0011_0000_0000;
    DUT.IM.inst_mem[1] = 24'b0001_0100_0001_0010_0000_0000;
    DUT.IM.inst_mem[2] = 24'b1001_0101_0000_0000_0000_0100;
    DUT.IM.inst_mem[3] = 24'b1010_0101_0000_0000_0000_0110;
    DUT.IM.inst_mem[4] = 24'b1011_0000_0000_0000_0000_0000;
end

// Dump all signals for waveform viewing
initial begin
    $dumpfile("processor.vcd");
    $dumpvars(0, DUT);   // capture all internals of DUT
end

initial begin
    #500;
    $finish;
end

endmodule
