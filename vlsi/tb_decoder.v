`timescale 1ns / 1ps

// Self-checking testbench for syndrome_decoder.
//
// Part 1: exhaustive check of every input combination against a reference
//         model (4 syndromes x raw_sum x raw_cout = 16 cases, all outputs).
// Part 2: asynchronous reset - outputs clear immediately, without a clock edge.
// Part 3: registered outputs - inputs must not reach the outputs before a clock edge.
// Part 4: replay of the 32 results measured in the Qiskit simulation
//         (qiskit_vectors.mem): the decoder must recover the true sum and carry.
//
// Ends with "ALL TESTS PASSED", or calls $fatal (non-zero exit) on any failure.

module tb_decoder;
    reg clk, rst_n;
    reg [1:0] syndrome;
    reg raw_sum_qubit, raw_cout_qubit;
    wire corrected_sum, cout_out, correction_flag;
    wire [1:0] error_location;
    integer errors, checks, i;

    syndrome_decoder uut (
        .clk(clk), .rst_n(rst_n), .syndrome(syndrome),
        .raw_sum_qubit(raw_sum_qubit), .raw_cout_qubit(raw_cout_qubit),
        .corrected_sum(corrected_sum), .cout_out(cout_out),
        .error_location(error_location), .correction_flag(correction_flag)
    );

    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------
    // Reference model of the decoder
    // ------------------------------------------------------------------
    function [4:0] model;  // {sum, cout, loc[1:0], flag}
        input [1:0] s;
        input raw_sum, raw_cout;
        begin
            case (s)
                2'b00: model = {raw_sum,  raw_cout, 2'b00, 1'b0};
                2'b01: model = {~raw_sum, raw_cout, 2'b01, 1'b1};  // qubit 0 flipped
                2'b11: model = {raw_sum,  raw_cout, 2'b10, 1'b1};  // qubit 1 flipped
                2'b10: model = {raw_sum,  raw_cout, 2'b11, 1'b1};  // qubit 2 flipped
            endcase
        end
    endfunction

    task check(input [4:0] expected, input [255:0] label);
    begin
        checks = checks + 1;
        if ({corrected_sum, cout_out, error_location, correction_flag} !== expected) begin
            $display("FAIL [%0s]: synd=%b raw_sum=%b raw_cout=%b -> sum=%b cout=%b loc=%b flag=%b (expected %b)",
                     label, syndrome, raw_sum_qubit, raw_cout_qubit,
                     corrected_sum, cout_out, error_location, correction_flag, expected);
            errors = errors + 1;
        end
    end
    endtask

    task apply(input [1:0] s, input raw_sum, input raw_cout);
    begin
        @(negedge clk);   // change inputs away from the active edge
        syndrome = s; raw_sum_qubit = raw_sum; raw_cout_qubit = raw_cout;
        @(posedge clk); #1;
    end
    endtask

    // Measured Qiskit results: {syndrome[1:0], raw_sum, raw_cout, exp_sum, exp_cout}
    reg [5:0] qvec [0:31];

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_decoder);

        clk = 0; rst_n = 0; errors = 0; checks = 0;
        syndrome = 2'b00; raw_sum_qubit = 0; raw_cout_qubit = 0;
        #22 rst_n = 1;

        // ---- Part 1: exhaustive ------------------------------------------
        for (i = 0; i < 16; i = i + 1) begin
            apply(i[3:2], i[1], i[0]);
            check(model(i[3:2], i[1], i[0]), "exhaustive");
        end
        $display("Part 1: %0d exhaustive cases checked", 16);

        // ---- Part 2: asynchronous reset -----------------------------------
        apply(2'b01, 1'b0, 1'b1);              // drive every output high
        check(5'b11_01_1, "pre-reset");
        @(negedge clk); #2 rst_n = 0; #1;      // between clock edges
        check(5'b00_00_0, "async reset");
        @(posedge clk); #1;
        check(5'b00_00_0, "held in reset");
        @(negedge clk) rst_n = 1;
        $display("Part 2: asynchronous reset checked");

        // ---- Part 3: outputs only change on the clock edge ----------------
        apply(2'b00, 1'b0, 1'b0);
        check(5'b00_00_0, "baseline");
        @(negedge clk);
        syndrome = 2'b01; raw_sum_qubit = 1'b0; raw_cout_qubit = 1'b1;
        #1 check(5'b00_00_0, "no change before edge");
        @(posedge clk); #1 check(model(2'b01, 1'b0, 1'b1), "updated after edge");
        $display("Part 3: registered outputs checked");

        // ---- Part 4: replay Qiskit measurements --------------------------
        $readmemb("qiskit_vectors.mem", qvec);
        for (i = 0; i < 32; i = i + 1) begin
            if (^qvec[i] === 1'bx) begin
                $display("FAIL: qiskit_vectors.mem line %0d missing (run from the vlsi/ folder)", i);
                errors = errors + 1;
            end else begin
                apply(qvec[i][5:4], qvec[i][3], qvec[i][2]);
                checks = checks + 1;
                if (corrected_sum !== qvec[i][1] || cout_out !== qvec[i][0]) begin
                    $display("FAIL [qiskit %0d]: synd=%b raw=%b%b -> sum=%b cout=%b, true sum=%b cout=%b",
                             i, qvec[i][5:4], qvec[i][3], qvec[i][2],
                             corrected_sum, cout_out, qvec[i][1], qvec[i][0]);
                    errors = errors + 1;
                end
            end
        end
        $display("Part 4: %0d Qiskit measurements replayed", 32);

        if (errors == 0) begin
            $display("ALL TESTS PASSED (%0d checks)", checks);
            $finish;
        end else
            $fatal(1, "%0d of %0d checks FAILED", errors, checks);
    end
endmodule
