from src.processing_element import ProcessingElement, ProcessingElementConfiguration
from src.instruction import ProcessingElementInstruction, ProcessingElementInstructionConfiguration, MemoryInstructionConfiguration, InstConfig
from src.assembler import Assembler
import sys
from bitstring import Bits


def main():

    # Testing Processing Element
    errors = 0
    errors += test_mac_int32()
    errors += test_pass_int32()
    errors += test_rnd_int32()
    errors += test_clr_int32()
    errors += test_mac_int16()
    errors += test_pass_int16()
    errors += test_rnd_int16()
    errors += test_clr_int16()
    errors += test_mac_int8()
    errors += test_pass_int8()
    errors += test_rnd_int8()
    errors += test_clr_int8()
    # Additional edge tests
    errors += test_out_int16_output_width_64()
    errors += test_rnd_int16_updates_full_lane()
    errors += test_out_int8_output_width_64()
    errors += test_out_int8_output_width_16()
    errors += test_nop_int16_no_change()
    errors += test_mac_int16_two_cycles()
    errors += test_mac_int16_overflow_wrap()
    errors += test_pass_int8_sign_extend()
    errors += test_rnd_int16_shift_bounds()
    errors += test_out_int8_lane_order()

    # Determining the Status of All Tests
    if errors == 0:
        print("All Tests Passed!")
    else:
        print(f"{errors} Tests Failed!")
    sys.exit(errors)


def test_mac_int32() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs

    a_value = Bits(int=15,length=32)
    b_value = Bits(int=-6,length=32)

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT32",
         "OUT INT32",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0xffffffA6", length=32):
        print("INT32 MAC Test Passed.")
        return 0
    else:
        print(f"INT32 MAC Test Failed.  Value was {test_pe.get_output()}")
        return 1
    
def test_pass_int32() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits(int=15,length=32)
    b_value = Bits(int=-6,length=32)

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT32",
         "OUT INT32",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0x0000000f", length=32):
        print("INT32 PASS Test Passed.")
        return 0
    else:
        print(f"INT32 PASS Test Failed. Value Was {test_pe.get_output()}.")
        return 1
    
