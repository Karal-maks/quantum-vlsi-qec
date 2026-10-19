`timescale 1ns / 1ps

module syndrome_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  syndrome,       // Stabilizer syndromes: {S1 (Z1Z2), S0 (Z0Z1)}
    input  wire        raw_sum_qubit,  // Measured physical qubit 0
    input  wire        raw_cout_qubit, // Measured carry-out qubit
    output reg         corrected_sum,  // Error-corrected logical sum
    output reg         cout_out,       // Stable carry-out
    output reg  [1:0]  error_location, // 2'b00: None, 2'b01: Qubit 0, 2'b10: Qubit 1, 2'b11: Qubit 2
    output reg         correction_flag // High when an active error was successfully corrected
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            corrected_sum   <= 1'b0;
            cout_out        <= 1'b0;
            error_location  <= 2'b00;
            correction_flag <= 1'b0;
        end else begin
            cout_out <= raw_cout_qubit;

            case (syndrome)
                2'b00: begin
                    // Stabilizers commute -> No error detected
                    corrected_sum   <= raw_sum_qubit;
                    error_location  <= 2'b00;
                    correction_flag <= 1'b0;
                end

                2'b01: begin
                    // Syndrome 01: S0 tripped, S1 untripped -> Qubit 0 suffered a bit-flip (X) error
                    corrected_sum   <= ~raw_sum_qubit; // Invert corrupted qubit back to ground truth
                    error_location  <= 2'b01;
                    correction_flag <= 1'b1;
                end

                2'b11: begin
                    // Syndrome 11: Both stabilizers tripped -> Qubit 1 (ancilla 1) suffered bit-flip
                    corrected_sum   <= raw_sum_qubit;  // Qubit 0 is uncorrupted
                    error_location  <= 2'b10;
                    correction_flag <= 1'b1;
                end

                2'b10: begin
                    // Syndrome 10: S1 tripped, S0 untripped -> Qubit 2 (ancilla 2) suffered bit-flip
                    corrected_sum   <= raw_sum_qubit;  // Qubit 0 is uncorrupted
                    error_location  <= 2'b11;
                    correction_flag <= 1'b1;
                end

                default: begin
                    corrected_sum   <= raw_sum_qubit;
                    error_location  <= 2'b00;
                    correction_flag <= 1'b0;
                end
            endcase
        end
    end

endmodule