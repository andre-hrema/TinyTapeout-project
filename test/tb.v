`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb #(
  parameter WORD_SIZE=8
)();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  wire [7:0] uio_oe = 8'b0001_1111;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  reg [1:0] ctl;
  reg[WORD_SIZE-1:0] data_in;

  wire [10:0] data_out;
  wire [1:0] status;
  wire [7:0] uio_out_bus;

  assign status = uio_out_bus[1:0];
  assign data_out[10:WORD_SIZE] = uio_out_bus[4:2];

  // Replace tt_um_example with your module name:
  tt_um_andre_dpe tt_um_andre_dpe (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (data_in),    // Dedicated inputs
      .uo_out (data_out[WORD_SIZE-1:0]),   // Dedicated outputs
      .uio_in ({1'b0, ctl, 5'b0}),   // 0+ctl+debug_ctl+00 -> ctl is 2 bit long, debug_ctl is 4 bit long.
      .uio_out(uio_out_bus),  // 000+upper_bit_output+status -> status is 2 bit wide, upper bits are 3 bit wide.
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
