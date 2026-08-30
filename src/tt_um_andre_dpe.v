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
  assign uio_oe = 8'b0000_0011; // status(out): [1:0], debug_selector(in): [4:2], ctl(in): [5:6]

  fsm fsm(
      // Control signals
      .clk(clk),
      .rst(rst),
      .ena(ena),
      .ctl(uio_in[6:5]), // bits [6:5] = ctl[1:0]
      .debug_selector(uio_in[4:1]), // bits [4:1] = debug_selector[3:0]
      .data_in(ui_in), // [WORD_SIZE-1:0]
      .data_out(uo_out), // [WORD_SIZE-1:0]
      .status(uio_out[1:0]) // [1:0]
  );

endmodule
