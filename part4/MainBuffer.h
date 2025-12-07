#ifndef __MAIN_BUFFER_H__
#define __MAIN_BUFFER_H__

#pragma once

#include <systemc.h>
#include <nvhls_connections.h>
#include <vector>

#include "../Spec.h"
#include "../InstructionSpec.h"

SC_MODULE(MainBuffer)
{
public:
        
    sc_in<bool> clk;
    sc_in<bool> rst;

    Connections::In<spec::Instruction::MemoryInstruction::Packed_t> buf_inst_in;
    Connections::In<spec::VectorType> output_data_in[spec::N_PE];

    Connections::Out<spec::VectorType> matrix_data_out[spec::N_PE];
    Connections::Out<spec::VectorType> vector_data_out[spec::N_PE];

    Connections::In<spec::VectorType> matrix_mem_write;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> matrix_mem_write_addr;

    Connections::In<spec::VectorType> vector_mem_write;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> vector_mem_write_addr;

    Connections::Out<spec::VectorType> output_mem_read;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> output_mem_read_addr;

    spec::VectorType matrix_mem[spec::kMemDepth];
    spec::VectorType vector_mem[spec::kMemDepth];
    spec::VectorType output_mem[spec::kMemDepth];

    NVUINTW(spec::kMemAddrWidth) addr = 0;
        spec::VectorType data = 0;
    


    SC_HAS_PROCESS(MainBuffer);
    MainBuffer(sc_module_name name)
        : sc_module(name),
          clk("clk"),
          rst("rst")
    {
        for (unsigned i = 0; i < spec::kMemDepth; ++i) {
            matrix_mem[i] = 0;
            vector_mem[i] = 0;
            output_mem[i] = 0;
        }

        SC_THREAD(run);
        sensitive << clk.pos();
        async_reset_signal_is(rst, false);

    }

    void run() {
        buf_inst_in.Reset();
        matrix_mem_write.Reset();
        matrix_mem_write_addr.Reset();
        vector_mem_write.Reset();
        vector_mem_write_addr.Reset();
        output_mem_read_addr.Reset();
        output_mem_read.Reset();
        
        #pragma hls_unroll yes
        for (int i=0; i < spec::N_PE; i++) {
            output_data_in[i].Reset();
            matrix_data_out[i].Reset();
            vector_data_out[i].Reset(); // Reset all vector_data_out ports
        }
        
        wait();


        while(1) {
            wait();
            
            if (matrix_mem_write_addr.PopNB(addr)) {
                if (matrix_mem_write.PopNB(data)) {
                    matrix_mem[addr] = data;
                }
            }

            if (vector_mem_write_addr.PopNB(addr)) {
                if (vector_mem_write.PopNB(data)) {
                    vector_mem[addr] = data;
                }
            }

            if (output_mem_read_addr.PopNB(addr)) {
                output_mem_read.Push(output_mem[addr]);
            }

            
            spec::Instruction::MemoryInstruction::Packed_t inst_packed;
            if (buf_inst_in.PopNB(inst_packed)) {
                spec::Instruction::MemoryInstruction buf_inst(inst_packed);

                //////////////// START IMPLEMENTATION HERE ////////////////
                // TODO: Your code here 
                // Note:
                // 1. You can use spec::NVINTW(width) to define integer with arbitrary bit-width
                // 2. Work through opcodes for READ, WRITE, and NOP as defined in spec::Instruction::MI
                // 3. For one set of matrix_data_out, you will need to access buf_inst.mema_offset() * spec::N_PE + i to get the correct data from matrix_mem
                // 4. For vector_data from vector_mem, one vector_data has to be copied to all vectors in vector_data_out 
                
                NVUINTW(2) opcode = buf_inst.opcode();
                NVUINTW(2) mode = buf_inst.mode();
                NVUINTW(10) mema_offset = buf_inst.mema_offset();  // Matrix memory offset
                NVUINTW(10) memb_offset = buf_inst.memb_offset();  // Vector memory offset
                
                if (opcode == spec::Instruction::MI::READ) {
                    
                    // Read matrix data - 16 consecutive locations
                    // mema_offset is the "row" index, and we read 16 elements per row
                    #pragma hls_unroll yes
                    for (int i = 0; i < spec::N_PE; i++) {
                        matrix_data_out[i].Push(matrix_mem[mema_offset * spec::N_PE + i]);
                    }
                    
                    // Read vector data with mode-dependent sub-element selection
                    // Then broadcast the selected element to all 16 PEs
                    spec::VectorType vec_data;
                    
                    if (mode == 2) {  // INT32: direct access
                        vec_data = vector_mem[memb_offset];
                    } else if (mode == 1) {  // INT16: 2 sub-elements per word
                        // Address bits [9:1] select the memory word
                        // Address bit [0] selects which 16-bit sub-element
                        NVUINTW(10) mem_addr = memb_offset >> 1;
                        NVUINTW(1) sub_idx = nvhls::get_slc<1>(memb_offset, 0);
                        spec::VectorType raw = vector_mem[mem_addr];
                        
                        // Extract the 16-bit sub-element and replicate it
                        NVUINTW(16) sub_elem = nvhls::get_slc<16>(raw, sub_idx * 16);
                        vec_data.set_slc(0, sub_elem);
                        vec_data.set_slc(16, sub_elem);
                    } else {  // INT8: 4 sub-elements per word
                        // Address bits [9:2] select the memory word
                        // Address bits [1:0] select which 8-bit sub-element
                        NVUINTW(10) mem_addr = memb_offset >> 2;
                        NVUINTW(2) sub_idx = nvhls::get_slc<2>(memb_offset, 0);
                        spec::VectorType raw = vector_mem[mem_addr];
                        
                        // Extract the 8-bit sub-element and replicate it 4 times
                        NVUINTW(8) sub_elem = nvhls::get_slc<8>(raw, sub_idx * 8);
                        vec_data.set_slc(0, sub_elem);
                        vec_data.set_slc(8, sub_elem);
                        vec_data.set_slc(16, sub_elem);
                        vec_data.set_slc(24, sub_elem);
                    }
                    
                    // Broadcast vector data to all 16 PEs
                    #pragma hls_unroll yes
                    for (int i = 0; i < spec::N_PE; i++) {
                        vector_data_out[i].Push(vec_data);
                    }
                    
                } else if (opcode == spec::Instruction::MI::WRITE) {
        
                    #pragma hls_unroll yes
                    for (int i = 0; i < spec::N_PE; i++) {
                        spec::VectorType pe_output = output_data_in[i].Pop();
                        output_mem[mema_offset * spec::N_PE + i] = pe_output;
                    }
                    
                } else if (opcode == spec::Instruction::MI::NOP) {
                    // NOP: Do nothing
                }
  
                //////////////// END IMPLEMENTATION HERE ////////////////
            }
        }
    }
};


#endif // __MAIN_BUFFER_H__
