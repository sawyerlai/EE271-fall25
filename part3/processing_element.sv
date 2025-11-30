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

    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] acc_value, next_acc_value;
    logic signed [`PE_OUTPUT_BITWIDTH-1:0] output_value, next_output_value;

    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] shifted;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] lane16, shifted16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] lane8, shifted8;

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

    pe_inst_t pe_inst_ff;
    logic pe_inst_valid_ff;

    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_ff;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2-1:0] mul_result_ff16 [1:0];
    logic signed [`PE_ACCUMULATION_BITWIDTH/4-1:0] mul_result_ff8 [3:0];
    
    logic mac_stage2_valid;
    logic [`PE_MODE_BITWIDTH-1:0] mode_stage2;

    logic signed [16:0] mul_a [3:0];
    logic signed [16:0] mul_b [3:0];
    logic signed [33:0] mul_out [3:0];
    
    assign mul_out[0] = mul_a[0] * mul_b[0];
    assign mul_out[1] = mul_a[1] * mul_b[1];
    assign mul_out[2] = mul_a[2] * mul_b[2];
    assign mul_out[3] = mul_a[3] * mul_b[3];

    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] mul_result_comb;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2-1:0] mul_result_comb16 [1:0];
    logic signed [`PE_ACCUMULATION_BITWIDTH/4-1:0] mul_result_comb8 [3:0];
    logic is_mac_op;
    
    logic [`PE_OPCODE_BITWIDTH-1:0] opcode_s1;
    logic [`PE_MODE_BITWIDTH-1:0] mode_s1;
    logic [`PE_VALUE_BITWIDTH-1:0] value_s1;

    logic signed [15:0] a_hi, b_hi;
    logic [15:0] a_lo, b_lo;
    logic signed [33:0] pp_hh;
    logic signed [33:0] pp_hl;
    logic signed [33:0] pp_lh;
    logic signed [33:0] pp_ll;

    always_comb begin
        integer i;
        
        opcode_s1 = pe_inst_ff.opcode;
        mode_s1 = pe_inst_ff.mode;
        value_s1 = pe_inst_ff.value;
        
        for (i = 0; i < 4; i++) begin
            mul_a[i] = '0;
            mul_b[i] = '0;
        end
        
        mul_result_comb = '0;
        for (i = 0; i < 2; i++) mul_result_comb16[i] = '0;
        for (i = 0; i < 4; i++) mul_result_comb8[i] = '0;
        is_mac_op = 1'b0;
        
        a_hi = '0; a_lo = '0;
        b_hi = '0; b_lo = '0;
        pp_hh = '0; pp_hl = '0; pp_lh = '0; pp_ll = '0;

        if (pe_inst_valid_ff) begin
            if (opcode_s1 != `PE_RND_OPCODE && value_s1 == `PE_MAC_VALUE) begin
                is_mac_op = 1'b1;
                
                case (mode_s1)
                    2'd0: begin
                        for (i = 0; i < 4; i++) begin
                            mul_a[i] = {{9{vector_input[i*8+7]}}, vector_input[i*8 +: 8]};
                            mul_b[i] = {{9{matrix_input[i*8+7]}}, matrix_input[i*8 +: 8]};
                            mul_result_comb8[i] = mul_out[i][15:0];
                        end
                    end
                    
                    2'd1: begin
                        for (i = 0; i < 2; i++) begin
                            mul_a[i] = {vector_input[i*16+15], vector_input[i*16 +: 16]};
                            mul_b[i] = {matrix_input[i*16+15], matrix_input[i*16 +: 16]};
                            mul_result_comb16[i] = mul_out[i][31:0];
                        end
                    end
                    
                    default: begin
                        a_hi = vector_input[31:16];
                        a_lo = vector_input[15:0];
                        b_hi = matrix_input[31:16];
                        b_lo = matrix_input[15:0];
                        
                        mul_a[0] = {a_hi[15], a_hi};
                        mul_b[0] = {b_hi[15], b_hi};
                        
                        mul_a[1] = {a_hi[15], a_hi};
                        mul_b[1] = {1'b0, b_lo};
                        
                        mul_a[2] = {1'b0, a_lo};
                        mul_b[2] = {b_hi[15], b_hi};
                        
                        mul_a[3] = {1'b0, a_lo};
                        mul_b[3] = {1'b0, b_lo};
                        
                        pp_hh = mul_out[0];
                        pp_hl = mul_out[1];
                        pp_lh = mul_out[2];
                        pp_ll = mul_out[3];
                        
                        mul_result_comb = (pp_hh << 32) + (pp_hl << 16) + (pp_lh << 16) + pp_ll;
                    end
                endcase
            end
        end
    end

    always_comb begin
        integer i;
        next_output_value = output_value;
        next_acc_value = acc_value;
        vector_output = output_value;

        if (mac_stage2_valid) begin
            case (mode_stage2)
                2'd0: begin
                    for (i = 0; i < 4; i++) begin
                        temp_val8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                        final_val8 = temp_val8 + mul_result_ff8[i];
                        wrapped8 = final_val8 & ((1 << `PE_ACCUMULATION_BITWIDTH/4) - 1);
                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = wrapped8;
                    end
                end
                2'd1: begin
                    for (i = 0; i < 2; i++) begin
                        temp_val16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                        final_val16 = temp_val16 + mul_result_ff16[i];
                        wrapped16 = final_val16 & ((1 << `PE_ACCUMULATION_BITWIDTH/2) - 1);
                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = wrapped16;
                    end
                end
                default: begin
                    temp_val = acc_value;
                    final_val = temp_val + mul_result_ff;
                    wrapped = final_val & ((1 << `PE_ACCUMULATION_BITWIDTH) - 1);
                    next_acc_value = wrapped;
                end
            endcase
        end

        if (pe_inst_valid_ff) begin
            case (pe_inst_ff.opcode) 
                `PE_RND_OPCODE: begin
                    case (pe_inst_ff.mode)
                        2'd0: begin
                            for (i = 0; i < 4; i++) begin
                                lane8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                shifted8 = lane8 >>> pe_inst_ff.value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = shifted8;
                            end
                        end
                        2'd1: begin
                            for (i = 0; i < 2; i++) begin
                                lane16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                shifted16 = lane16 >>> pe_inst_ff.value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = shifted16;
                            end
                        end
                        default: begin
                            shifted = acc_value >>> pe_inst_ff.value;
                            next_acc_value = shifted;
                        end
                    endcase
                end   
                default: begin
                    case (pe_inst_ff.value) 
                        `PE_MAC_VALUE: begin
                        end
                        `PE_OUT_VALUE: begin
                            case (pe_inst_ff.mode)
                                2'd0: begin
                                    for (i = 0; i < 4; i++) begin
                                        vacc_lane_val8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                        next_output_value[i * `PE_OUTPUT_BITWIDTH/4 +: `PE_OUTPUT_BITWIDTH/4] = vacc_lane_val8;
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < 2; i++) begin
                                        vacc_lane_val16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                        next_output_value[i * `PE_OUTPUT_BITWIDTH/2 +: `PE_OUTPUT_BITWIDTH/2] = vacc_lane_val16;
                                    end
                                end
                                default: begin
                                    vacc_lane_val = acc_value;
                                    next_output_value = vacc_lane_val;
                                end
                            endcase 
                        end
                        `PE_PASS_VALUE: begin
                            case (pe_inst_ff.mode) 
                                2'd0: begin
                                    for (i = 0; i < 4; i++) begin
                                        lane_in8 = vector_input[i * 8 +: 8];
                                        lane_ext8 = lane_in8;
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = lane_ext8;
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < 2; i++) begin
                                        lane_in16 = vector_input[i * 16 +: 16];
                                        lane_ext16 = lane_in16;
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = lane_ext16;
                                    end
                                end
                                default: begin
                                    lane_in = vector_input;
                                    lane_ext = lane_in;
                                    next_acc_value = lane_ext;
                                end
                            endcase
                        end
                        `PE_CLR_VALUE: begin
                            next_acc_value = '0;
                            next_output_value = '0;
                        end
                        default: begin
                        end
                    endcase
                end
            endcase
        end
    end

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
