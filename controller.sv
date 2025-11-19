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
    fsm_t next_state;
    pe_inst_t pe_inst_reg, next_pe_inst_reg;
    buf_inst_t mem_inst_reg, next_mem_inst_reg;
    logic [`BUF_MEMA_OFFSET_BITWIDTH - 1 : 0] mema_offset, next_mema_offset;
    logic [`BUF_MEMB_OFFSET_BITWIDTH - 1 : 0] memb_offset, next_memb_offset;
    logic [`CONTROLLER_MEMA_INC_BITWIDTH - 1 : 0] mema_inc, next_mema_inc;
    logic [`CONTROLLER_MEMB_INC_BITWIDTH - 1 : 0] memb_inc, next_memb_inc;
    logic [`CONTROLLER_COUNTER_BITWIDTH - 1 : 0] counter, next_counter;
    logic next_inst_exec_begins, next_pe_inst_valid, next_buf_inst_valid;

    always @* begin
        // set all to earlier values to avoid latching
        next_state = state;
        next_pe_inst_reg = pe_inst_reg;
        next_mem_inst_reg = mem_inst_reg;
        next_mema_offset = mema_offset;
        next_memb_offset = memb_offset;
        next_mema_inc = mema_inc;
        next_memb_inc = memb_inc;
        next_counter = counter;
        next_inst_exec_begins = 1'b0;

        case (state)
            IDLE:
                if (inst_valid) begin
                    next_state = EXECUTING;
                    next_inst_exec_begins = 1'b1;
                    next_pe_inst_reg = inst.pe_instruction;
                    next_mem_inst_reg = inst.buf_instruction;
                    next_mema_offset = inst.buf_instruction.mema_offset;
                    next_memb_offset = inst.buf_instruction.memb_offset;
                    next_mema_inc = inst.mema_inc;
                    next_memb_inc = inst.memb_inc;
                    next_counter = inst.count + {{(`CONTROLLER_COUNT_BITWIDTH - 1){1'b0}}, 1'b1};
                end
            EXECUTING: begin
                pe_inst = pe_inst_reg;
                pe_inst_valid = 1'b1;

                buf_inst = mem_inst_reg;
                buf_inst.mema_offset = mema_offset;
                buf_inst.memb_offset = memb_offset;
                buf_inst_valid = 1'b1;

                if (counter == 1) begin
                    next_state = IDLE;
                    next_counter = '0;
                end else begin
                    next_state = EXECUTING;
                    next_counter = counter - 1'b1;
                    next_mema_offset = mema_offset + mema_inc;
                    next_memb_offset = memb_offset + memb_inc;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            pe_inst_reg <= '0;
            mem_inst_reg <= '0;
            mema_offset <= '0;
            memb_offset <= '0;
            mema_inc <= '0;
            memb_inc <= '0;
            counter <= '0;
            inst_exec_begins <= 1'b0;
        end else begin
            state <= next_state;
            pe_inst_reg <= next_pe_inst_reg;
            mem_inst_reg <= next_mem_inst_reg;
            mema_offset <= next_mema_offset;
            memb_offset <= next_memb_offset;
            mema_inc <= next_mema_inc;
            memb_inc <= next_memb_inc;
            counter <= next_counter;
            inst_exec_begins <= next_inst_exec_begins;
        end
    end
    // END IMPLEMENTATION

endmodule

