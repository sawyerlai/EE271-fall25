`include "defines.sv"

module buffer (
    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // Input Instruction
    input buf_inst_t    buf_inst,
    input logic         buf_inst_valid,

    // Outputs
    output logic [`MEM0_BITWIDTH-1:0] matrix_data,
    output logic [`MEM1_BITWIDTH-1:0] vector_data,
    input  logic [`MEM2_BITWIDTH-1:0] output_data
);

    // START IMPLEMENTATION
    
    // Matrix Memory 
    array #(
        .DW(`MEM0_BITWIDTH),
        .NW(`MEM0_DEPTH),
        .AW(`MEM0_ADDR_WIDTH)
    ) u_matrix_mem (
        .clk(clk),
        .cen('0),
        .wen('1),
        .gwen('1),
        .a(buf_inst.mema_offset),
        .d('0),
        .q(matrix_data)
    );

    // MEM1 Logic 
    logic [`MEM1_BITWIDTH-1:0]              mem1_data_raw;
    logic [`MEM1_ADDR_WIDTH-1:0]            mem1_addr;

    // Pipeline the address LSBs to align with memory read latency (1 cycle)
    logic [`BUF_MEMB_OFFSET_BITWIDTH-1:0]   offset_reg;
    always @(posedge clk, negedge rst_n) begin
        offset_reg <= (!rst_n) ? '0 : buf_inst.memb_offset;
    end

    vector_decoder vector_decoder_inst (
        .data_from_mem(mem1_data_raw),
        .addr_from_controller(buf_inst.memb_offset),
        .addr_from_controller_reg(offset_reg),
        .mode(buf_inst.mode),
        .data_to_pe(vector_data),
        .addr_to_mem(mem1_addr)
    );
    
    array #(
        .DW(`MEM1_BITWIDTH),
        .NW(`MEM1_DEPTH),
        .AW(`MEM1_ADDR_WIDTH)
    ) u_vector_mem (
        .clk(clk),
        .cen('0),
        .wen('1),
        .gwen('1),
        .a(mem1_addr),
        .d('0),
        .q(mem1_data_raw)
    );

    // Write to output 
    logic write_control_n; // Active Low 
    assign write_control_n = ~(buf_inst_valid && (buf_inst.opcode == `BUF_WRITE));
    
    array #(
        .DW(`MEM2_BITWIDTH),
        .NW(`MEM2_DEPTH),
        .AW(`MEM2_ADDR_WIDTH),
        .INITIALIZE_MEMORY(1)
    ) u_output_mem (
        .clk(clk),
        .cen('0),
        .wen('0),
        .gwen(write_control_n),
        .a(buf_inst.mema_offset),
        .d(output_data),
        .q()
    );


    // END IMPLEMENTATION


endmodule
