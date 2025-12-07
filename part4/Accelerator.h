#ifndef __ACCELERATOR_H__
#define __ACCELERATOR_H__

#pragma once

#include <systemc.h>
#include <nvhls_connections.h>
#include "Spec.h"
#include "InstructionSpec.h"
#include "ProcessingElement/ProcessingElement.h"
#include "MainBuffer/MainBuffer.h"

SC_MODULE(Accelerator)
{
public:


    sc_in<bool> clk;
    sc_in<bool> rst;

    Connections::In<spec::Instruction::Instruction::Packed_t> inst_in;
    Connections::In<spec::VectorType> matrix_mem_write;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> matrix_mem_write_addr;
    Connections::In<spec::VectorType> vector_mem_write;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> vector_mem_write_addr;
    Connections::Out<spec::VectorType> output_mem_read;
    Connections::In<NVUINTW(spec::kMemAddrWidth)> output_mem_read_addr;

    // Sub-modules
    ProcessingElement pe_array0;
    ProcessingElement pe_array1;
    ProcessingElement pe_array2;
    ProcessingElement pe_array3;
    ProcessingElement pe_array4;
    ProcessingElement pe_array5;
    ProcessingElement pe_array6;
    ProcessingElement pe_array7;
    ProcessingElement pe_array8;
    ProcessingElement pe_array9;
    ProcessingElement pe_array10;
    ProcessingElement pe_array11;
    ProcessingElement pe_array12;
    ProcessingElement pe_array13;
    ProcessingElement pe_array14;
    ProcessingElement pe_array15;

    MainBuffer main_buffer;

    // Internal channels for connecting sub-modules
    Connections::Combinational<spec::Instruction::ProcessingElementInstruction::Packed_t> pe_inst_channels[spec::N_PE];
    Connections::Combinational<spec::Instruction::MemoryInstruction::Packed_t> buf_inst;

    // Channels for PE <-> MainBuffer data transfer
    Connections::Combinational<spec::VectorType> matrix_data_channels[spec::N_PE];
    Connections::Combinational<spec::VectorType> vector_data_channels[spec::N_PE];
    Connections::Combinational<spec::VectorType> output_data_channels[spec::N_PE];


    SC_HAS_PROCESS(Accelerator);
    Accelerator(sc_module_name name)
        : sc_module(name),
            clk("clk"),
            rst("rst"),
            inst_in("inst_in"),
            pe_array0("pe_array0"),
            pe_array1("pe_array1"),
            pe_array2("pe_array2"),
            pe_array3("pe_array3"),
            pe_array4("pe_array4"),
            pe_array5("pe_array5"),
            pe_array6("pe_array6"),
            pe_array7("pe_array7"),
            pe_array8("pe_array8"),
            pe_array9("pe_array9"),
            pe_array10("pe_array10"),
            pe_array11("pe_array11"),
            pe_array12("pe_array12"),
            pe_array13("pe_array13"),
            pe_array14("pe_array14"),
            pe_array15("pe_array15"),
            main_buffer("main_buffer")
    {
        // Instantiate Processing Elements and connect channels
        // Add all individual instances, apparently catapult does not loops for objects creation yet
        pe_array0.clk(clk);
        pe_array0.rst(rst);
        pe_array0.pe_inst_in(pe_inst_channels[0]);
        pe_array0.matrix_input(matrix_data_channels[0]);
        pe_array0.vector_input(vector_data_channels[0]);
        pe_array0.vector_output(output_data_channels[0]);
        pe_array1.clk(clk);
        pe_array1.rst(rst);
        pe_array1.pe_inst_in(pe_inst_channels[1]);
        pe_array1.matrix_input(matrix_data_channels[1]);
        pe_array1.vector_input(vector_data_channels[1]);
        pe_array1.vector_output(output_data_channels[1]);
        pe_array2.clk(clk);
        pe_array2.rst(rst);
        pe_array2.pe_inst_in(pe_inst_channels[2]);
        pe_array2.matrix_input(matrix_data_channels[2]);
        pe_array2.vector_input(vector_data_channels[2]);
        pe_array2.vector_output(output_data_channels[2]);
        pe_array3.clk(clk);
        pe_array3.rst(rst);
        pe_array3.pe_inst_in(pe_inst_channels[3]);
        pe_array3.matrix_input(matrix_data_channels[3]);
        pe_array3.vector_input(vector_data_channels[3]);
        pe_array3.vector_output(output_data_channels[3]); 
        pe_array4.clk(clk);
        pe_array4.rst(rst);
        pe_array4.pe_inst_in(pe_inst_channels[4]);
        pe_array4.matrix_input(matrix_data_channels[4]);
        pe_array4.vector_input(vector_data_channels[4]);
        pe_array4.vector_output(output_data_channels[4]);
        pe_array5.clk(clk);
        pe_array5.rst(rst);
        pe_array5.pe_inst_in(pe_inst_channels[5]);
        pe_array5.matrix_input(matrix_data_channels[5]);
        pe_array5.vector_input(vector_data_channels[5]);
        pe_array5.vector_output(output_data_channels[5]);
        pe_array6.clk(clk);
        pe_array6.rst(rst);
        pe_array6.pe_inst_in(pe_inst_channels[6]);
        pe_array6.matrix_input(matrix_data_channels[6]);
        pe_array6.vector_input(vector_data_channels[6]);
        pe_array6.vector_output(output_data_channels[6]);
        pe_array7.clk(clk);
        pe_array7.rst(rst);
        pe_array7.pe_inst_in(pe_inst_channels[7]);
        pe_array7.matrix_input(matrix_data_channels[7]);
        pe_array7.vector_input(vector_data_channels[7]);
        pe_array7.vector_output(output_data_channels[7]);
        pe_array8.clk(clk);
        pe_array8.rst(rst);
        pe_array8.pe_inst_in(pe_inst_channels[8]);
        pe_array8.matrix_input(matrix_data_channels[8]);
        pe_array8.vector_input(vector_data_channels[8]); 
        pe_array8.vector_output(output_data_channels[8]);
        pe_array9.clk(clk);
        pe_array9.rst(rst);
        pe_array9.pe_inst_in(pe_inst_channels[9]);
        pe_array9.matrix_input(matrix_data_channels[9]);
        pe_array9.vector_input(vector_data_channels[9]);
        pe_array9.vector_output(output_data_channels[9]);
        pe_array10.clk(clk);
        pe_array10.rst(rst);
        pe_array10.pe_inst_in(pe_inst_channels[10]);
        pe_array10.matrix_input(matrix_data_channels[10]);
        pe_array10.vector_input(vector_data_channels[10]);
        pe_array10.vector_output(output_data_channels[10]);
        pe_array11.clk(clk);
        pe_array11.rst(rst);
        pe_array11.pe_inst_in(pe_inst_channels[11]);
        pe_array11.matrix_input(matrix_data_channels[11]);
        pe_array11.vector_input(vector_data_channels[11]);
        pe_array11.vector_output(output_data_channels[11]);
        pe_array12.clk(clk);
        pe_array12.rst(rst);
        pe_array12.pe_inst_in(pe_inst_channels[12]);
        pe_array12.matrix_input(matrix_data_channels[12]);
        pe_array12.vector_input(vector_data_channels[12]);
        pe_array12.vector_output(output_data_channels[12]);
        pe_array13.clk(clk);
        pe_array13.rst(rst);
        pe_array13.pe_inst_in(pe_inst_channels[13]);
        pe_array13.matrix_input(matrix_data_channels[13]);
        pe_array13.vector_input(vector_data_channels[13]);
        pe_array13.vector_output(output_data_channels[13]);
        pe_array14.clk(clk);
        pe_array14.rst(rst);
        pe_array14.pe_inst_in(pe_inst_channels[14]);
        pe_array14.matrix_input(matrix_data_channels[14]);
        pe_array14.vector_input(vector_data_channels[14]);
        pe_array14.vector_output(output_data_channels[14]);
        pe_array15.clk(clk);
        pe_array15.rst(rst);
        pe_array15.pe_inst_in(pe_inst_channels[15]);
        pe_array15.matrix_input(matrix_data_channels[15]);
        pe_array15.vector_input(vector_data_channels[15]);
        pe_array15.vector_output(output_data_channels[15]);


        // Instantiate MainBuffer
        main_buffer.clk(clk);
        main_buffer.rst(rst);
        main_buffer.buf_inst_in(buf_inst);
        
        // Connect PE data channels to MainBuffer
        for (int i = 0; i < spec::N_PE; i++) {
            main_buffer.vector_data_out[i](vector_data_channels[i]);
            main_buffer.matrix_data_out[i](matrix_data_channels[i]);
            main_buffer.output_data_in[i](output_data_channels[i]);
        }

        // Connect memory access channels
        main_buffer.matrix_mem_write(matrix_mem_write);
        main_buffer.matrix_mem_write_addr(matrix_mem_write_addr);
        main_buffer.vector_mem_write(vector_mem_write);
        main_buffer.vector_mem_write_addr(vector_mem_write_addr);
        main_buffer.output_mem_read(output_mem_read);
        main_buffer.output_mem_read_addr(output_mem_read_addr);
        
        SC_THREAD(run);
        sensitive << clk.pos();
        async_reset_signal_is(rst, false);
    }

    void run()
    {
        inst_in.Reset();
        buf_inst.ResetWrite();
        #pragma hls_unroll yes
        for (int i = 0; i < spec::N_PE; i++) {
            pe_inst_channels[i].ResetWrite();
        }

        wait();

        while (1) {

            //////////////// START IMPLEMENTATION HERE ////////////////
            // TODO: Your code here 
            // Note:
            // 1. dont forget to an a wait(); within the while loop to avoid infinite zero-delay loop, preferably in the count loop
            
            // Wait for a new instruction (blocking)
            spec::Instruction::Instruction::Packed_t inst_packed = inst_in.Pop();
            spec::Instruction::Instruction inst(inst_packed);
            
            // Extract instruction components
            spec::Instruction::MemoryInstruction mem_inst = inst.mem_instruction();
            spec::Instruction::ProcessingElementInstruction pe_inst = inst.pe_instruction();
            NVUINTW(10) count = inst.count();     
            NVUINTW(1) mema_inc = inst.mema_inc(); 
            NVUINTW(1) memb_inc = inst.memb_inc(); 
            
            // Get initial memory offsets
            NVUINTW(10) mema_offset = mem_inst.mema_offset();
            NVUINTW(10) memb_offset = mem_inst.memb_offset();
            
            for (NVUINTW(11) i = 0; i <= count; i++) {
                // Update memory instruction offsets for this iteration
                mem_inst.set_mema_offset(mema_offset);
                mem_inst.set_memb_offset(memb_offset);
                
                // Dispatch memory instruction to MainBuffer
                buf_inst.Push(mem_inst.packed);
                
                // Dispatch PE instruction to all 16 Processing Elements
                #pragma hls_unroll yes
                for (int pe = 0; pe < spec::N_PE; pe++) {
                    pe_inst_channels[pe].Push(pe_inst.packed);
                }
                
                // Increment offsets for next iteration if enabled
                if (mema_inc) {
                    mema_offset = mema_offset + 1;
                }
                if (memb_inc) {
                    memb_offset = memb_offset + 1;
                }
                
                wait();
            }
           
            ////////////// END IMPLEMENTATION HERE ////////////////
        }
    }
};

#endif // __ACCELERATOR_H__
