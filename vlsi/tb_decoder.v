`timescale 1ns / 1ps

module tb_decoder;
    reg clk, rst_n;
    reg [1:0] syndrome;
    reg raw_sum_qubit, raw_cout_qubit;
    wire corrected_sum, cout_out, correction_flag;
    wire [1:0] error_location;
    integer errors;

    syndrome_decoder uut (
        .clk(clk), .rst_n(rst_n), .syndrome(syndrome),
        .raw_sum_qubit(raw_sum_qubit), .raw_cout_qubit(raw_cout_qubit),
        .corrected_sum(corrected_sum), .cout_out(cout_out),
        .error_location(error_location), .correction_flag(correction_flag)
    );

    always #5 clk = ~clk;   // 100 MHz

    task run_case(input [1:0] s, input raw_sum, input exp_sum,
                  input [1:0] exp_loc, input exp_flag);
    begin
        syndrome = s; raw_sum_qubit = raw_sum; raw_cout_qubit = 1'b1;
        @(posedge clk); #1;   // outputs are registered: check after one clock edge
        if (corrected_sum !== exp_sum || error_location !== exp_loc ||
            correction_flag !== exp_flag) begin
            $display("FAIL: synd=%b raw=%b -> sum=%b loc=%b flag=%b (expected %b %b %b)",
                     s, raw_sum, corrected_sum, error_location, correction_flag,
                     exp_sum, exp_loc, exp_flag);
            errors = errors + 1;
        end else
            $display("PASS: synd=%b raw=%b -> sum=%b loc=%b flag=%b",
                     s, raw_sum, corrected_sum, error_location, correction_flag);
    end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_decoder);

        clk = 0; rst_n = 0; errors = 0;
        syndrome = 2'b00; raw_sum_qubit = 0; raw_cout_qubit = 0;
        #22 rst_n = 1;

        //       synd   raw  exp_sum  exp_loc  exp_flag
        run_case(2'b00, 1'b0, 1'b0, 2'b00, 1'b0);  // no error
        run_case(2'b00, 1'b1, 1'b1, 2'b00, 1'b0);  // no error, sum=1
        run_case(2'b01, 1'b1, 1'b0, 2'b01, 1'b1);  // qubit 0 flipped -> repaired
        run_case(2'b01, 1'b0, 1'b1, 2'b01, 1'b1);  // qubit 0 flipped -> repaired
        run_case(2'b11, 1'b0, 1'b0, 2'b10, 1'b1);  // ancilla 1 flipped
        run_case(2'b10, 1'b0, 1'b0, 2'b11, 1'b1);  // ancilla 2 flipped

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule