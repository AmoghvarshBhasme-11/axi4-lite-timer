# Results

Vivado behavioral simulation waveforms.

| File | What it shows |
|------|----------------|
| `wave_write_channel.png` | ACLK, ARESETN, AWADDR/AWVALID/AWREADY, WDATA/WVALID/WREADY, BRESP/BVALID/BREADY |
| `wave_read_channel.png` | ARADDR/ARVALID/ARREADY, RDATA/RRESP/RVALID/RREADY, testbench `resp` and `errors` |

All self-checking tests passed. Simulation `$finish` at ~635 ns.
