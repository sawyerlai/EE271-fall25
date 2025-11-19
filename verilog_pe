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

    logic [`PE_ACCUMULATION_BITWIDTH-1:0] acc_value;
    logic [`PE_ACCUMULATION_BITWIDTH-1:0] next_acc_value;
    logic [`PE_OUTPUT_BITWIDTH-1:0] next_output_value;
    logic [`PE_ACCUMULATION_BITWIDTH - 1:0] lane;

    always @* begin
        integer i;
        next_output_value = vector_output;
        next_acc_value = acc_value;

        if (pe_inst_valid) begin
            opcode = pe_inst.opcode;
            mode = pe_inst.mode;
            value = pe_inst.value;

            case (opcode) 
                `PE_RND_OPCODE: begin
                    case (mode)
                        2'd0: begin
                            for (i = 0; i < 4; i++) begin
                                logic [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] lane = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                logic [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] shifted = lane >>> value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = shifted;
                            end
                        end
                        2'd1: begin
                            for (i = 0; i < 2; i++) begin
                                logic [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] lane = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                logic [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] shifted = lane >>> value;
                                next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = shifted;
                            end
                        end
                        default: begin
                            logic [`PE_ACCUMULATION_BITWIDTH - 1:0] shifted = acc_value >>> value;
                            next_acc_value = shifted;
                        end
                    endcase
                end   
                default: begin
                    case (value) 
                        `PE_MAC_VALUE: begin
                            case (mode)
                                2'd0: begin
                                    for (i = 0; i < 4; i++) begin
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] final_val;
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] wrapped;
                                        logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] a_val = vector_input[i * 8 +: 8];
                                        logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] b_val = matrix_input[i * 8 +: 8];

                                        logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1 : 0] temp_val = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                        final_val = temp_val + a_val * b_val;
                                        wrapped = final_val & ((1 << `PE_ACCUMULATION_BITWIDTH/4) - 1);
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = wrapped[0 +: `PE_ACCUMULATION_BITWIDTH/4];
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < 2; i++) begin
                                        logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] a_val = vector_input[i * 16 +: 16];
                                        logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] b_val = matrix_input[i * 16 +: 16];
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] final_val;
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] wrapped;

                                        logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1 : 0] temp_val = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                        final_val = temp_val + a_val * b_val;
                                        wrapped = final_val & ((1 << `PE_ACCUMULATION_BITWIDTH/2) - 1);
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = wrapped[0 +: `PE_ACCUMULATION_BITWIDTH/2];
                                    end
                                end
                                default: begin
                                    logic signed [`PE_INPUT_BITWIDTH - 1:0] a_val = vector_input;
                                    logic signed [`PE_INPUT_BITWIDTH - 1:0] b_val = matrix_input;
                                    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] final_val;
                                    logic signed [`PE_ACCUMULATION_BITWIDTH - 1:0] wrapped; 

                                    logic signed [`PE_ACCUMULATION_BITWIDTH - 1 : 0] temp_val  = acc_value;
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
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1:0] vacc_lane_val = acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4];
                                        next_output_value[i * `PE_OUTPUT_BITWIDTH/4 +: `PE_OUTPUT_BITWIDTH/4] = vacc_lane_val[`PE_OUTPUT_BITWIDTH/4 - 1 : 0];
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < 2; i++) begin
                                        logic [`PE_ACCUMULATION_BITWIDTH/2 - 1:0] vacc_lane_val = acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2];
                                        next_output_value[i * `PE_OUTPUT_BITWIDTH/2 +: `PE_OUTPUT_BITWIDTH/2] = vacc_lane_val[`PE_OUTPUT_BITWIDTH/2 - 1 : 0];
                                    end
                                end
                                default: begin
                                    logic [`PE_ACCUMULATION_BITWIDTH - 1:0] vacc_lane_val = acc_value;
                                    next_output_value = vacc_lane_val[`PE_OUTPUT_BITWIDTH - 1 : 0];
                                end
                            endcase 
                        end
                        `PE_PASS_VALUE: begin
                            case (mode) 
                                2'd0: begin
                                    for (i = 0; i < 4; i++) begin
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/4 - 1 : 0] lane_ext;
                                        logic signed [`PE_INPUT_BITWIDTH/4 - 1:0] lane_in = vector_input[i * 8 +: 8];
                                        lane_ext = lane_in;
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/4 +: `PE_ACCUMULATION_BITWIDTH/4] = lane_ext;
                                    end
                                end
                                2'd1: begin
                                    for (i = 0; i < 2; i++) begin
                                        logic signed [`PE_ACCUMULATION_BITWIDTH/2 - 1 : 0] lane_ext;
                                        logic signed [`PE_INPUT_BITWIDTH/2 - 1:0] lane_in = vector_input[i * 16 +: 16];
                                        lane_ext = lane_in;
                                        next_acc_value[i * `PE_ACCUMULATION_BITWIDTH/2 +: `PE_ACCUMULATION_BITWIDTH/2] = lane_ext;
                                    end
                                end
                                default: begin
                                    logic signed [`PE_ACCUMULATION_BITWIDTH - 1 : 0] lane_ext;
                                    logic signed [`PE_INPUT_BITWIDTH - 1:0] lane_in = vector_input;
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

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            acc_value <= '0; // sets all bits to 0!
            vector_output <= '0;
        end else begin
            acc_value <= next_acc_value;
            vector_output <= next_output_value;
        end
    end
    // END IMPLEMENTATION

endmodule
