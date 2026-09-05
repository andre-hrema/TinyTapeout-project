/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_andre_dpe (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire rst = !rst_n;
  assign uio_oe = 8'b0001_1111; // result upper bits and status are outputs
  assign uio_out[7:5] = 3'b000; // unused I/O bits must have a driver

  wire [10:0] fsm_data_out;
  assign uo_out = fsm_data_out[7:0];
  assign uio_out[4:2] = fsm_data_out[10:8];

  fsm fsm(
      // Control signals
      .clk(clk),
      .rst(rst),
      .ena(ena),
      .ctl(uio_in[6:5]), // bits [6:5] = ctl[1:0]
      .data_in(ui_in), // [WORD_SIZE-1:0]
      .data_out(fsm_data_out), // result[7:0] on uo_out, result[10:8] on uio_out[4:2]
      .status(uio_out[1:0]) // [1:0]
  );

endmodule
