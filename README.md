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
├── rtl/
│   └── axi_timer.v          # AXI4-Lite timer slave
├── tb/
│   └── tb_axi_timer.v       # Self-checking AXI master testbench
└── results/
    ├── screenshots/         # Vivado waveform captures
    └── simulation_log.txt   # Optional console log
```

## How to run

1. Open the project in Vivado
2. Set simulation top to `tb_axi_timer`
3. **Run Behavioral Simulation**
4. Confirm the Tcl console shows `ALL TESTS PASSED`

## Test coverage

1. Write / read LOAD
2. Enable timer via CTRL
3. Read COUNT (counting)
4. Write COUNT → **SLVERR**
5. Invalid address (`0x20`) → **DECERR**
6. Clear COUNT via CTRL `[1]`
7. STATUS read + W1C write

## Simulation results

Waveforms from a full self-checking run (`$finish` at ~635 ns):

### Write channel (AW / W / B)

![Write channel waveform](results/screenshots/wave_write_channel.png)

Shows address/data phases, VALID/READY handshakes, and BRESP values:
- `0` = OKAY
- `2` = SLVERR (write to COUNT)
- `3` = DECERR (addr `0x20`)

### Read channel (AR / R) and testbench status

![Read channel waveform](results/screenshots/wave_read_channel.png)

Shows AR handshake, RDATA (e.g. LOAD=`5`, COUNT increasing), RRESP, and `errors=0`.

## What I learned

- AXI4-Lite channel roles and VALID/READY rules
- Address decode must use enough bits (partial `[3:0]` decode made `0x20` look like `0x00`)
- Self-checking testbenches beat “stare at waves only”
- Separating protocol FSM from timer datapath keeps the design clear

## Author

**Amogh** — ECE / VLSI
