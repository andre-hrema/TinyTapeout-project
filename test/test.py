import os
import cocotb
import enum
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock


CLOCK_PERIOD_NS = 10

ASSERT = True
if "NOASSERT" in os.environ:
    ASSERT = False

class MemCtl(enum.Enum):
    MEM_IDLE = 0
    MEM_STORE = 1
    MEM_LOAD = 2
    MEM_CLEAR = 3

class DpeStatus(enum.Enum):
    DPE_IDLE = 0
    DPE_IN_PROGRESS = 1
    DPE_RESULT_AVAILABLE = 2
    DPE_INTERNAL_ERROR = 3

class CtlFSM(enum.Enum):
    CTL_IDLE         = 0
    CTL_WORK         = 1
    CTL_DEBUG        = 2
    CTL_READ_RESULT  = 3


def reset_module(function):
    async def wrapper(dut):
        cocotb.log.info(f"Starting {function.__name__}")

        # Start clock
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())

        # inverted reset logic
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        await function(dut)
    return wrapper

"""
# Testing all memory banks
@cocotb.test()
@reset_module
async def test_fsm_simple_calc_all_memories(dut):
    # Test the FSM module with a simple calculation

    MAX_ENTRIES = 12

    # Set control to CTL_WORK
    dut.ctl.value = 0x1
    await RisingEdge(dut.clk)
    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")


    for i in range(1,MAX_ENTRIES, 2):
        dut.data_in.value = ((i + 1) << 4) | i
        await RisingEdge(dut.clk)

    # Set control to CTL_IDLE to trigger RUN_MAC
    dut.ctl.value = 0x0
    await RisingEdge(dut.clk)

    # Move the FSM to WORK before changing to read-and-store mode.
    dut.ctl.value = CtlFSM.CTL_WORK.value
    await RisingEdge(dut.clk)

    second_input_array = [242, 227, 212, 197, 182, 167]

    # Read the first result while storing the next round during its calculation.
    dut.ctl.value = CtlFSM.CTL_READ_RESULT.value
    dut.data_in.value = second_input_array[0]
    await RisingEdge(dut.clk)

    # Feed with the second round
    # Firs result should be 322 and second 320
"""


# Testing all 12 entries
@cocotb.test()
@reset_module
async def test_fsm_simple_calc_6_pairs_entries(dut):
    #Test the FSM module with a simple calculation

    MAX_ENTRIES = 12

    # Set control to CTL_WORK
    dut.ctl.value = 0x1
    await RisingEdge(dut.clk)
    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")


    for i in range(1,MAX_ENTRIES, 2):
        dut.data_in.value = ((i + 1) << 4) | i
        await RisingEdge(dut.clk)
    
    # Set control to CTL_IDLE to trigger RUN_MAC
    dut.ctl.value = 0x0
    await RisingEdge(dut.clk)

    # Switch store memory to block 2 and 3
    await RisingEdge(dut.clk)

    # calculation period
    for i in range(0,MAX_ENTRIES-1,2):
        await RisingEdge(dut.clk)
        assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"


    # Feeding MAC with stored values 1 and 2 and reading stored values 3 and 4
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"

    # Feeding MAC with stored values 3 and 4
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # done == 1
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_RESULT_AVAILABLE.value, f"status should be DPE_RESULT_AVAILABLE (2), got {dut.status.value}"

    dut.ctl.value = CtlFSM.CTL_READ_RESULT.value
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.data_out.value == 322


@cocotb.test()
@reset_module
async def test_fsm_simple_calc_a(dut):
    #Test the FSM module with a simple calculation

    # Set control to CTL_WORK
    dut.ctl.value = 0x1
    await RisingEdge(dut.clk)
    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")

    # input 2 and 1
    dut.data_in.value = 33
    await RisingEdge(dut.clk)

    # input 4 and 3
    dut.data_in.value = 67
    await RisingEdge(dut.clk)
    
    # Set control to CTL_IDLE to trigger RUN_MAC
    dut.ctl.value = 0x0
    await RisingEdge(dut.clk)

    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")
    # Switch store memory to block 2 and 3
    await RisingEdge(dut.clk)
    
    # MAC fed with 1 and 2
    await RisingEdge(dut.clk)


    # MAC fed with 3 and 4
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"

    # Stop feeding mac
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"

    # Feeding MAC with stored values 3 and 4
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # done == 1
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_RESULT_AVAILABLE.value, f"status should be DPE_RESULT_AVAILABLE (2), got {dut.status.value}"
    dut.ctl.value = CtlFSM.CTL_READ_RESULT.value
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.data_out.value == 14


@cocotb.test()
@reset_module
async def test_fsm_simple_calc_b(dut):
    #Test the FSM module with a simple calculation

    # Set control to CTL_WORK
    dut.ctl.value = 0x1
    await RisingEdge(dut.clk)
    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")

    # input 5 and 4
    dut.data_in.value = 84
    await RisingEdge(dut.clk)

    # input 7 and 6
    dut.data_in.value = 118
    await RisingEdge(dut.clk)
    
    # Set control to CTL_IDLE to trigger RUN_MAC
    dut.ctl.value = 0x0
    await RisingEdge(dut.clk)

    sim_time = cocotb.utils.get_sim_time(units="ns")
    cocotb.log.info(f"Simulation time: {sim_time} ns")
    # Switch store memory to block 2 and 3
    await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"


    # MAC fed with 6 and 7
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"

    # Stop feeding MAC
    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_IN_PROGRESS.value, f"status should be DPE_IN_PROGRESS (1), got {dut.status.value}"

    # Feeding MAC with stored values 3 and 4
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    assert dut.status.value == DpeStatus.DPE_RESULT_AVAILABLE.value, f"status should be DPE_RESULT_AVAILABLE (2), got {dut.status.value}"

    dut.ctl.value = CtlFSM.CTL_READ_RESULT.value
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.data_out.value == 62


# Test reset behavior of the FSM module
@cocotb.test()
@reset_module
async def test_fsm_reset(dut):
    # Test the FSM module

    # Check initial state
    assert dut.data_out.value == 0, f"result should be 0 after reset, got {dut.data_out.value}"
    assert dut.status.value == 0, f"status should be DPE_IDLE (0) after reset, got {dut.status.value}"
