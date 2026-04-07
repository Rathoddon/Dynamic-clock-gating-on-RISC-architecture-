
module tb_project_ca1;

    reg clk, reset;
    wire [15:0] alu_out, pc_out;
    wire mem_rd_out, mem_wt_out, reg_wt_out;

    project_ca uut (
        .clk(clk),
        .reset(reset),
        .alu_out(alu_out),
        .pc_out(pc_out),
        .mem_rd_out(mem_rd_out),
        .mem_wt_out(mem_wt_out),
        .reg_wt_out(reg_wt_out)
    );
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        clk = 0;
        reset = 1;
        #20 reset = 0;   
        #500 $finish;
    end

  initial begin
    $monitor("T=%0t | PC=%h | ALU=%h | regA=%h | regB=%h",
             $time, pc_out, alu_out, uut.regA, uut.regB);
end

    initial begin
        $dumpfile("design.vcd");
        $dumpvars(0, uut);
    end

endmodule
