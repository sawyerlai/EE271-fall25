`include "defines.sv"

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

    // START IMPLEMENTATION

    // Accumulator and output
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] acc_value, next_acc_value;
    logic signed [`PE_OUTPUT_BITWIDTH-1:0] output_value, next_output_value;

    // Shift/round variables
    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] shifted;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] lane16, shifted16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] lane8, shifted8;

    // MAC variables for accumulation stage
    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] final_val, wrapped, temp_val;
    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] vacc_lane_val;

    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] final_val16, wrapped16, temp_val16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] vacc_lane_val16;

    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] final_val8, wrapped8, temp_val8;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] vacc_lane_val8;

    logic signed [`PE_ACCUMULATION_BITWIDTH - 1 : 0] lane_ext;
    logic signed [`PE_INPUT_BITWIDTH - 1:0] lane_in;

    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1 : 0] lane_ext16;
    logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] lane_in16;

    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1 : 0] lane_ext8;
    logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] lane_in8;

    // =========================================================================
    // PIPELINE STAGE 1 REGISTERS (Instruction)
    // =========================================================================
    pe_inst_t pe_inst_ff;
    logic pe_inst_valid_ff;

    // =========================================================================
    // PIPELINE STAGE 2 REGISTERS (Multiply results)
    // =========================================================================
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_ff;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2-1:0] mul_result_ff16 [1:0];
    logic signed [`PE_ACCUMULATION_BITWIDTH/4-1:0] mul_result_ff8 [3:0];
    
    logic mac_stage2_valid;
    logic [`PE_MODE_BITWIDTH-1:0] mode_stage2;

    // =========================================================================
    // HARDWARE REUSE: 4 x 16-bit MULTIPLIERS
    // =========================================================================
    // Multiplier inputs (17-bit signed to handle unsigned 16-bit values)
    logic signed [16:0] mul_a [3:0];
    logic signed [16:0] mul_b [3:0];
    // Multiplier outputs (34-bit to hold full product)
    logic signed [33:0] mul_out [3:0];
    
    // Compute all 4 multiplies in parallel
    assign mul_out[0] = mul_a[0] * mul_b[0];
    assign mul_out[1] = mul_a[1] * mul_b[1];
    assign mul_out[2] = mul_a[2] * mul_b[2];
    assign mul_out[3] = mul_a[3] * mul_b[3];

    // =========================================================================
    // STAGE 1: Configure multipliers and compute products
    // =========================================================================
    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_comb;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2-1:0] mul_result_comb16 [1:0];
    logic signed [`PE_ACCUMULATION_BITWIDTH/4-1:0] mul_result_comb8 [3:0];
    logic is_mac_op;
    
    logic [`PE_OPCODE_BITWIDTH-1:0] opcode_s1;
    logic [`PE_MODE_BITWIDTH-1:0] mode_s1;
    logic [`PE_VALUE_BITWIDTH-1:0] value_s1;

    // For INT32 decomposition
    logic signed [15:0] a_hi, b_hi;
    logic [15:0] a_lo, b_lo;
    logic signed [33:0] pp_hh;  // A_hi * B_hi (signed × signed)
    logic signed [33:0] pp_hl;  // A_hi * B_lo (signed × unsigned)
    logic signed [33:0] pp_lh;  // A_lo * B_hi (unsigned × signed)
    logic signed [33:0] pp_ll;  // A_lo * B_lo (unsigned × unsigned)

    always_comb begin
        integer i;
        
        // Decode instruction
        opcode_s1 = pe_inst_ff.opcode;
        mode_s1 = pe_inst_ff.mode;
        value_s1 = pe_inst_ff.value;
        
        // Default multiplier inputs
        for (i = 0; i < 4; i++) begin
            mul_a[i] = '0;
            mul_b[i] = '0;
        end
        
        // Default outputs
        mul_result_comb = '0;
        for (i = 0; i < 2; i++) mul_result_comb16[i] = '0;
        for (i = 0; i < 4; i++) mul_result_comb8[i] = '0;
        is_mac_op = 1'b0;
        
        // INT32 decomposition signals
        a_hi = '0; a_lo = '0;
        b_hi = '0; b_lo = '0;
        pp_hh = '0; pp_hl = '0; pp_lh = '0; pp_ll = '0;

        if (pe_inst_valid_ff) begin
            if (opcode_s1 != `PE_RND_OPCODE && value_s1 == `PE_MAC_VALUE) begin
                is_mac_op = 1'b1;
                
                case (mode_s1)
                    2'd0: begin // INT8 - 4 lanes, sign-extend 8-bit to 17-bit
                        for (i = 0; i < 4; i++) begin
                            // Sign extend 8-bit to 17-bit signed
                            mul_a[i] = {{9{vector_input[i*8+7]}}, vector_input[i*8 +: 8]};
                            mul_b[i] = {{9{matrix_input[i*8+7]}}, matrix_input[i*8 +: 8]};
                            // Result: lower 16 bits of 34-bit product
                            mul_result_comb8[i] = mul_out[i][15:0];
                        end
                    end
                    
                    2'd1: begin // INT16 - 2 lanes, sign-extend 16-bit to 17-bit
                        for (i = 0; i < 2; i++) begin
                            // Sign extend 16-bit to 17-bit signed
                            mul_a[i] = {vector_input[i*16+15], vector_input[i*16 +: 16]};
                            mul_b[i] = {matrix_input[i*16+15], matrix_input[i*16 +: 16]};
                            // Result: lower 32 bits of 34-bit product
                            mul_result_comb16[i] = mul_out[i][31:0];
                        end
                    end
                    
                    default: begin // INT32 - decompose into 4 partial products
                        // Split 32-bit operands into high/low 16-bit parts
                        a_hi = vector_input[31:16];  // signed (includes sign bit)
                        a_lo = vector_input[15:0];   // unsigned
                        b_hi = matrix_input[31:16];  // signed
                        b_lo = matrix_input[15:0];   // unsigned
                        
                        // Configure multipliers for partial products
                        // mul[0]: A_hi × B_hi (signed × signed)
                        mul_a[0] = {a_hi[15], a_hi};  // sign extend to 17-bit
                        mul_b[0] = {b_hi[15], b_hi};
                        
                        // mul[1]: A_hi × B_lo (signed × unsigned)
                        mul_a[1] = {a_hi[15], a_hi};  // sign extend
                        mul_b[1] = {1'b0, b_lo};      // zero extend (unsigned)
                        
                        // mul[2]: A_lo × B_hi (unsigned × signed)
                        mul_a[2] = {1'b0, a_lo};      // zero extend (unsigned)
                        mul_b[2] = {b_hi[15], b_hi};  // sign extend
                        
                        // mul[3]: A_lo × B_lo (unsigned × unsigned)
                        mul_a[3] = {1'b0, a_lo};      // zero extend
                        mul_b[3] = {1'b0, b_lo};      // zero extend
                        
                        // Get partial products
                        pp_hh = mul_out[0];
                        pp_hl = mul_out[1];
                        pp_lh = mul_out[2];
                        pp_ll = mul_out[3];
                        
                        // Combine: Result = pp_hh×2^32 + (pp_hl + pp_lh)×2^16 + pp_ll
                        // For 64-bit accumulator, we need bits [63:0]
                        mul_result_comb = (pp_hh << 32) + (pp_hl << 16) + (pp_lh << 16) + pp_ll;
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // STAGE 2: Accumulate and other operations
    // =========================================================================
    // =========================================================================
    // STAGE 2: OPTIMIZED Logic
    // =========================================================================
    always_comb begin
        integer i;
        // Default assignments to prevent latches
        next_acc_value = acc_value; 
        next_output_value = output_value;
        vector_output = output_value;

        // Use a single priority chain to flatten MUX depth
        if (pe_inst_valid_ff && pe_inst_ff.opcode == `PE_RND_OPCODE) begin
            // --- HANDLE SHIFT/ROUND ---
            case (pe_inst_ff.mode)
                2'd0: begin
                    for (i = 0; i < 4; i++) begin
                        lane8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                        // Direct assignment, logic inside the index
                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = lane8 >>> pe_inst_ff.value;
                    end
                end
                2'd1: begin
                    for (i = 0; i < 2; i++) begin
                        lane16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = lane16 >>> pe_inst_ff.value;
                    end
                end
                default: begin
                     next_acc_value = acc_value >>> pe_inst_ff.value;
                end
            endcase
        end 
        else if (pe_inst_valid_ff && pe_inst_ff.opcode == `PE_CLR_VALUE) begin
            // --- HANDLE CLEAR ---
            next_acc_value = '0;
            next_output_value = '0;
        end
        else if (pe_inst_valid_ff && pe_inst_ff.value == `PE_PASS_VALUE) begin
            // --- HANDLE PASS (LOAD) ---
            case (pe_inst_ff.mode)
                2'd0: for(i=0; i<4; i++) next_acc_value[i*8 +: 8] = vector_input[i*8 +: 8];
                2'd1: for(i=0; i<2; i++) next_acc_value[i*16 +: 16] = vector_input[i*16 +: 16];
                default: next_acc_value = vector_input;
            endcase
        end
        else if (mac_stage2_valid) begin
            // --- HANDLE MAC (The Critical Path) ---
            // Note: Removed the manual bit-masking (&). 
            // Verilog automatically truncates if the LHS width matches the destination.
            case (mode_stage2)
                2'd0: begin // INT8
                    for (i = 0; i < 4; i++) begin
                        next_acc_value[i*`PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = 
                            acc_value[i*`PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] + mul_result_ff8[i];
                    end
                end
                2'd1: begin // INT16
                    for (i = 0; i < 2; i++) begin
                        next_acc_value[i*`PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = 
                            acc_value[i*`PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] + mul_result_ff16[i];
                    end
                end
                default: begin // INT32
                    next_acc_value = acc_value + mul_result_ff;
                end
            endcase
        end
        
        // ... (inside the always_comb block)

        // Handle Output Logic
        if (pe_inst_valid_ff && pe_inst_ff.value == `PE_OUT_VALUE) begin
            case (pe_inst_ff.mode)
                2'd0: begin // INT8
                    for (i = 0; i < 4; i++) begin
                        // Grab 8 bits from accumulator
                        vacc_lane_val8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                        // Assign to output
                        next_output_value[i * `PE_OUTPUT_BITWIDTH/4 +: `PE_OUTPUT_BITWIDTH/4] = vacc_lane_val8;
                    end
                end
                2'd1: begin // INT16
                    for (i = 0; i < 2; i++) begin
                        vacc_lane_val16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                        next_output_value[i * `PE_OUTPUT_BITWIDTH/2 +: `PE_OUTPUT_BITWIDTH/2] = vacc_lane_val16;
                    end
                end
                default: begin // INT32
                     next_output_value = acc_value;
                end
            endcase 
        end
    end

    // =========================================================================
    // Sequential logic - Pipeline registers
    // =========================================================================
    always_ff @(posedge clk, negedge rst_n) begin
        integer i;
        if (!rst_n) begin
            acc_value <= '0; 
            output_value <= '0;
            pe_inst_ff <= '0;
            pe_inst_valid_ff <= '0;
            
            mac_stage2_valid <= '0;
            mode_stage2 <= '0;
            mul_result_ff <= '0;
            for (i = 0; i < 2; i++) mul_result_ff16[i] <= '0;
            for (i = 0; i < 4; i++) mul_result_ff8[i] <= '0;
        end else begin
            pe_inst_ff <= pe_inst;
            pe_inst_valid_ff <= pe_inst_valid;
            
            mac_stage2_valid <= is_mac_op;
            mode_stage2 <= mode_s1;
            mul_result_ff <= mul_result_comb;
            for (i = 0; i < 2; i++) mul_result_ff16[i] <= mul_result_comb16[i];
            for (i = 0; i < 4; i++) mul_result_ff8[i] <= mul_result_comb8[i];
            
            acc_value <= next_acc_value;
            output_value <= next_output_value;
        end
    end
    // END IMPLEMENTATION

endmodule
