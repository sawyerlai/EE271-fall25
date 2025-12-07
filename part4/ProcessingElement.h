#ifndef __PROCESSING_ELEMENT_H__
#define __PROCESSING_ELEMENT_H__

#pragma once

#include <systemc.h>
#include <nvhls_connections.h>
#include <nvhls_int.h>
#include "../Spec.h"
#include "../InstructionSpec.h"

using namespace nvhls;

SC_MODULE(ProcessingElement)
{
    sc_in<bool> clk;
    sc_in<bool> rst;

    Connections::In<spec::Instruction::ProcessingElementInstruction::Packed_t> pe_inst_in;
    Connections::In<spec::VectorType> vector_input;
    Connections::In<spec::VectorType> matrix_input;
    Connections::Out<spec::VectorType> vector_output;

    spec::AccumVectorType accumulation_register;


    SC_HAS_PROCESS(ProcessingElement);
    ProcessingElement(sc_module_name name)
        : sc_module(name),
          clk("clk"),
          rst("rst"),
          pe_inst_in("pe_inst_in"),
          vector_input("vector_input"),
          matrix_input("matrix_input"),
          vector_output("vector_output")

    {
        SC_THREAD(run);
        sensitive << clk.pos();
        async_reset_signal_is(rst, false);
    }

    void run()
    {
        pe_inst_in.Reset();
        vector_input.Reset();
        matrix_input.Reset();
        vector_output.Reset();

        accumulation_register = 0;

        wait();

        while (1) {
            wait();


            //////////////// START IMPLEMENTATION HERE ////////////////
            // TODO: Your code here 
            // Note:
            // 1. You can use spec::NVINTW(width) to define integer with arbitrary bit-width
            // 2. You can use nvhls::get_slc<width>(var, pos) to get a slice of 'width' bits from 'var' starting at 'pos' bit
            // 3. You can use var.set_slc(pos, value) to set a slice of 'var' starting at 'pos' bit with 'value'
            // 4. Becareful about the Blocking and non blocking behvaiour for all the inputs
            // 5. The martix_input and vector_input are only valid (or Poped from connections channel) for MAC and PASS instructions
            // 6. The vector_output is only valid (or Pushed to connections channel) for OUT instruction
            // 7. Refer to InstructionSpec.h for instruction format and opcode/value definitions
            // 8. work through opcodes for MAC, PASS, OUT, and NOP as defined in spec::Instruction::PEI
            
            // Wait for an instruction to arrive (blocking read)
            spec::Instruction::ProcessingElementInstruction::Packed_t inst_packed = pe_inst_in.Pop();
            spec::Instruction::ProcessingElementInstruction inst(inst_packed);
            
            // Extract instruction fields using the accessor methods
            NVUINTW(2) opcode = inst.opcode();  // 2-bit opcode
            NVUINTW(2) mode = inst.mode();      // 2-bit mode (INT8=0, INT16=1, INT32=2)
            NVUINTW(5) value = inst.value();    // 5-bit value field (sub-opcode or shift amount)
            
            if (opcode == spec::Instruction::PEI::RND) {
                // RND instruction: Right-shift accumulator by 'value' bits (per lane)
                // This is used for fixed-point scaling after multiplication
                
                if (mode == 0) {  // INT8: 4 lanes, 16-bit accumulators each
                    #pragma hls_unroll yes
                    for (int i = 0; i < 4; i++) {
                        NVINTW(16) lane = nvhls::get_slc<16>(accumulation_register, i * 16);
                        lane = lane >> value;  // Arithmetic right shift (signed)
                        accumulation_register.set_slc(i * 16, lane);
                    }
                } else if (mode == 1) {  // INT16: 2 lanes, 32-bit accumulators each
                    #pragma hls_unroll yes
                    for (int i = 0; i < 2; i++) {
                        NVINTW(32) lane = nvhls::get_slc<32>(accumulation_register, i * 32);
                        lane = lane >> value;
                        accumulation_register.set_slc(i * 32, lane);
                    }
                } else {  // INT32: 1 lane, 64-bit accumulator
                    NVINTW(64) lane = accumulation_register;
                    lane = lane >> value;
                    accumulation_register = lane;
                }
                
            } else {
                // NO_VALUE opcode: use 'value' field as sub-opcode
                
                if (value == spec::Instruction::PEI::MAC) {
                    spec::VectorType mat = matrix_input.Pop();
                    spec::VectorType vec = vector_input.Pop();
                    
                    if (mode == 0) {  // INT8
                        #pragma hls_unroll yes
                        for (int i = 0; i < 4; i++) {
                            // Extract 8-bit signed values from each lane
                            NVINTW(8) mat_lane = nvhls::get_slc<8>(mat, i * 8);
                            NVINTW(8) vec_lane = nvhls::get_slc<8>(vec, i * 8);
                            // Get current 16-bit accumulator lane
                            NVINTW(16) acc_lane = nvhls::get_slc<16>(accumulation_register, i * 16);
                            // Multiply (result is 16-bit) and accumulate
                            NVINTW(16) product = (NVINTW(16))mat_lane * (NVINTW(16))vec_lane;
                            acc_lane += product;
                            accumulation_register.set_slc(i * 16, acc_lane);
                        }
                    } else if (mode == 1) {  // INT16
                        #pragma hls_unroll yes
                        for (int i = 0; i < 2; i++) {
                            NVINTW(16) mat_lane = nvhls::get_slc<16>(mat, i * 16);
                            NVINTW(16) vec_lane = nvhls::get_slc<16>(vec, i * 16);
                            NVINTW(32) acc_lane = nvhls::get_slc<32>(accumulation_register, i * 32);
                            NVINTW(32) product = (NVINTW(32))mat_lane * (NVINTW(32))vec_lane;
                            acc_lane += product;
                            accumulation_register.set_slc(i * 32, acc_lane);
                        }
                    } else {  // INT32
                        NVINTW(32) mat_val = mat;
                        NVINTW(32) vec_val = vec;
                        NVINTW(64) product = (NVINTW(64))mat_val * (NVINTW(64))vec_val;
                        accumulation_register += product;
                    }
                    
                } else if (value == spec::Instruction::PEI::PASS) {
                    spec::VectorType mat = matrix_input.Pop();
                    spec::VectorType vec = vector_input.Pop();
                    (void)mat;  // Suppress unused warning - we use vec for PASS
                    
                    if (mode == 0) {  // INT8
                        #pragma hls_unroll yes
                        for (int i = 0; i < 4; i++) {
                            NVINTW(8) vec_lane = nvhls::get_slc<8>(vec, i * 8);
                            NVINTW(16) extended = vec_lane;  // Sign extension
                            accumulation_register.set_slc(i * 16, extended);
                        }
                    } else if (mode == 1) {  // INT16
                        #pragma hls_unroll yes
                        for (int i = 0; i < 2; i++) {
                            NVINTW(16) vec_lane = nvhls::get_slc<16>(vec, i * 16);
                            NVINTW(32) extended = vec_lane;
                            accumulation_register.set_slc(i * 32, extended);
                        }
                    } else {  // INT32
                        NVINTW(32) vec_val = vec;
                        accumulation_register = (NVINTW(64))vec_val;
                    }
                    
                } else if (value == spec::Instruction::PEI::OUT) {
                    spec::VectorType output_val = 0;
                    
                    if (mode == 0) {  // INT8: extract lower 8 bits from each 16-bit lane
                        #pragma hls_unroll yes
                        for (int i = 0; i < 4; i++) {
                            NVUINTW(8) out_lane = nvhls::get_slc<8>(accumulation_register, i * 16);
                            output_val.set_slc(i * 8, out_lane);
                        }
                    } else if (mode == 1) {  // INT16: extract lower 16 bits from each 32-bit lane
                        #pragma hls_unroll yes
                        for (int i = 0; i < 2; i++) {
                            NVUINTW(16) out_lane = nvhls::get_slc<16>(accumulation_register, i * 32);
                            output_val.set_slc(i * 16, out_lane);
                        }
                    } else {  // INT32: extract lower 32 bits from 64-bit accumulator
                        output_val = nvhls::get_slc<32>(accumulation_register, 0);
                    }
                    
                    vector_output.Push(output_val);
                    
                } else if (value == spec::Instruction::PEI::CLR) {
                    accumulation_register = 0;
                    
                } else if (value == spec::Instruction::PEI::NOP) {
                    // NOP: Do nothing, just consume the instruction
                }
            }

            //////////////// END IMPLEMENTATION HERE ////////////////
        }
    }
};
#endif // ___PROCESSING_ELEMENT_H__
