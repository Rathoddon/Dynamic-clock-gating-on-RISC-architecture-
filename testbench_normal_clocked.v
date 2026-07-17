`timescale 1ns/1ps

module tb_project_ca1;

    reg clk;
    reg reset;
    wire debug_clk;

    // Instantiate DUT
    project_ca DUT (
        .clk(clk),
        .reset(reset),
        .debug_clk(debug_clk)
    );

    // Clock generation: 10ns period = 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset sequence
    initial begin
        reset = 1;
        #20 reset = 0;
    end
    initial begin
    DUT.R.reg_array[0] = 16'd1;
    DUT.R.reg_array[1] = 16'd2;
    DUT.R.reg_array[2] = 16'd5;
    DUT.R.reg_array[3] = 16'd10;
    DUT.R.reg_array[4] = 16'd0;
    DUT.R.reg_array[5] = 16'd0;
end


initial begin
  $monitor(
        "T=%0t | PC=%h | STATE=%d | INST=%h | OPCODE=%h | RZ=%d RX=%d RY=%d | REGA=%h REGB=%h | ALU=%h | ZERO=%b | JMP=%b | mem_data = %d | write data = %d | mem_read = %d | register write = %d | write back = %d",
    $time,
    DUT.pc,
    DUT.CU.state,
    DUT.instruction,
    DUT.opcode,
    DUT.rz,
    DUT.rx,
    DUT.ry,
    DUT.regA,
    DUT.regB,
    DUT.alu_result,
    DUT.zero_int,
    DUT.jmp,
    DUT.mem_data,
    DUT.write_data,
    DUT.mem_rd,
    DUT.reg_wt,
    DUT.wb_sel
    );
end
always @(posedge clk)
begin
$display("-----------------------------------");
$display("R0=%d",DUT.R.reg_array[0]);
$display("R1=%d",DUT.R.reg_array[1]);
$display("R2=%d",DUT.R.reg_array[2]);
$display("R3=%d",DUT.R.reg_array[3]);
$display("R4=%d",DUT.R.reg_array[4]);
$display("R5=%d",DUT.R.reg_array[5]);
$display("R6=%d",DUT.R.reg_array[6]);
$display("R7=%d",DUT.R.reg_array[7]);
$display("R8=%d",DUT.R.reg_array[8]);
$display("R9=%d",DUT.R.reg_array[9]);
$display("R10=%d",DUT.R.reg_array[10]);
$display("R11=%d",DUT.R.reg_array[11]);
$display("R12=%d",DUT.R.reg_array[12]);
$display("R13=%d",DUT.R.reg_array[13]);
$display("-----------------------------------");
end
    // Simulation control
    initial begin
        // Dump VCD for waveform + power analysis
        $dumpfile("design1.vcd");
        $dumpvars(0, tb_project_ca1);

        // Run simulation for 500 ns
        #500;
        $finish;
    end
endmodule
