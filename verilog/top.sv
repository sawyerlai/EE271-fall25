`include "defines.sv"

module top(

    // Clock and Reset Inputs
    input wire clk,
    input wire rst_n,

    // Controls How Many Instructions Will be Executed
    input logic [`IMEM_ADDR_WIDTH-1:0] instruction_count
);

    // Top Level Signals
    instruction_t inst;
    wire          inst_valid;
    wire          inst_exec_begins;

    instruction_memory u_instruction_memory (
        .clk(clk),
        .rst_n(rst_n),
        .inst(inst),
        .inst_valid(inst_valid),
        .advance_pointer(inst_exec_begins),
        .instruction_count(instruction_count)
    );

    // START IMPLEMENTATION
    pe_inst_t     pe_inst;
    logic         pe_inst_valid;
    buf_inst_t    buf_inst;
    logic         buf_inst_valid;

    logic [`MEM0_BITWIDTH-1:0] matrix_data; // From MEM0 to PEs
    logic [`MEM1_BITWIDTH-1:0] vector_data; // From MEM1 to PEs
    logic [`MEM2_BITWIDTH-1:0] output_data; // From PEs to MEM2

    // controller
    controller u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .inst(inst),
        .inst_valid(inst_valid),
        .inst_exec_begins(inst_exec_begins),
        .pe_inst(pe_inst),
        .pe_inst_valid(pe_inst_valid),
        .buf_inst(buf_inst),
        .buf_inst_valid(buf_inst_valid)
    );

    // buffer
    buffer u_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .buf_inst(buf_inst),
        .buf_inst_valid(buf_inst_valid),
        .matrix_data(matrix_data),
        .vector_data(vector_data),
        .output_data(output_data)
    );

    logic [`PE_INPUT_BITWIDTH-1:0] pe_inputs_a [`PE_COUNT-1:0];
    logic [`PE_INPUT_BITWIDTH-1:0] pe_inputs_b;
    logic [`PE_OUTPUT_BITWIDTH-1:0] pe_outputs [`PE_COUNT-1:0];

    assign pe_inputs_b = vector_data; 

    genvar i;
    generate
        for (i = 0; i < `PE_COUNT; i++) begin : pe_gen
            assign pe_inputs_a[i] = matrix_data[i*`PE_INPUT_BITWIDTH +: `PE_INPUT_BITWIDTH];

            processing_element u_pe (
                .clk(clk),
                .rst_n(rst_n),
                .pe_inst(pe_inst),
                .pe_inst_valid(pe_inst_valid),
                .vector_input(pe_inputs_a[i]),
                .matrix_input(pe_inputs_b),
                .vector_output(pe_outputs[i])
            );
            
            assign output_data[i*`PE_OUTPUT_BITWIDTH +: `PE_OUTPUT_BITWIDTH] = pe_outputs[i];
        end
    endgenerate
    // END IMPLEMENTATION


endmodule
