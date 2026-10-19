`timescale 1ns / 1ps

module tb_decoder;
    reg clk;
    reg rst_n;
    reg [1:0] syndrome;
    reg raw_sum_qubit;
    reg raw_cout_qubit;

    wire corrected_sum;
    wire cout_out;
    wire [1:0] error_location;
    wire correction_flag;

    syndrome_decoder uut (
        .clk(clk),
        .rst_n(rst_n),
        .syndrome(syndrome),
        .raw_sum_qubit(raw_sum_qubit),
        .raw_cout_qubit(raw_cout_qubit),
        .corrected_sum(corrected_sum),
        .cout_out(cout_out),
        .error_location(error_location),
        .correction_flag(correction_flag)
    );

    // Clock generator: 100 MHz clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        syndrome = 2'b00;
        raw_sum_qubit = 0;
        raw_cout_qubit = 0;

        #20 rst_n = 1;

        // Test 1: No noise (1 + 1 = Sum 0, Cout 1)
        #10 syndrome = 2'b00; raw_sum_qubit = 0; raw_cout_qubit = 1;
        #10 $display("[TB Case 1: No Error]      RawSum=%b Synd=%b => CorrectedSum=%b Cout=%b Flag=%b", python quantum\circuit_quantum_alu.pypython quantum\circuit_quantum_alu.py
                     raw_sum_qubit, syndrome, corrected_sum, cout_out, correction_flag);

        // Test 2: Bit flip on Qubit 0 (RawSum incorrectly reads 1, syndrome is 01)
        #10 syndrome = 2'b01; raw_sum_qubit = 1; raw_cout_qubit = 1;
        #10 $display("[TB Case 2: Qubit 0 Error] RawSum=%b Synd=%b => CorrectedSum=%b Cout=%b Flag=%b (Loc=%b)", 
                     raw_sum_qubit, syndrome, corrected_sum, cout_out, correction_flag, error_location);

        // Test 3: Bit flip on Ancilla 1 (RawSum is clean 0, syndrome is 11)
        #10 syndrome = 2'b11; raw_sum_qubit = 0; raw_cout_qubit = 1;
        #10 $display("[TB Case 3: Ancilla Error] RawSum=%b Synd=%b => CorrectedSum=%b Cout=%b Flag=%b (Loc=%b)", 
                     raw_sum_qubit, syndrome, corrected_sum, cout_out, correction_flag, error_location);

        #20 $finish;
    end
endmodule