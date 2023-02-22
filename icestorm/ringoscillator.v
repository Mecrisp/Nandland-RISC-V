
module ring_osc ( input resetq, output osc_out );

  parameter NUM_LUTS = 42;

  wire [NUM_LUTS:0] buffers_in, buffers_out;
  assign buffers_in = {buffers_out[NUM_LUTS - 1:0], chain_in};
  wire chain_out = buffers_out[NUM_LUTS];
  wire chain_in = resetq ? !chain_out : 0;

  SB_LUT4 #(
      .LUT_INIT(16'd2)
  ) buffers [NUM_LUTS:0] (
      .O(buffers_out),
      .I0(buffers_in),
      .I1(1'b0),
      .I2(1'b0),
      .I3(1'b0)
  );

  assign osc_out = chain_out;

endmodule
