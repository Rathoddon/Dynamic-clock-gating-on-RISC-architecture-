# Dynamic-clock-gating-on-RISC-architecture-

A 5-state multicycle RISC processor implemented in Verilog, with a dynamic
clock-gating variant designed to reduce dynamic power consumption by
disabling the clock to idle functional units (register file, data memory,
instruction register) during cycles where they perform no useful work.

## Overview

Multicycle RISC processors spend many clock cycles per instruction in
states where only a subset of the datapath is actually active — for
example, the register file only needs to be clocked during the writeback
state, and the data memory only during the memory-access state. In a
conventional design, every register in the datapath still toggles on
every clock edge regardless of whether it's doing useful work, which
wastes dynamic power.

This project implements **BUFGCE-based clock gating**, enabling each
gated block's clock only during the specific FSM states where it needs
to latch new data, and compares the resulting power dissipation against
an identically-functioning ungated baseline.

## Architecture

- **ISA**: custom RISC instruction set — ADD, SUB, MUL, AND, OR, XOR,
  NOT, SHL, SHR, LOAD, STORE, JUMP, BEQ, BNE
- **Datapath**: 5-state FSM (fetch → decode → execute/branch-resolve →
  memory access → writeback), single register file, single ALU,
  separate instruction and data memories
- **Clock gating**: `BUFGCE` primitives gate the clock to the register
  file and data memory, enabled only during the FSM states that need
  them (writeback and memory-access respectively)

## Repository Contents

| File | Description |
|---|---|
| `Normal_clocked_risc.v` | Baseline RISC processor — all registers clocked on every cycle |
| `dynamic_clock_gating.v` | Clock-gated variant — register file and data memory clocks gated by FSM state |
| `testbench_normal_clocked.v` | Testbench for the baseline design |
| `testbench.v` | Testbench for the clock-gated design |
| `power report_normal clk.png` | Vivado power report — baseline design |
| `power report_clock gating.png` | Vivado power report — gated design |
| `transcript_normal clocked.png` | Simulation transcript — baseline design |
| `transcript_gated clock.png` | Simulation transcript — gated design |

## Results

| | Normal Clocked | Clock Gated |
|---|---|---|
| Estimated dynamic power | 0.29 W | 0.253 W |
| **Reduction** | — | **~12.75%** |

Power figures are Vivado's post-implementation power estimate, derived
from switching activity captured during simulation of the same test
program on both designs. See `power report_normal clk.png` and
`power report_clock gating.png` for the full reports.

## How to Reproduce

1. Open Vivado and create a new RTL project.
2. Add `Normal_clocked_risc.v` (or `dynamic_clock_gating.v`) as a design
   source, and the matching testbench as a simulation source.
3. Add `program.mem` (instruction memory contents) to the project.
4. Run behavioral simulation and confirm the transcript output.
5. Run **Synthesis**, then **Implementation**.
6. Open the **Power Report** (Flow Navigator → Implementation → Report
   Power) to view estimated dynamic/static power dissipation.
7. Repeat for the other variant and compare.

## Key Design Notes

- Clock gates use Vivado's `BUFGCE` primitive rather than hand-built
  latch-based gating cells, to avoid simulation/synthesis timing
  mismatches.
- Gating enables are derived from registered FSM state, not from
  same-cycle combinational signals that update on the same edge they're
  read — this avoids race conditions between the gating enable and the
  data it's meant to protect.
- Both designs were verified against the same instruction sequence
  (LOAD, ADD, BEQ, BNE, STORE, JUMP) to confirm functional equivalence
  before comparing power.

## Learnings

- Clock gating trades a small amount of control complexity for a
  measurable reduction in dynamic power, by eliminating unnecessary
  switching activity in registers that aren't performing useful work
  on a given cycle.
- Gating logic must be derived carefully with respect to the FSM's
  own timing — an enable signal that changes on the same edge it's
  meant to gate can silently corrupt data rather than simply fail to
  save power.
- Power estimates from synthesis tools reflect the specific switching
  activity of the simulated workload; a longer, more instruction-diverse
  test program gives a more representative estimate than a short one.

## Future Work

- Operand isolation on the ALU to reduce combinational switching
  during cycles where its result isn't consumed.
- Extending clock gating to the instruction register, gated tightly to
  the fetch state only.
- Re-evaluating power savings on a longer, more instruction-diverse
  test program.
