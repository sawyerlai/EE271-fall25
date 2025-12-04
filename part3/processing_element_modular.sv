`include "defines.sv"
`include "pe_lane.sv"

//==============================================================================
// processing_element_modular - Fully Parameterized Modular Processing Element
//
// This is a refactored version of processing_element.sv designed to improve
// synthesis speed through modular lane-based architecture while preserving
// exact cycle-for-cycle timing and functionality.
//
// Architecture:
// - Top-level PE contains only interconnects, instruction pipeline, and 
//   register updates
// - Lane arithmetic (MAC, SHIFT, PASS, OUT, CLR) is handled in pe_lane
//   submodules instantiated via generate-for loops
// - Supports INT8 (4 lanes), INT16 (2 lanes), INT32 (1 lane) modes
// - Fully parameterized for easy extension to arbitrary lane counts/widths
//
// Key Features:
// - Interface is 100% compatible with original processing_element
// - All existing testbenches and top modules work without changes
// - Two-stage MAC pipeline is preserved for timing match
// - All modes and opcodes fully supported
//
// Timing:
// - MAC: 2 cycles (multiply in cycle 1, accumulate in cycle 2)
// - SHIFT/PASS/OUT/CLR: 1 cycle
// - NOP: no effect
//==============================================================================

module processing_element(

    // Clock and Reset Inputs
    input wire clk,
    input wire rst_n,

    // Input Instruction
    input pe_inst_t     pe_inst,
    input logic         pe_inst_valid,

    // Input Operands
    input logic [`PE_INPUT_BITWIDTH-1:0] vector_input,
    input logic [`PE_INPUT_BITWIDTH-1:0] matrix_input,

    // Output Operand
    output logic [`PE_OUTPUT_BITWIDTH-1:0] vector_output

);

    //==========================================================================
    // Lane Configuration Parameters
    //==========================================================================
    // Number of lanes for each mode
    localparam NUM_LANES_8  = 4;  // INT8:  4 lanes of 8-bit
    localparam NUM_LANES_16 = 2;  // INT16: 2 lanes of 16-bit
    localparam NUM_LANES_32 = 1;  // INT32: 1 lane of 32-bit
    
    // Lane input widths (derived from input bitwidth)
    localparam LANE_INPUT_8   = `PE_INPUT_BITWIDTH / NUM_LANES_8;    // 8
    localparam LANE_INPUT_16  = `PE_INPUT_BITWIDTH / NUM_LANES_16;   // 16
    localparam LANE_INPUT_32  = `PE_INPUT_BITWIDTH / NUM_LANES_32;   // 32
    
    // Lane accumulator widths (derived from accumulation bitwidth)
    localparam LANE_ACC_8     = `PE_ACCUMULATION_BITWIDTH / NUM_LANES_8;   // 16
    localparam LANE_ACC_16    = `PE_ACCUMULATION_BITWIDTH / NUM_LANES_16;  // 32
    localparam LANE_ACC_32    = `PE_ACCUMULATION_BITWIDTH / NUM_LANES_32;  // 64
    
    // Lane output widths (derived from output bitwidth)
    localparam LANE_OUT_8     = `PE_OUTPUT_BITWIDTH / NUM_LANES_8;   // 8
    localparam LANE_OUT_16    = `PE_OUTPUT_BITWIDTH / NUM_LANES_16;  // 16
    localparam LANE_OUT_32    = `PE_OUTPUT_BITWIDTH / NUM_LANES_32;  // 32

    //==========================================================================
    // Registers - State
    //==========================================================================
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] acc_value, next_acc_value;
    logic signed [`PE_OUTPUT_BITWIDTH-1:0] output_value, next_output_value;
    
    // Instruction pipeline register (stage 1)
    pe_inst_t pe_inst_ff;
    logic pe_inst_valid_ff;
    
    // MAC pipeline registers (stage 2)
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_ff;
    logic signed [LANE_ACC_16-1:0] mul_result_ff16 [NUM_LANES_16-1:0];
    logic signed [LANE_ACC_8-1:0]  mul_result_ff8  [NUM_LANES_8-1:0];
    
    logic mac_stage2_valid;
    logic [`PE_MODE_BITWIDTH-1:0] mode_stage2;

    //==========================================================================
    // Hardware Reuse: 4 x 16-bit Multipliers
    // Used for INT32 decomposition (Booth-style) and INT16/INT8 lanes
    //==========================================================================
    logic signed [16:0] mul_a [3:0];
    logic signed [16:0] mul_b [3:0];
    logic signed [33:0] mul_out [3:0];
    
    assign mul_out[0] = mul_a[0] * mul_b[0];
    assign mul_out[1] = mul_a[1] * mul_b[1];
    assign mul_out[2] = mul_a[2] * mul_b[2];
    assign mul_out[3] = mul_a[3] * mul_b[3];

    //==========================================================================
    // Stage 1: Instruction Decode and Multiply Products
    //==========================================================================
    logic [`PE_OPCODE_BITWIDTH-1:0] opcode_s1;
    logic [`PE_MODE_BITWIDTH-1:0] mode_s1;
    logic [`PE_VALUE_BITWIDTH-1:0] value_s1;
    
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_comb;
    logic signed [LANE_ACC_16-1:0] mul_result_comb16 [NUM_LANES_16-1:0];
    logic signed [LANE_ACC_8-1:0]  mul_result_comb8  [NUM_LANES_8-1:0];
    logic is_mac_op;
    
    // INT32 decomposition signals
    logic signed [15:0] a_hi, b_hi;
    logic [15:0] a_lo, b_lo;
    logic signed [33:0] pp_hh, pp_hl, pp_lh, pp_ll;

    always_comb begin
        integer i;
        
        // Decode registered instruction
        opcode_s1 = pe_inst_ff.opcode;
        mode_s1 = pe_inst_ff.mode;
        value_s1 = pe_inst_ff.value;
        
        // Default multiplier inputs
        for (i = 0; i < 4; i++) begin
            mul_a[i] = '0;
            mul_b[i] = '0;
        end
        
        // Default multiply result outputs
        mul_result_comb = '0;
        for (i = 0; i < NUM_LANES_16; i++) mul_result_comb16[i] = '0;
        for (i = 0; i < NUM_LANES_8; i++) mul_result_comb8[i] = '0;
        is_mac_op = 1'b0;
        
        // INT32 decomposition signals
        a_hi = '0; a_lo = '0;
        b_hi = '0; b_lo = '0;
        pp_hh = '0; pp_hl = '0; pp_lh = '0; pp_ll = '0;

        if (pe_inst_valid_ff) begin
            if (opcode_s1 != `PE_RND_OPCODE && value_s1 == `PE_MAC_VALUE) begin
                is_mac_op = 1'b1;
                
                case (mode_s1)
                    2'd0: begin // INT8 - 4 lanes
                        for (i = 0; i < NUM_LANES_8; i++) begin
                            // Sign extend 8-bit to 17-bit for multiplier
                            mul_a[i] = {{9{vector_input[i*LANE_INPUT_8+7]}}, vector_input[i*LANE_INPUT_8 +: LANE_INPUT_8]};
                            mul_b[i] = {{9{matrix_input[i*LANE_INPUT_8+7]}}, matrix_input[i*LANE_INPUT_8 +: LANE_INPUT_8]};
                            // Extract result bits for lane accumulator width
                            mul_result_comb8[i] = mul_out[i][LANE_ACC_8-1:0];
                        end
                    end
                    
                    2'd1: begin // INT16 - 2 lanes
                        for (i = 0; i < NUM_LANES_16; i++) begin
                            // Sign extend 16-bit to 17-bit for multiplier
                            mul_a[i] = {vector_input[i*LANE_INPUT_16+15], vector_input[i*LANE_INPUT_16 +: LANE_INPUT_16]};
                            mul_b[i] = {matrix_input[i*LANE_INPUT_16+15], matrix_input[i*LANE_INPUT_16 +: LANE_INPUT_16]};
                            // Extract result bits for lane accumulator width
                            mul_result_comb16[i] = mul_out[i][LANE_ACC_16-1:0];
                        end
                    end
                    
                    default: begin // INT32 - 1 lane using 4 partial products
                        // Split 32-bit operands into high/low 16-bit parts
                        a_hi = vector_input[31:16];  // signed
                        a_lo = vector_input[15:0];   // unsigned
                        b_hi = matrix_input[31:16];  // signed
                        b_lo = matrix_input[15:0];   // unsigned
                        
                        // Configure multipliers for partial products
                        // mul[0]: A_hi × B_hi (signed × signed)
                        mul_a[0] = {a_hi[15], a_hi};
                        mul_b[0] = {b_hi[15], b_hi};
                        
                        // mul[1]: A_hi × B_lo (signed × unsigned)
                        mul_a[1] = {a_hi[15], a_hi};
                        mul_b[1] = {1'b0, b_lo};
                        
                        // mul[2]: A_lo × B_hi (unsigned × signed)
                        mul_a[2] = {1'b0, a_lo};
                        mul_b[2] = {b_hi[15], b_hi};
                        
                        // mul[3]: A_lo × B_lo (unsigned × unsigned)
                        mul_a[3] = {1'b0, a_lo};
                        mul_b[3] = {1'b0, b_lo};
                        
                        // Get partial products
                        pp_hh = mul_out[0];
                        pp_hl = mul_out[1];
                        pp_lh = mul_out[2];
                        pp_ll = mul_out[3];
                        
                        // Combine: Result = pp_hh×2^32 + (pp_hl + pp_lh)×2^16 + pp_ll
                        mul_result_comb = (pp_hh << 32) + (pp_hl << 16) + (pp_lh << 16) + pp_ll;
                    end
                endcase
            end
        end
    end

    //==========================================================================
    // Lane Operation Control Signals
    //==========================================================================
    // INT8 lanes control
    logic lane8_do_mac   [NUM_LANES_8-1:0];
    logic lane8_do_shift [NUM_LANES_8-1:0];
    logic lane8_do_pass  [NUM_LANES_8-1:0];
    logic lane8_do_out   [NUM_LANES_8-1:0];
    logic lane8_do_clr   [NUM_LANES_8-1:0];
    
    // INT16 lanes control
    logic lane16_do_mac   [NUM_LANES_16-1:0];
    logic lane16_do_shift [NUM_LANES_16-1:0];
    logic lane16_do_pass  [NUM_LANES_16-1:0];
    logic lane16_do_out   [NUM_LANES_16-1:0];
    logic lane16_do_clr   [NUM_LANES_16-1:0];
    
    // INT32 lane control
    logic lane32_do_mac   [NUM_LANES_32-1:0];
    logic lane32_do_shift [NUM_LANES_32-1:0];
    logic lane32_do_pass  [NUM_LANES_32-1:0];
    logic lane32_do_out   [NUM_LANES_32-1:0];
    logic lane32_do_clr   [NUM_LANES_32-1:0];

    //==========================================================================
    // Lane Outputs
    //==========================================================================
    // INT8 lane outputs
    logic signed [LANE_ACC_8-1:0]  lane8_next_acc [NUM_LANES_8-1:0];
    logic signed [LANE_OUT_8-1:0]  lane8_next_out [NUM_LANES_8-1:0];
    
    // INT16 lane outputs
    logic signed [LANE_ACC_16-1:0] lane16_next_acc [NUM_LANES_16-1:0];
    logic signed [LANE_OUT_16-1:0] lane16_next_out [NUM_LANES_16-1:0];
    
    // INT32 lane outputs
    logic signed [LANE_ACC_32-1:0] lane32_next_acc [NUM_LANES_32-1:0];
    logic signed [LANE_OUT_32-1:0] lane32_next_out [NUM_LANES_32-1:0];

    //==========================================================================
    // Generate INT8 Lanes (4 lanes)
    //==========================================================================
    genvar g8;
    generate
        for (g8 = 0; g8 < NUM_LANES_8; g8++) begin : gen_lane8
            pe_lane #(
                .INPUT_WIDTH    (LANE_INPUT_8),
                .ACC_WIDTH      (LANE_ACC_8),
                .OUTPUT_WIDTH   (LANE_OUT_8),
                .VALUE_BITWIDTH (`PE_VALUE_BITWIDTH)
            ) u_lane8 (
                .vector_in      (vector_input[g8*LANE_INPUT_8 +: LANE_INPUT_8]),
                .matrix_in      (matrix_input[g8*LANE_INPUT_8 +: LANE_INPUT_8]),
                .acc_in         (acc_value[g8*LANE_ACC_8 +: LANE_ACC_8]),
                .out_in         (output_value[g8*LANE_OUT_8 +: LANE_OUT_8]),
                .shift_value    (pe_inst_ff.value),
                .mul_result     (mul_result_ff8[g8]),
                .do_mac         (lane8_do_mac[g8]),
                .do_shift       (lane8_do_shift[g8]),
                .do_pass        (lane8_do_pass[g8]),
                .do_out         (lane8_do_out[g8]),
                .do_clr         (lane8_do_clr[g8]),
                .next_acc       (lane8_next_acc[g8]),
                .next_out       (lane8_next_out[g8])
            );
        end
    endgenerate

    //==========================================================================
    // Generate INT16 Lanes (2 lanes)
    //==========================================================================
    genvar g16;
    generate
        for (g16 = 0; g16 < NUM_LANES_16; g16++) begin : gen_lane16
            pe_lane #(
                .INPUT_WIDTH    (LANE_INPUT_16),
                .ACC_WIDTH      (LANE_ACC_16),
                .OUTPUT_WIDTH   (LANE_OUT_16),
                .VALUE_BITWIDTH (`PE_VALUE_BITWIDTH)
            ) u_lane16 (
                .vector_in      (vector_input[g16*LANE_INPUT_16 +: LANE_INPUT_16]),
                .matrix_in      (matrix_input[g16*LANE_INPUT_16 +: LANE_INPUT_16]),
                .acc_in         (acc_value[g16*LANE_ACC_16 +: LANE_ACC_16]),
                .out_in         (output_value[g16*LANE_OUT_16 +: LANE_OUT_16]),
                .shift_value    (pe_inst_ff.value),
                .mul_result     (mul_result_ff16[g16]),
                .do_mac         (lane16_do_mac[g16]),
                .do_shift       (lane16_do_shift[g16]),
                .do_pass        (lane16_do_pass[g16]),
                .do_out         (lane16_do_out[g16]),
                .do_clr         (lane16_do_clr[g16]),
                .next_acc       (lane16_next_acc[g16]),
                .next_out       (lane16_next_out[g16])
            );
        end
    endgenerate

    //==========================================================================
    // Generate INT32 Lane (1 lane)
    //==========================================================================
    genvar g32;
    generate
        for (g32 = 0; g32 < NUM_LANES_32; g32++) begin : gen_lane32
            pe_lane #(
                .INPUT_WIDTH    (LANE_INPUT_32),
                .ACC_WIDTH      (LANE_ACC_32),
                .OUTPUT_WIDTH   (LANE_OUT_32),
                .VALUE_BITWIDTH (`PE_VALUE_BITWIDTH)
            ) u_lane32 (
                .vector_in      (vector_input[g32*LANE_INPUT_32 +: LANE_INPUT_32]),
                .matrix_in      (matrix_input[g32*LANE_INPUT_32 +: LANE_INPUT_32]),
                .acc_in         (acc_value[g32*LANE_ACC_32 +: LANE_ACC_32]),
                .out_in         (output_value[g32*LANE_OUT_32 +: LANE_OUT_32]),
                .shift_value    (pe_inst_ff.value),
                .mul_result     (mul_result_ff),
                .do_mac         (lane32_do_mac[g32]),
                .do_shift       (lane32_do_shift[g32]),
                .do_pass        (lane32_do_pass[g32]),
                .do_out         (lane32_do_out[g32]),
                .do_clr         (lane32_do_clr[g32]),
                .next_acc       (lane32_next_acc[g32]),
                .next_out       (lane32_next_out[g32])
            );
        end
    endgenerate

    //==========================================================================
    // Stage 2: Decode Instruction and Generate Lane Control Signals
    //==========================================================================
    always_comb begin
        integer i;
        
        // Default: disable all lane operations
        for (i = 0; i < NUM_LANES_8; i++) begin
            lane8_do_mac[i]   = 1'b0;
            lane8_do_shift[i] = 1'b0;
            lane8_do_pass[i]  = 1'b0;
            lane8_do_out[i]   = 1'b0;
            lane8_do_clr[i]   = 1'b0;
        end
        
        for (i = 0; i < NUM_LANES_16; i++) begin
            lane16_do_mac[i]   = 1'b0;
            lane16_do_shift[i] = 1'b0;
            lane16_do_pass[i]  = 1'b0;
            lane16_do_out[i]   = 1'b0;
            lane16_do_clr[i]   = 1'b0;
        end
        
        for (i = 0; i < NUM_LANES_32; i++) begin
            lane32_do_mac[i]   = 1'b0;
            lane32_do_shift[i] = 1'b0;
            lane32_do_pass[i]  = 1'b0;
            lane32_do_out[i]   = 1'b0;
            lane32_do_clr[i]   = 1'b0;
        end
        
        // =====================================================================
        // MAC Stage 2: Use pipelined multiply results from previous cycle
        // =====================================================================
        if (mac_stage2_valid) begin
            case (mode_stage2)
                2'd0: begin // INT8
                    for (i = 0; i < NUM_LANES_8; i++) begin
                        lane8_do_mac[i] = 1'b1;
                    end
                end
                2'd1: begin // INT16
                    for (i = 0; i < NUM_LANES_16; i++) begin
                        lane16_do_mac[i] = 1'b1;
                    end
                end
                default: begin // INT32
                    for (i = 0; i < NUM_LANES_32; i++) begin
                        lane32_do_mac[i] = 1'b1;
                    end
                end
            endcase
        end
        
        // =====================================================================
        // Current Instruction Decode for Non-MAC Operations
        // These take priority over MAC (handled by lane priority logic)
        // =====================================================================
        if (pe_inst_valid_ff) begin
            case (pe_inst_ff.opcode)
                `PE_RND_OPCODE: begin
                    // SHIFT/RND operation - mode selects lane configuration
                    case (pe_inst_ff.mode)
                        2'd0: begin // INT8
                            for (i = 0; i < NUM_LANES_8; i++) begin
                                lane8_do_shift[i] = 1'b1;
                            end
                        end
                        2'd1: begin // INT16
                            for (i = 0; i < NUM_LANES_16; i++) begin
                                lane16_do_shift[i] = 1'b1;
                            end
                        end
                        default: begin // INT32
                            for (i = 0; i < NUM_LANES_32; i++) begin
                                lane32_do_shift[i] = 1'b1;
                            end
                        end
                    endcase
                end
                
                default: begin
                    case (pe_inst_ff.value)
                        `PE_MAC_VALUE: begin
                            // MAC is handled via pipeline (mac_stage2_valid)
                            // No action here for current cycle
                        end
                        
                        `PE_OUT_VALUE: begin
                            // OUT operation - mode selects lane configuration
                            case (pe_inst_ff.mode)
                                2'd0: begin // INT8
                                    for (i = 0; i < NUM_LANES_8; i++) begin
                                        lane8_do_out[i] = 1'b1;
                                    end
                                end
                                2'd1: begin // INT16
                                    for (i = 0; i < NUM_LANES_16; i++) begin
                                        lane16_do_out[i] = 1'b1;
                                    end
                                end
                                default: begin // INT32
                                    for (i = 0; i < NUM_LANES_32; i++) begin
                                        lane32_do_out[i] = 1'b1;
                                    end
                                end
                            endcase
                        end
                        
                        `PE_PASS_VALUE: begin
                            // PASS operation - mode selects lane configuration
                            case (pe_inst_ff.mode)
                                2'd0: begin // INT8
                                    for (i = 0; i < NUM_LANES_8; i++) begin
                                        lane8_do_pass[i] = 1'b1;
                                    end
                                end
                                2'd1: begin // INT16
                                    for (i = 0; i < NUM_LANES_16; i++) begin
                                        lane16_do_pass[i] = 1'b1;
                                    end
                                end
                                default: begin // INT32
                                    for (i = 0; i < NUM_LANES_32; i++) begin
                                        lane32_do_pass[i] = 1'b1;
                                    end
                                end
                            endcase
                        end
                        
                        `PE_CLR_VALUE: begin
                            // CLR operation - clears ALL lanes regardless of mode
                            for (i = 0; i < NUM_LANES_8; i++) begin
                                lane8_do_clr[i] = 1'b1;
                            end
                            for (i = 0; i < NUM_LANES_16; i++) begin
                                lane16_do_clr[i] = 1'b1;
                            end
                            for (i = 0; i < NUM_LANES_32; i++) begin
                                lane32_do_clr[i] = 1'b1;
                            end
                        end
                        
                        default: begin
                            // NOP - no operation
                        end
                    endcase
                end
            endcase
        end
    end

    //==========================================================================
    // Stage 2: Accumulator and Output Value Update Logic
    // Combines lane outputs into full accumulator/output values
    //==========================================================================
    always_comb begin
        integer i;
        
        // Default: hold current values
        next_acc_value = acc_value;
        next_output_value = output_value;
        vector_output = output_value;
        
        // =====================================================================
        // MAC from Stage 2 pipeline - handled first
        // =====================================================================
        if (mac_stage2_valid) begin
            case (mode_stage2)
                2'd0: begin // INT8
                    for (i = 0; i < NUM_LANES_8; i++) begin
                        next_acc_value[i*LANE_ACC_8 +: LANE_ACC_8] = lane8_next_acc[i];
                    end
                end
                2'd1: begin // INT16
                    for (i = 0; i < NUM_LANES_16; i++) begin
                        next_acc_value[i*LANE_ACC_16 +: LANE_ACC_16] = lane16_next_acc[i];
                    end
                end
                default: begin // INT32
                    for (i = 0; i < NUM_LANES_32; i++) begin
                        next_acc_value[i*LANE_ACC_32 +: LANE_ACC_32] = lane32_next_acc[i];
                    end
                end
            endcase
        end
        
        // =====================================================================
        // Current instruction operations - can override MAC result
        // Priority: RND > PASS > CLR (handled by if-else chain)
        // =====================================================================
        if (pe_inst_valid_ff) begin
            case (pe_inst_ff.opcode)
                `PE_RND_OPCODE: begin
                    // SHIFT/RND operation
                    case (pe_inst_ff.mode)
                        2'd0: begin
                            for (i = 0; i < NUM_LANES_8; i++) begin
                                next_acc_value[i*LANE_ACC_8 +: LANE_ACC_8] = lane8_next_acc[i];
                            end
                        end
                        2'd1: begin
                            for (i = 0; i < NUM_LANES_16; i++) begin
                                next_acc_value[i*LANE_ACC_16 +: LANE_ACC_16] = lane16_next_acc[i];
                            end
                        end
                        default: begin
                            for (i = 0; i < NUM_LANES_32; i++) begin
                                next_acc_value[i*LANE_ACC_32 +: LANE_ACC_32] = lane32_next_acc[i];
                            end
                        end
                    endcase
                end
                
                default: begin
                    case (pe_inst_ff.value)
                        `PE_MAC_VALUE: begin
                            // MAC result already handled above
                        end
                        
                        `PE_OUT_VALUE: begin
                            // OUT operation
                            case (pe_inst_ff.mode)
                                2'd0: begin
                                    for (i = 0; i < NUM_LANES_8; i++) begin
                                        next_output_value[i*LANE_OUT_8 +: LANE_OUT_8] = lane8_next_out[i];
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < NUM_LANES_16; i++) begin
                                        next_output_value[i*LANE_OUT_16 +: LANE_OUT_16] = lane16_next_out[i];
                                    end
                                end
                                default: begin
                                    for (i = 0; i < NUM_LANES_32; i++) begin
                                        next_output_value[i*LANE_OUT_32 +: LANE_OUT_32] = lane32_next_out[i];
                                    end
                                end
                            endcase
                        end
                        
                        `PE_PASS_VALUE: begin
                            // PASS operation
                            case (pe_inst_ff.mode)
                                2'd0: begin
                                    for (i = 0; i < NUM_LANES_8; i++) begin
                                        next_acc_value[i*LANE_ACC_8 +: LANE_ACC_8] = lane8_next_acc[i];
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < NUM_LANES_16; i++) begin
                                        next_acc_value[i*LANE_ACC_16 +: LANE_ACC_16] = lane16_next_acc[i];
                                    end
                                end
                                default: begin
                                    for (i = 0; i < NUM_LANES_32; i++) begin
                                        next_acc_value[i*LANE_ACC_32 +: LANE_ACC_32] = lane32_next_acc[i];
                                    end
                                end
                            endcase
                        end
                        
                        `PE_CLR_VALUE: begin
                            // CLR operation - clear everything
                            next_acc_value = '0;
                            next_output_value = '0;
                        end
                        
                        default: begin
                            // NOP - no change
                        end
                    endcase
                end
            endcase
        end
    end

    //==========================================================================
    // Sequential Logic - Pipeline Registers
    //==========================================================================
    always_ff @(posedge clk, negedge rst_n) begin
        integer i;
        if (!rst_n) begin
            // Reset all state
            acc_value <= '0;
            output_value <= '0;
            pe_inst_ff <= '0;
            pe_inst_valid_ff <= '0;
            
            // Reset MAC pipeline
            mac_stage2_valid <= '0;
            mode_stage2 <= '0;
            mul_result_ff <= '0;
            for (i = 0; i < NUM_LANES_16; i++) mul_result_ff16[i] <= '0;
            for (i = 0; i < NUM_LANES_8; i++) mul_result_ff8[i] <= '0;
        end else begin
            // Update instruction pipeline
            pe_inst_ff <= pe_inst;
            pe_inst_valid_ff <= pe_inst_valid;
            
            // Update MAC pipeline
            mac_stage2_valid <= is_mac_op;
            mode_stage2 <= mode_s1;
            mul_result_ff <= mul_result_comb;
            for (i = 0; i < NUM_LANES_16; i++) mul_result_ff16[i] <= mul_result_comb16[i];
            for (i = 0; i < NUM_LANES_8; i++) mul_result_ff8[i] <= mul_result_comb8[i];
            
            // Update state registers
            acc_value <= next_acc_value;
            output_value <= next_output_value;
        end
    end

endmodule
