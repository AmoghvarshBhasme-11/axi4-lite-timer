# AXI4-Lite Timer Peripheral

32-bit data / 8-bit address **AXI4-Lite slave timer** in Verilog, designed and verified in **Xilinx Vivado** with a self-checking testbench.

## Why this project

Demonstrates how a CPU talks to a peripheral over **AXI4-Lite** — not only standalone RTL:

- VALID / READY handshakes on write and read channels
- Register map with clear access rules
- **OKAY**, **SLVERR**, and **DECERR** responses

## Features

| Item | Detail |
|------|--------|
| Write path | AW → W → B |
| Read path | AR → R |
| `0x00` CTRL | `[0]` enable, `[1]` clear |
| `0x04` LOAD | Load value (R/W) |
| `0x08` COUNT | Free-running counter (**read-only**) |
| `0x0C` STATUS | `[0]` overflow flag (**W1C**) |
| Responses | OKAY / SLVERR (write to COUNT) / DECERR (bad address) |
| FSM | `IDLE` · `WRITE_ACCEPT` · `WRITE_RESP` · `READ_RESP` |

## Tools

- **Vivado** (XSim behavioral simulation)
- Pure **Verilog** (no UVM)

## Repository layout

```text
axi4-lite-timer/
├── README.md
├── src/
│   ├── axilitetimer.v   # AXI4-Lite timer slave (module: axi_timer)
│   └── tbaxi.v          # Self-checking testbench (module: tb_axi_timer)
└── results/
    ├── wave_write_channel.png
    └── wave_read_channel.png
```

## How to run

1. Create a Vivado RTL project and add `src/axilitetimer.v`
2. Add `src/tbaxi.v` as a simulation source
3. Set simulation top to `tb_axi_timer`
4. **Run Behavioral Simulation**
5. Confirm the Tcl console shows `ALL TESTS PASSED`

## Test coverage

1. Write / read LOAD
2. Enable timer via CTRL
3. Read COUNT (counting)
4. Write COUNT → **SLVERR**
5. Invalid address (`0x20`) → **DECERR**
6. Clear COUNT via CTRL `[1]`
7. STATUS read + W1C write

## Simulation results

Full self-checking run finished at **~635 ns** (`$finish`).

### Write channel (AW / W / B)

![Write channel waveform](results/wave_write_channel.png)

BRESP values: `0` = OKAY, `2` = SLVERR, `3` = DECERR.

### Read channel (AR / R)

![Read channel waveform](results/wave_read_channel.png)

RDATA shows LOAD=`5`, COUNT increasing, and `errors = 0`.

## What I learned

- AXI4-Lite channel roles and VALID/READY rules
- Address decode must use enough bits (partial `[3:0]` decode made `0x20` look like `0x00`)
- Self-checking testbenches beat “stare at waves only”
- Separating protocol FSM from timer datapath keeps the design clear

## Author

**Amogh** — ECE / VLSI
