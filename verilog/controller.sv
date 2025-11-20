`include "defines.sv"

module controller(

    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // Input Instruction
    input  instruction_t inst,
    input  logic         inst_valid,
    output logic         inst_exec_begins,

    // Output Instructions to PEs/Buffer
    output pe_inst_t     pe_inst,
    output logic         pe_inst_valid,
    output buf_inst_t    buf_inst,
    output logic         buf_inst_valid

);

    typedef enum {IDLE, EXECUTING} fsm_t; 
    fsm_t state;

    // START IMPLEMENTATION
    logic [`CONTROLLER_COUNT_BITWIDTH-1:0] count;
    
    // Registers to track offsets and increments during loop execution
    logic [`BUF_MEMA_OFFSET_BITWIDTH-1:0] mema_offset_reg;
    logic [`BUF_MEMB_OFFSET_BITWIDTH-1:0] memb_offset_reg;
    logic [`CONTROLLER_MEMA_INC_BITWIDTH-1:0] mema_inc_reg;
    logic [`CONTROLLER_MEMB_INC_BITWIDTH-1:0] memb_inc_reg;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            inst_exec_begins <= '0;
            pe_inst <= '0;
            pe_inst_valid <= '0;
            buf_inst <= '0;
            buf_inst_valid <= '0;
            count <= '0;
            mema_offset_reg <= '0;
            memb_offset_reg <= '0;
            mema_inc_reg <= '0;
            memb_inc_reg <= '0;
        end else begin
            
            case (state)
                IDLE: begin
                    if (inst_valid) begin
                        state <= EXECUTING;
                        inst_exec_begins <= 1'b1;
                        count <= inst.count;
                        mema_offset_reg <= inst.buf_instruction.mema_offset;
                        memb_offset_reg <= inst.buf_instruction.memb_offset;
                        mema_inc_reg    <= inst.mema_inc;
                        memb_inc_reg    <= inst.memb_inc;
                        pe_inst <= inst.pe_instruction;
                        pe_inst_valid <= 1'b1;
                        buf_inst <= inst.buf_instruction;
                        buf_inst_valid <= 1'b1;
                    end else begin
                        state <= IDLE;
                        pe_inst_valid <= 1'b0;
                        buf_inst_valid <= 1'b0;
                        inst_exec_begins <= 1'b0;
                    end
                end

                EXECUTING: begin
                    inst_exec_begins <= 1'b0;

                    if (count == 0) begin
                        state <= IDLE;
                        pe_inst_valid <= 1'b0;
                        buf_inst_valid <= 1'b0;
                    end else begin
                        count <= count - 1;
                        mema_offset_reg <= mema_offset_reg + mema_inc_reg;
                        memb_offset_reg <= memb_offset_reg + memb_inc_reg;
                        buf_inst.mema_offset <= mema_offset_reg + mema_inc_reg;
                        buf_inst.memb_offset <= memb_offset_reg + memb_inc_reg;
                        pe_inst_valid <= 1'b1;
                        buf_inst_valid <= 1'b1;
                    end
                end
            endcase
        end
    end
    // END IMPLEMENTATION

endmodule
