from bitstring import Bits, BitArray
from .instruction import ProcessingElementInstruction, PEI
from dataclasses import dataclass

@dataclass
class ProcessingElementConfiguration:
    INPUT_BITWIDTH        : int
    ACCUMULATION_BITWIDTH : int
    OUTPUT_BITWIDTH       : int

class ProcessingElement:

    def __init__(
        self,
        config : ProcessingElementConfiguration,
        default_value = 0
    ):

        # Saving Inputs
        self._config = config

        # Creating Bitstrings
        self._input_a_value = Bits(int=default_value, length=self._config.INPUT_BITWIDTH)
        self._input_b_value = Bits(int=default_value, length=self._config.INPUT_BITWIDTH)
        self._acc_value     = Bits(int=default_value, length=self._config.ACCUMULATION_BITWIDTH)
        self._output_value  = Bits(int=default_value, length=self._config.OUTPUT_BITWIDTH)

    def input_a(self, value : Bits) -> None:
        self._input_a_value = value

    def input_b(self, value : Bits) -> None:
        self._input_b_value = value

    # Handling Each Instruction
    def execute_instruction(self, instruction : ProcessingElementInstruction) -> None:
        # START IMPLEMENTATION
        opcode = instruction.get_opcode().uint
        if opcode == PEI.NO_VALUE:
            value = instruction.get_value().uint
            if value == PEI.MAC:
                self._handle_mac(instruction)
            elif value == PEI.NOP:
                pass 
            elif value == PEI.OUT:
                self._handle_out(instruction)
            elif value == PEI.PASS:
                self._handle_pass(instruction)
            elif value == PEI.CLR:
                self._handle_clr(instruction)
        else:
            self._handle_rnd(instruction)
        # END IMPLEMENTATION
        return None

    # defined helper function here:
    def get_indices(self, channel_num, total_bw, mode, num_channels):
        channel_width = total_bw // (num_channels)
        start = total_bw - (channel_num + 1) * channel_width
        end =  total_bw - (channel_num) * channel_width
        return start, end

    def _handle_mac(self, instruction : ProcessingElementInstruction):
        # START IMPLEMENTATION
        mode = instruction.get_mode_bitwidth()
        num_channels = self._config.OUTPUT_BITWIDTH // mode 
        vacc_width = self._config.ACCUMULATION_BITWIDTH // num_channels
        mask = (1 << mode) - 1 # gets us the correct bits so we don't overflow

        for i in range(num_channels):
            a_val = self._input_a_value[i * mode : i * mode + mode].int
            b_val = self._input_b_value[i * mode : i * mode + mode].int
            acc_val = self._acc_value[i * vacc_width : i * vacc_width + vacc_width].int
            final_val = acc_val + a_val * b_val
            self._acc_value._overwrite(BitArray(int=final_val, length=vacc_width), i * vacc_width)
        # END IMPLEMENTATION
        return None

    def _handle_out(self, instruction : ProcessingElementInstruction):
        # START IMPLEMENTATION
        mode = instruction.get_mode_bitwidth()
        num_channels = self._config.OUTPUT_BITWIDTH // mode 
        vacc_width = self._config.ACCUMULATION_BITWIDTH // num_channels
        result = BitArray()

        for i in reversed(range(num_channels)):
            start, end = self.get_indices(i, self._config.ACCUMULATION_BITWIDTH, mode, num_channels)
            acc_val = self._acc_value[start:end]
            result.append(BitArray(int=acc_val[-mode:].int, length=mode))
        
        if len(result) > self._config.OUTPUT_BITWIDTH:
            self._output_value = result[-self._config.OUTPUT_BITWIDTH:]
        else:
            self._output_value = result
        # END IMPLEMENTATION
        return None

    def _handle_pass(self, instruction : ProcessingElementInstruction):
        # START IMPLEMENTATION
        mode = instruction.get_mode_bitwidth()
        num_channels = self._config.OUTPUT_BITWIDTH // mode 
        vacc_width = self._config.ACCUMULATION_BITWIDTH // num_channels
        result = BitArray()

        for i in reversed(range(num_channels)):
            start, end = self.get_indices(i, self._config.INPUT_BITWIDTH, mode, num_channels)
            result.append(BitArray(int=self._input_a_value[start:end].int, length=vacc_width))

        self._acc_value = result
        # END IMPLEMENTATION
        return None

    def _handle_clr(self, instruction : ProcessingElementInstruction):
        # START IMPLEMENTATION
        self._acc_value = BitArray(uint=0, length=self._config.ACCUMULATION_BITWIDTH)
        self._output_value = BitArray(uint=0, length=self._config.OUTPUT_BITWIDTH)
        # END IMPLEMENTATION
        return None

    def _handle_rnd(self, instruction : ProcessingElementInstruction):
        # START IMPLEMENTATION
        shift_val = instruction.get_value().uint
        mode = instruction.get_mode_bitwidth()
        num_channels = self._config.OUTPUT_BITWIDTH // mode
        vacc_width = self._config.ACCUMULATION_BITWIDTH // num_channels

        for i in range(num_channels):
            start, end = self.get_indices(i, self._config.ACCUMULATION_BITWIDTH, mode, num_channels)
            acc_val = self._acc_value[start:end]
            acc_val = acc_val.__irshift__(shift_val)
            self._acc_value._overwrite(acc_val[-mode:], end - mode)
        # END IMPLEMENTATION
        return None

    def get_output(self) -> Bits:
        return self._output_value

    def get_accumulation(self) -> Bits:
        return self._acc_value
