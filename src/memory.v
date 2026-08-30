/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ns

module memory_bank #(
    parameter NUM_MEM_ELEMENTS = 16,
    parameter WORD_SIZE = 8
  )(
    input  wire  clk,      // clock
    input  wire  rst,
    input  wire [1:0] ctl,
    input  wire [WORD_SIZE-1:0] data_in,
    output logic [WORD_SIZE-1:0] memory_content
);

  typedef enum logic [1:0] {
    MEM_IDLE  =  2'b00,
    MEM_STORE =  2'b01,
    MEM_LOAD  =  2'b10,
    MEM_CLEAR =  2'b11
  } mem_ctl_t;

  reg [$clog2(NUM_MEM_ELEMENTS)-1:0] counter;
  // the last element of mem_bank_x is used to store the intermediate values of the dot product
  reg [WORD_SIZE-1:0] mem_bank[NUM_MEM_ELEMENTS-1:0];

  always_ff @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      memory_content <= 0;
    end else begin

      case (ctl)
        MEM_IDLE: begin
          // Do nothing
        end

        MEM_STORE: begin
          mem_bank[counter] <= data_in;

          if (counter == NUM_MEM_ELEMENTS - 1)
            counter <= 0;
          else
            counter <= counter + 1;

        end

        MEM_LOAD: begin    
          if (data_in == 8'hFF) begin
            memory_content <= {{(WORD_SIZE-$clog2(NUM_MEM_ELEMENTS)){1'b0}}, counter};
          end else if (data_in < counter) begin
              memory_content <= mem_bank[data_in];
          end else begin
              memory_content <= 0;
          end
        end

        MEM_CLEAR: begin
          counter <= 0;
          memory_content <= 0;
        end

        default:
        ;

      endcase
    end
  end

endmodule
