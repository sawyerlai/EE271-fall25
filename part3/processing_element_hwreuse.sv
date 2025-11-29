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
    logic [`PE_OPCODE_BITWIDTH-1:0] opcode;
    logic [`PE_MODE_BITWIDTH-1:0] mode;
    logic [`PE_VALUE_BITWIDTH-1:0] value;

    logic signed [`PE_ACCUMULATION_BITWIDTH-1:0] acc_value, next_acc_value;
    logic signed [`PE_OUTPUT_BITWIDTH-1:0] output_value, next_output_value;

    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] shifted;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] lane16, shifted16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] lane8, shifted8;

    logic signed [`PE_INPUT_BITWIDTH - 1:0] a_val, b_val;
    logic signed [2 * `PE_INPUT_BITWIDTH - 1:0] mul_output;
    assign mul_output = a_val * b_val;

    logic [1:0] lane_idx, next_lane_idx;

    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] final_val, wrapped, temp_val;
    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] vacc_lane_val;

    logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] a_val16, b_val16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] final_val16, wrapped16, temp_val16;
    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] vacc_lane_val16;

    logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] a_val8, b_val8;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] final_val8, wrapped8, temp_val8;
    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] vacc_lane_val8;

    logic signed [`PE_ACCUMULATION_BITWIDTH - 1 : 0] lane_ext;
    logic signed [`PE_INPUT_BITWIDTH - 1:0] lane_in;

    logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1 : 0] lane_ext16;
    logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] lane_in16;

    logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1 : 0] lane_ext8;
    logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] lane_in8;

    // Pipeline Registers
    pe_inst_t pe_inst_ff;
    logic pe_inst_valid_ff;

    always @* begin
        integer i;
        next_output_value = output_value;
        next_acc_value = acc_value;
        vector_output = output_value;
        next_lane_idx = lane_idx;

        // Use the delayed/registered instruction
        if (pe_inst_valid_ff) begin
            opcode = pe_inst_ff.opcode;
            mode = pe_inst_ff.mode;
            value = pe_inst_ff.value;

            case (opcode) 
                `PE_RND_OPCODE: begin
                    case (mode)
                        2'd0: begin
                            for (i = 0; i < 4; i++) begin
                                lane8 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                shifted8 = lane8 >>> value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = shifted8;
                            end
                        end
                        2'd1: begin
                            for (i = 0; i < 2; i++) begin
                                lane16 = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                shifted16 = lane16 >>> value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = shifted16;
                            end
                        end
                        default: begin
                            shifted = acc_value >>> value;
                            next_acc_value = shifted;
                        end
                    endcase
                end   
                default: begin
                    case (value) 
                        `PE_MAC_VALUE: begin
                            case (mode)
                                2'd0: begin
                                    a_val8 = vector_input[lane_idx * 8 +: 8];
                                    b_val8 = matrix_input[lane_idx * 8 +: 8];

                                    a_val = {{(`PE_INPUT_BITWIDTH - 8){a_val8[7]}}, a_val8}; // sign extend
                                    b_val = {{(`PE_INPUT_BITWIDTH - 8){b_val8[7]}}, b_val8};

                                    temp_val8 = acc_value[lane_idx * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                    final_val8 = temp_val8 + mul_p[`PE_ACCUMULATION_BITWIDTH/4 - 1:0];
                                    wrapped8 = final_val8 & ((1 << `PE_ACCUMULATION_BITWIDTH/4) - 1);
                                    next_acc_value[lane_idx * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = wrapped8;

                                    if (lane_idx == 2'd3)
                                        next_lane_idx = 2'd0;
                                    else
                                        next_lane_idx = lane_idx + 2'd1;
                                end
                                2'd1: begin
                                    a_val16 = vector_input[lane_idx * 16 +: 16];
                                    b_val16 = matrix_input[lane_idx * 16 +: 16];

                                    a_val = {{(`PE_INPUT_BITWIDTH - 16){a_val16[7]}}, a_val16}; // sign extend
                                    b_val = {{(`PE_INPUT_BITWIDTH - 16){b_val16[7]}}, b_val16};

                                    temp_val16 = acc_value[lane_idx * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                    final_val16 = temp_val16 + mul_p[`PE_ACCUMULATION_BITWIDTH/2 - 1:0];
                                    wrapped16 = final_val16 & ((1 << `PE_ACCUMULATION_BITWIDTH/2) - 1);
                                    next_acc_value[lane_idx * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = wrapped16;

                                    if (lane_idx == 2'd1)
                                        next_lane_idx = 2'd0;
                                    else
                                        next_lane_idx = lane_idx + 2'd1;
                                end
                                default: begin
                                    a_val = vector_input;
                                    b_val = matrix_input;
                                    temp_val  = acc_value;
                                    final_val = temp_val + a_val * b_val;
                                    wrapped = final_val & ((1 << `PE_ACCUMULATION_BITWIDTH) - 1);
                                    next_acc_value = wrapped;
                                end
                            endcase
                        end
                        `PE_OUT_VALUE: begin
                            case (mode)
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
                            case (mode) 
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
                            // NOP
                        end
                    endcase
                end
            endcase
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            acc_value <= '0; 
            output_value <= '0;
            pe_inst_ff <= '0;
            pe_inst_valid_ff <= '0;
            lane_idx <= '0;
        end else begin
            acc_value <= next_acc_value;
            output_value <= next_output_value;
            pe_inst_ff <= pe_inst;
            pe_inst_valid_ff <= pe_inst_valid;
            lane_idx <= next_lane_idx;
        end
    end
    // END IMPLEMENTATION

endmodule