def test_rnd_int32() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits(int=15,length=32)
    b_value = Bits(int=-6,length=32)

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT32",
         "RND INT32 2",
         "OUT INT32",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0x00000003", length=32):
        print("INT32 RND Test Passed.")
        return 0
    else:
        print(f"INT32 RND Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_clr_int32() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits(int=15,length=32)
    b_value = Bits(int=-6,length=32)

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT32",
         "OUT INT32",
         "CLR INT32"
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if (test_pe.get_output() == Bits(uint=0, length=32)) and (test_pe.get_accumulation() == Bits(uint=0, length=64)):
        print("INT32 CLR Test Passed.")
        return 0
    else:
        print(f"INT32 CLR Test Failed.  Value was {test_pe.get_output()}")
        return 1


def test_mac_int16() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs

    a_value = Bits().join([
        Bits(int=-15,length=16),
        Bits(int=7,length=16)
    ])
    b_value = Bits().join([
        Bits(int=8,length=16),
        Bits(int=3,length=16)
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT16",
         "OUT INT16",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0xff880015", length=32):
        print("INT16 MAC Test Passed.")
        return 0
    else:
        print(f"INT16 MAC Test Failed.  Value was {test_pe.get_output()}")
        return 1
    
def test_pass_int16() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs

    a_value = Bits().join([
        Bits(int=-15,length=16),
        Bits(int=7,length=16)
    ])
    b_value = Bits().join([
        Bits(int=8,length=16),
        Bits(int=3,length=16)
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT16",
         "OUT INT16",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0xfff10007", length=32):
        print("INT16 PASS Test Passed.")
        return 0
    else:
        print(f"INT16 PASS Test Failed, Value Was {test_pe.get_output()}.")
        return 1
    
def test_rnd_int16() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs

    a_value = Bits().join([
        Bits(hex="ABCD",length=16),
        Bits(hex="EF00",length=16)
    ])
    b_value = Bits().join([
        Bits(int=8,length=16),
        Bits(int=3,length=16)
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT16",
         "RND INT16 8",
         "OUT INT16",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0xffABffEF", length=32):
        print("INT16 RND Test Passed.")
        return 0
    else:
        print(f"INT16 RND Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_clr_int16() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs

    a_value = Bits().join([
        Bits(int=-15,length=16),
        Bits(int=7,length=16)
    ])
    b_value = Bits().join([
        Bits(int=8,length=16),
        Bits(int=3,length=16)
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT16",
         "OUT INT16",
         "CLR INT16"
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if (test_pe.get_output() == Bits(uint=0, length=32)) and (test_pe.get_accumulation() == Bits(uint=0, length=64)):
        print("INT16 CLR Test Passed.")
        return 0
    else:
        print(f"INT16 CLR Test Failed.  Value was {test_pe.get_output()}")
        return 1


def test_mac_int8() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    b_value = Bits().join([
        Bits(int=10,length=8),
        Bits(int=10,length=8),
        Bits(int=-8,length=8),
        Bits(int=-8,length=8),
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT8",
         "OUT INT8",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0x32cee818", length=32):
        print("INT8 MAC Test Passed.")
        return 0
    else:
        print(f"INT8 MAC Test Failed.  Value was {test_pe.get_output()}")
        return 1
    
def test_pass_int8() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    b_value = Bits().join([
        Bits(int=10,length=8),
        Bits(int=10,length=8),
        Bits(int=-8,length=8),
        Bits(int=-8,length=8),
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT8",
         "OUT INT8",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0x05fb03fd", length=32):
        print("INT8 PASS Test Passed.")
        return 0
    else:
        print(f"INT8 PASS Test Failed, Value Was {test_pe.get_output()}.")
        return 1
    
def test_rnd_int8() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    b_value = Bits().join([
        Bits(int=10,length=8),
        Bits(int=10,length=8),
        Bits(int=-8,length=8),
        Bits(int=-8,length=8),
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "PASS INT8",
         "RND INT8 1",
         "OUT INT8",
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if test_pe.get_output() == Bits(hex="0x02fd01fe", length=32):
        print("INT8 RND Test Passed.")
        return 0
    else:
        print(f"INT8 RND Test Failed, Value Was {test_pe.get_output()}.")
        return 1

def test_clr_int8() -> int:

    # Creating a Test PE Configuration
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=(32*2),
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Loading the Inputs
    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    b_value = Bits().join([
        Bits(int=10,length=8),
        Bits(int=10,length=8),
        Bits(int=-8,length=8),
        Bits(int=-8,length=8),
    ])

    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    # Instruction List
    inst_list = [
         "MAC INT8",
         "OUT INT8",
         "CLR INT8"
    ]

    # Assembling Instruction
    insts = [assemble_test_instruction(elem) for elem in inst_list]

    # Executing the Instruction
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Reporting Whether the Test Passed or Failed
    if (test_pe.get_output() == Bits(uint=0, length=32)) and (test_pe.get_accumulation() == Bits(uint=0, length=64)):
        print("INT8 CLR Test Passed.")
        return 0
    else:
        print(f"INT8 CLR Test Failed.  Value was {test_pe.get_output()}")
        return 1


def test_out_int16_output_width_64() -> int:
    # Verifies lane count is derived from INPUT_BITWIDTH, not OUTPUT_BITWIDTH
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,
        OUTPUT_BITWIDTH=64
    )
    test_pe = ProcessingElement(pe_test_config)

    # Inputs: two 16-bit values
    a_value = Bits().join([
        Bits(int=-15,length=16),  # MSB lane
        Bits(int=7,length=16)     # LSB lane
    ])
    b_value = Bits(uint=0,length=32)
    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    inst_list = [
         "PASS INT16",
         "OUT INT16",
    ]
    insts = [assemble_test_instruction(elem) for elem in inst_list]
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Expected: two 16-bit truncated lanes (MSB first) padded to 64 bits on the left
    expected_32 = Bits().join([
        Bits(int=-15,length=16),
        Bits(int=7,length=16)
    ])
    expected_64 = Bits().join([
        Bits(uint=0,length=32),
        expected_32
    ])

    if test_pe.get_output() == expected_64:
        print("INT16 OUT with OUTPUT_BITWIDTH=64 Test Passed.")
        return 0
    else:
        print(f"INT16 OUT with OUTPUT_BITWIDTH=64 Test Failed. Value Was {test_pe.get_output()}.")
        return 1


def test_rnd_int16_updates_full_lane() -> int:
    # Verifies RND shifts the entire accumulation lane (not only low mode bits)
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,  # two lanes of 32
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    # Load inputs
    a_value = Bits().join([
        Bits(hex="ABCD",length=16),  # MSB lane (negative)
        Bits(hex="EF00",length=16)   # LSB lane (negative)
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    inst_list = [
         "PASS INT16",
         "RND INT16 8",
    ]
    insts = [assemble_test_instruction(elem) for elem in inst_list]
    for elem in insts:
        test_pe.execute_instruction(elem)

    # Expected accumulation after PASS then arithmetic >> 8 on each 32-bit lane
    msb_lane = Bits(int=Bits(hex="ABCD", length=16).int, length=32).int >> 8
    lsb_lane = Bits(int=Bits(hex="EF00", length=16).int, length=32).int >> 8
    expected_acc = Bits().join([
        Bits(int=msb_lane, length=32),
        Bits(int=lsb_lane, length=32)
    ])

    if test_pe.get_accumulation() == expected_acc:
        print("INT16 RND updates full accumulation lane Test Passed.")
        return 0
    else:
        print(f"INT16 RND updates full lane Test Failed. Acc Was {test_pe.get_accumulation()}.")
        return 1

def test_out_int8_output_width_64() -> int:
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,
        OUTPUT_BITWIDTH=64
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    inst_list = [
         "PASS INT8",
         "OUT INT8",
    ]
    insts = [assemble_test_instruction(elem) for elem in inst_list]
    for elem in insts:
        test_pe.execute_instruction(elem)

    expected_32 = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    expected_64 = Bits().join([Bits(uint=0,length=32), expected_32])
    if test_pe.get_output() == expected_64:
        print("INT8 OUT with OUTPUT_BITWIDTH=64 Test Passed.")
        return 0
    else:
        print(f"INT8 OUT with OUTPUT_BITWIDTH=64 Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_out_int8_output_width_16() -> int:
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,
        OUTPUT_BITWIDTH=16
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=5,length=8),
        Bits(int=-5,length=8),
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    inst_list = [
         "PASS INT8",
         "OUT INT8",
    ]
    insts = [assemble_test_instruction(elem) for elem in inst_list]
    for elem in insts:
        test_pe.execute_instruction(elem)

    expected_16 = Bits().join([
        Bits(int=3,length=8),
        Bits(int=-3,length=8),
    ])
    if test_pe.get_output() == expected_16:
        print("INT8 OUT with OUTPUT_BITWIDTH=16 Test Passed.")
        return 0
    else:
        print(f"INT8 OUT with OUTPUT_BITWIDTH=16 Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_nop_int16_no_change() -> int:
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=-1,length=16),
        Bits(int=2,length=16)
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    insts = [assemble_test_instruction(elem) for elem in [
        "PASS INT16",
        "OUT INT16",
        "NOP INT16"
    ]]
    before_acc = None
    before_out = None
    for idx, inst in enumerate(insts):
        test_pe.execute_instruction(inst)
        if idx == 1:
            before_acc = test_pe.get_accumulation()
            before_out = test_pe.get_output()
    if (test_pe.get_accumulation() == before_acc) and (test_pe.get_output() == before_out):
        print("INT16 NOP no-change Test Passed.")
        return 0
    else:
        print("INT16 NOP no-change Test Failed.")
        return 1

def test_mac_int16_two_cycles() -> int:
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=-15,length=16),
        Bits(int=7,length=16)
    ])
    b_value = Bits().join([
        Bits(int=8,length=16),
        Bits(int=3,length=16)
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    insts = [assemble_test_instruction(elem) for elem in [
        "MAC INT16",
        "MAC INT16",
        "OUT INT16"
    ]]
    for inst in insts:
        test_pe.execute_instruction(inst)

    expected = Bits().join([
        Bits(int=(-15*8*2), length=16),
        Bits(int=(7*3*2),   length=16)
    ])
    if test_pe.get_output() == expected:
        print("INT16 MAC two cycles Test Passed.")
        return 0
    else:
        print(f"INT16 MAC two cycles Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_mac_int16_overflow_wrap() -> int:
    # Force lane width to 16 bits so product wraps
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=32,   # two lanes of 16
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=32767,length=16),
        Bits(int=32767,length=16)
    ])
    b_value = Bits().join([
        Bits(int=32767,length=16),
        Bits(int=32767,length=16)
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(b_value)

    insts = [assemble_test_instruction(elem) for elem in [
        "MAC INT16",
        "OUT INT16"
    ]]
    for inst in insts:
        test_pe.execute_instruction(inst)

    expected = Bits().join([
        Bits(int=1, length=16),  # 0x0001 (wrap of 0x3FFF0001 low 16 bits)
        Bits(int=1, length=16)
    ])
    if test_pe.get_output() == expected:
        print("INT16 MAC overflow wrap Test Passed.")
        return 0
    else:
        print(f"INT16 MAC overflow wrap Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def test_pass_int8_sign_extend() -> int:
    # Ensure PASS sign-extends lane values into the accumulation width
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=128,  # four lanes of 32
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=-1,length=8),
        Bits(int=-2,length=8),
        Bits(int=1,length=8),
        Bits(int=-3,length=8),
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    insts = [assemble_test_instruction(elem) for elem in [
        "PASS INT8"
    ]]
    for inst in insts:
        test_pe.execute_instruction(inst)

    expected_acc = Bits().join([
        Bits(int=-1,length=32),
        Bits(int=-2,length=32),
        Bits(int=1,length=32),
        Bits(int=-3,length=32),
    ])
    if test_pe.get_accumulation() == expected_acc:
        print("INT8 PASS sign-extend Test Passed.")
        return 0
    else:
        print(f"INT8 PASS sign-extend Test Failed. Acc Was {test_pe.get_accumulation()}.")
        return 1

def test_rnd_int16_shift_bounds() -> int:
    # Shift by 0 (no change) and by a large value, verify arithmetic behavior
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,  # two lanes of 32
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=-256,length=16),  # negative value
        Bits(int=1024,length=16)
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    # PASS then RND by 0 (no change)
    test_pe.execute_instruction(assemble_test_instruction("PASS INT16"))
    before = test_pe.get_accumulation()
    test_pe.execute_instruction(assemble_test_instruction("RND INT16 0"))
    after0 = test_pe.get_accumulation()

    # Now large shift
    test_pe.execute_instruction(assemble_test_instruction("RND INT16 12"))
    afterN = test_pe.get_accumulation()

    # Expectations
    msb = Bits(int=-256, length=32).int >> 12
    lsb = Bits(int=1024, length=32).int >> 12
    expectedN = Bits().join([Bits(int=msb,length=32), Bits(int=lsb,length=32)])

    ok = (before == after0) and (afterN == expectedN)
    if ok:
        print("INT16 RND shift bounds Test Passed.")
        return 0
    else:
        print("INT16 RND shift bounds Test Failed.")
        return 1

def test_out_int8_lane_order() -> int:
    # Check OUT concatenation order is MSB lane first
    pe_test_config = ProcessingElementConfiguration(
        INPUT_BITWIDTH=32,
        ACCUMULATION_BITWIDTH=64,  # four lanes of 16 or two lanes of 32? for INT8: 4 lanes of 16
        OUTPUT_BITWIDTH=32
    )
    test_pe = ProcessingElement(pe_test_config)

    a_value = Bits().join([
        Bits(int=0x11,length=8),  # MSB byte
        Bits(int=0x22,length=8),
        Bits(int=0x33,length=8),
        Bits(int=0x44,length=8),  # LSB byte
    ])
    test_pe.input_a(a_value)
    test_pe.input_b(Bits(uint=0,length=32))

    test_pe.execute_instruction(assemble_test_instruction("PASS INT8"))
    test_pe.execute_instruction(assemble_test_instruction("OUT INT8"))

    expected = Bits().join([
        Bits(int=0x11,length=8),
        Bits(int=0x22,length=8),
        Bits(int=0x33,length=8),
        Bits(int=0x44,length=8),
    ])
    if test_pe.get_output() == expected:
        print("INT8 OUT lane order (MSB->LSB) Test Passed.")
        return 0
    else:
        print(f"INT8 OUT lane order Test Failed. Value Was {test_pe.get_output()}.")
        return 1

def assemble_test_instruction(
        test_inst_str : str,
        opcode_bitwidth=2,
        mode_bitwidth=2,
        value_bitwidth=5
    ) -> ProcessingElementInstruction:
        
        # Instruction Configuration
        inst_config = InstConfig(
            COUNT_BITWIDTH     = 10,
            MEMA_INC_BITWIDTH  = 1,
            MEMB_INC_BITWIDTH  = 1,
            MEMORY_INST_CONFIG = MemoryInstructionConfiguration(
                OPCODE_BITWIDTH      = 2,
                MODE_BITWIDTH        = 2,
                MEMA_OFFSET_BITWIDTH = 10,
                MEMB_OFFSET_BITWIDTH = 10
            ),
            PE_INST_CONFIG     = ProcessingElementInstructionConfiguration(
                OPCODE_BITWIDTH      = opcode_bitwidth,
                MODE_BITWIDTH        = mode_bitwidth,
                VALUE_BITWIDTH       = value_bitwidth
            )
        )

        assembler = Assembler(inst_config)
        return assembler.convert_pe_instruction(test_inst_str)

if __name__ == "__main__":
    main()
