//==============================================================================
// pe_lane - Parameterized Lane Submodule for Processing Element
//
// This module implements all arithmetic operations for a single lane within
// a processing element. Each lane handles its own slice of accumulator,
// input vectors, and matrix data based on parameterization.
//
// Supported operations:
//   - MAC: acc = acc + mul_product (with wrap via truncation)
//   - SHIFT (RND): acc = acc >>> shift_value (arithmetic shift right)
//   - PASS: acc = sign_extend(vector_in)
//   - OUT: output = acc (truncated to output width)
//   - CLR: acc = 0, output = 0
//
// Parameters:
//   INPUT_WIDTH     - Bit width of input operands for this lane
//   ACC_WIDTH       - Bit width of accumulator for this lane
//   OUTPUT_WIDTH    - Bit width of output for this lane
//   VALUE_BITWIDTH  - Bit width of the instruction value field
//
// The module is purely combinational - register updates are handled by
// the top-level processing_element.
//==============================================================================

module pe_lane #(
    parameter INPUT_WIDTH    = 8,     // Lane input width
    parameter ACC_WIDTH      = 16,    // Lane accumulator width
    parameter OUTPUT_WIDTH   = 8,     // Lane output width
    parameter VALUE_BITWIDTH = 5      // Instruction value field width
)(
    // Lane input operands (from vector/matrix slices)
    input  logic signed [INPUT_WIDTH-1:0]   vector_in,
    input  logic signed [INPUT_WIDTH-1:0]   matrix_in,
    
    // Current accumulator value (from top-level register slice)
    input  logic signed [ACC_WIDTH-1:0]     acc_in,
    
    // Current output value (for hold behavior)
    input  logic signed [OUTPUT_WIDTH-1:0]  out_in,
    
    // Shift/round value from instruction
    input  logic [VALUE_BITWIDTH-1:0]       shift_value,
    
    // Pipelined multiply result (from external multiplier stage)
    input  logic signed [ACC_WIDTH-1:0]     mul_result,
    
    // Operation control signals (active-high enables)
    input  logic                            do_mac,
    input  logic                            do_shift,
    input  logic                            do_pass,
    input  logic                            do_out,
    input  logic                            do_clr,
    
    // Lane outputs (next-state values for top-level registers)
    output logic signed [ACC_WIDTH-1:0]     next_acc,
    output logic signed [OUTPUT_WIDTH-1:0]  next_out
);

    // =========================================================================
    // Combinational Logic for Lane Operations
    // =========================================================================
    
    // MAC operation: acc = acc + mul_result (wrap via truncation)
    logic signed [ACC_WIDTH-1:0] mac_result;
    assign mac_result = acc_in + mul_result;
    
    // SHIFT (RND) operation: arithmetic right shift
    logic signed [ACC_WIDTH-1:0] shift_result;
    assign shift_result = acc_in >>> shift_value;
    
    // PASS operation: sign-extend input to accumulator width
    // The signed type handles automatic sign extension
    logic signed [ACC_WIDTH-1:0] pass_result;
    assign pass_result = vector_in;  // Sign extension happens automatically
    
    // OUT operation: truncate accumulator to output width (lower bits)
    logic signed [OUTPUT_WIDTH-1:0] out_result;
    assign out_result = acc_in[OUTPUT_WIDTH-1:0];

    // =========================================================================
    // Next Accumulator Value Selection
    // Priority: CLR > PASS > SHIFT > MAC > HOLD
    // =========================================================================
    always_comb begin
        if (do_clr) begin
            next_acc = '0;
        end else if (do_pass) begin
            next_acc = pass_result;
        end else if (do_shift) begin
            next_acc = shift_result;
        end else if (do_mac) begin
            next_acc = mac_result;
        end else begin
            next_acc = acc_in;  // Hold current value
        end
    end

    // =========================================================================
    // Next Output Value Selection
    // Priority: CLR > OUT > HOLD
    // =========================================================================
    always_comb begin
        if (do_clr) begin
            next_out = '0;
        end else if (do_out) begin
            next_out = out_result;
        end else begin
            next_out = out_in;  // Hold current value
        end
    end

endmodule
