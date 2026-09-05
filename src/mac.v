`default_nettype none
`timescale 1ns/1ns

module mac #(
    parameter NUM_ELEMENTS = 6,
    parameter WORD_SIZE = 4,
    parameter RESULT_WIDTH = 2*WORD_SIZE + $clog2(NUM_ELEMENTS)
)(mod_input, input_valid, result, done, clk, rst);

input wire [2*WORD_SIZE-1:0] mod_input;
input wire input_valid;
output reg [RESULT_WIDTH-1:0] result;
output reg done;
input wire clk;
input wire rst;

// aliases para facilitar o dump (GTKWave/VCD não mostra arrays desempacotados corretamente)
wire [WORD_SIZE-1:0] mod_input_0 = mod_input[WORD_SIZE-1:0];
wire [WORD_SIZE-1:0] mod_input_1 = mod_input[2*WORD_SIZE-1:WORD_SIZE];

    reg [2*WORD_SIZE-1:0] mult_result;
    reg [RESULT_WIDTH-1:0] acc_result;

    reg valid_mult;
    reg valid_acc;
    reg operation_active;

    reg prev_pipeline_empty;
    reg prev_input_valid;
    
    wire pipeline_empty;


    always @(posedge clk) begin
        if (rst) begin
            result <= 0;
            done <= 0;

            mult_result <= 0;
            acc_result <= 0;

            valid_mult <= 0;
            valid_acc <= 0;
            operation_active <= 0;

            prev_pipeline_empty <= 1'b0;
            prev_input_valid <= 0;
        end else begin
            if (!prev_input_valid && input_valid) begin
                acc_result <= 0;
                operation_active <= 1'b1;
                result <= 0;
                done <= 0;
            end

            if (input_valid)
                mult_result <= mod_input_0*mod_input_1;

            if (valid_mult)
                acc_result <= {{$clog2(NUM_ELEMENTS){1'b0}}, mult_result} + acc_result;


            // calculation done, attribute the result
            if (operation_active && !prev_pipeline_empty && pipeline_empty) begin
                done <= 1'b1;
                result <= acc_result;
                operation_active <= 1'b0;
            end

            // history registers
            prev_input_valid <= input_valid;
            prev_pipeline_empty <= pipeline_empty;

            // pipeline state registers
            valid_mult <= input_valid;
            valid_acc <= valid_mult;
        end
    end

    assign pipeline_empty = !valid_mult && !valid_acc && !input_valid;

endmodule
