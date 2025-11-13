from bitstring import Bits
from .instruction import MemoryInstruction, MI, Mode
from dataclasses import dataclass
import numpy as np

@dataclass
class MainBufferConfiguration:
    MEM0_BITWIDTH : int
    MEM0_DEPTH    : int
    MEM1_BITWIDTH : int
    MEM1_DEPTH    : int
    MEM2_BITWIDTH : int
    MEM2_DEPTH    : int

class MainBuffer:

    def __init__(
        self,
        config : MainBufferConfiguration,
        default_value = 0
    ):

        # Saving the Config
        self._buffer_config = config

        # Creating the Individual Memories
        self._mem0 = [Bits(int=default_value, length=self._buffer_config.MEM0_BITWIDTH) for _ in range(self._buffer_config.MEM0_DEPTH)]
        self._mem1 = [Bits(int=default_value, length=self._buffer_config.MEM1_BITWIDTH) for _ in range(self._buffer_config.MEM1_DEPTH)]
        self._mem2 = [Bits(int=default_value, length=self._buffer_config.MEM2_BITWIDTH) for _ in range(self._buffer_config.MEM2_DEPTH)]

        # Creating the Output And Input Ports
        self._mem0_output_port = Bits(int=default_value, length=self._buffer_config.MEM0_BITWIDTH)
        self._mem1_output_port = Bits(int=default_value, length=self._buffer_config.MEM1_BITWIDTH)
        self._mem2_input_port  = Bits(int=default_value, length=self._buffer_config.MEM2_BITWIDTH)

    def execute_instruction(self, instruction : MemoryInstruction) -> None:
        # START IMPLEMENTATION
        opcode = instruction.get_opcode().uint
        if opcode == MI.READ:
            self._handle_read(instruction)
        elif opcode == MI.WRITE:
            self._handle_write(instruction)
        else: # for NOP
            pass
        # END IMPLEMENTATION
        return None

    def _handle_read(self, instruction : MemoryInstruction) -> None:
        # START IMPLEMENTATION
        mode = Mode.bitwidth(int(instruction.get_mode().uint))

        mema_offset = int(instruction.get_mema_offset().uint)
        memb_offset = int(instruction.get_memb_offset().uint)

        self._mem0_output_port = self._mem0[mema_offset]
        
        if mode == 32:
            self._mem1_output_port = self._mem1[memb_offset]
        elif mode == 16:
            base = memb_offset >> 1
            sel  = memb_offset & 1
            word = self._mem1[base]
            half = word[:16] if sel == 1 else word[-16:]
            self._mem1_output_port = Bits().join([half, half])
        elif mode == 8:
            base = memb_offset >> 2
            sel  = memb_offset & 3
            word = self._mem1[base]
            bytes_msb_to_lsb = list(word.cut(8))  
            piece = bytes_msb_to_lsb[3 - sel]     
            self._mem1_output_port = Bits().join([piece, piece, piece, piece])

        # END IMPLEMENTATION
        return None

    def _handle_write(self, instruction : MemoryInstruction) -> None:
        # START IMPLEMENTATION
        # This instruction indicates that the output data from the PEs should be written to MEM2 at the address pointed to by MemAOffset.
        addr = instruction.get_mema_offset().uint
        self._mem2[addr] = self._mem2_input_port
        # END IMPLEMENTATION
        return None

    def read_mem0_output(self) -> Bits:
        return self._mem0_output_port

    def read_mem1_output(self) -> Bits:
        return self._mem1_output_port

    def write_mem2_output(self, value : Bits) -> None:
        self._mem2_input_port = value

    def set_mem0(self, mem : list[int]) -> None:
        # Ensuring the Memory List is the Proper Length and Writing
        if len(mem) != self._buffer_config.MEM0_DEPTH:
            raise ValueError(f"Length of Memory [{len(mem)}] is incorrect for depth [{self._buffer_config.MEM0_DEPTH}] ")
        self._mem0 = [Bits(int=elem, length=self._buffer_config.MEM0_BITWIDTH) for elem in mem]

    def set_mem1(self, mem : list[int]) -> None:
        # Ensuring the Memory List is the Proper Length and Writing
        if len(mem) != self._buffer_config.MEM1_DEPTH:
            raise ValueError(f"Length of Memory [{len(mem)}] is incorrect for depth [{self._buffer_config.MEM1_DEPTH}] ")
        self._mem1 = [Bits(int=elem, length=self._buffer_config.MEM1_BITWIDTH) for elem in mem]

    def set_mem0_bits(self, mem : list[Bits]) -> None:
        # Ensuring the Memory List is the Proper Length and Writing
        if len(mem) != self._buffer_config.MEM0_DEPTH:
            raise ValueError(f"Length of Memory [{len(mem)}] is incorrect for depth [{self._buffer_config.MEM0_DEPTH}] ")
        self._mem0 = mem

    def set_mem1_bits(self, mem : list[Bits]) -> None:
        # Ensuring the Memory List is the Proper Length and Writing
        if len(mem) != self._buffer_config.MEM1_DEPTH:
            raise ValueError(f"Length of Memory [{len(mem)}] is incorrect for depth [{self._buffer_config.MEM1_DEPTH}] ")
        self._mem1 = mem

    def read_mem2(self) -> list[int]:
        return [elem.int for elem in self._mem2]

    def read_mem2_bits(self) -> list[Bits]:
        return self._mem2