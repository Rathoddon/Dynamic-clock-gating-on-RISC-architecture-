`timescale 1ns/1ps

module tb_project_ca();

    reg clk;
    reg reset;
    wire debug_clk;

    // Instantiate Unit Under Test (UUT)
    project_ca UUT (
        .clk(clk),
        .reset(reset),
        .debug_clk(debug_clk)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        #20;
        reset = 0;
        
        // Run simulation for sufficient duration
        #1000;
        $finish;
    end

    // Comprehensive monitoring matching the transcript format
    initial begin
        $monitor("T=%0t | PC=%04h | STATE=%0d | INST=%6h | OPCODE=%h | RZ=%2d RX=%2d RY=%2d | REGA=%04h REGB=%04h | ALU=%4h | ZERO=%b | JMP=%b | mem_data = %6h | write data = %6h | mem_read = %b | register write = %b | write back = %b",
            $time, 
            UUT.pc, 
            UUT.CU.state, 
            UUT.instruction, 
            UUT.opcode, 
            UUT.rz, UUT.rx, UUT.ry, 
            UUT.regA, UUT.regB, 
            UUT.alu_result, 
            UUT.zero_int, 
            UUT.jmp, 
            UUT.mem_data, 
            UUT.write_data, 
            UUT.mem_rd, 
            UUT.reg_wt, 
            UUT.wb_sel
        );
        end 
        always @(posedge clk) begin
    $display("-----------------------------------");
    $display("R0=%d",  UUT.R.reg_array[0]);
    $display("R1=%d",  UUT.R.reg_array[1]);
    $display("R2=%d",  UUT.R.reg_array[2]);
    $display("R3=%d",  UUT.R.reg_array[3]);
    $display("R4=%d",  UUT.R.reg_array[4]);
    $display("R5=%d",  UUT.R.reg_array[5]);
    $display("R6=%d",  UUT.R.reg_array[6]);
    $display("R7=%d",  UUT.R.reg_array[7]);
    $display("R8=%d",  UUT.R.reg_array[8]);
    $display("R9=%d",  UUT.R.reg_array[9]);
    $display("R10=%d", UUT.R.reg_array[10]);
    $display("R11=%d", UUT.R.reg_array[11]);
    $display("R12=%d", UUT.R.reg_array[12]);
    $display("R13=%d", UUT.R.reg_array[13]);
    $display("-----------------------------------");
end
endmodule
