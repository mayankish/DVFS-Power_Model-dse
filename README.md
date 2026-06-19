# DVFS-Aware Power Model & Design-Space Explorer — 8x8 INT8 Systolic MAC Array

## Overview

A MATLAB/Simulink power and design-space-exploration (DSE) model for a
DVFS-controlled INT8 systolic MAC array. It estimates dynamic and leakage
power from real, characterized 180nm standard-cell data, sweeps a 5-level
DVFS voltage/frequency policy implemented as a Stateflow chart, and produces
a power-vs-throughput Pareto front — the kind of architecture-level PPA
trade-off analysis a system-modeling role at Infineon would run before RTL
exists.

This project extends two existing RTL portfolio projects —
`8x8_systolic_MAC-ARRAY` and `CMOS-StdCell-Library` — by combining the real
array's documented dataflow timing with the real library's characterized
180nm cell energy/leakage/delay data, and adding a DVFS control policy and
DSE sweep that neither source project has.

## Architecture

```
parse_liberty.m  -->  pe_characterize.m  -->  dvfs_levels.m
 (real .lib data)      (gate-equivalent        (5-point V/F sweep,
                        PE energy/leakage/       alpha-power law,
                        f_max model)             anchored on TT)
                                |
workload_generator.m -->  job_activity_trace.m   (per-cycle active-PE
 (synthetic matmul          (real RTL dataflow     count, from real
  job sequence)               timing model)         skewed-feed timing)
                                |
                          run_dse.m  -->  results/*.csv  -->  plot_results.m  -->  results/*.png

simulink/build_simulink_model.m  -->  dvfs_systolic_model.slx
   (Stateflow DVFS-level-selection / clock-gating controller,
    driven by job_pending + utilization, used as the policy
    this project's power model evaluates)
```

- **parse_liberty.m** reads the real characterized Liberty files
  (`data/liberty/cells_180nm_{TT,SS,FF}.lib`, produced by
  `03_cmos_cell_library/char/characterize.py`) and extracts area, leakage
  power, pin capacitance, and `cell_rise` delay for the 7 cells used here.
- **pe_characterize.m** combines those real numbers with a documented
  gate-equivalent decomposition of one systolic-array PE's datapath
  (`pe_gate_counts.m`) to estimate per-PE dynamic energy/cycle, leakage
  power, and maximum clock frequency.
- **dvfs_levels.m** derives a 5-point voltage/frequency sweep analytically
  from that nominal characterization (CV² dynamic scaling, linear leakage
  scaling, alpha-power-law frequency scaling).
- **workload_generator.m** / **job_activity_trace.m** generate a synthetic
  sequence of matmul jobs and, for each, a per-cycle active-PE-count trace
  derived from the real array's documented skewed-feed dataflow timing
  (`systolic_mac_array/README.md`).
- **run_dse.m** replays the same workload trace at every DVFS level and
  integrates energy over time to get average power, latency, and
  throughput per level; **plot_results.m** turns that into the Pareto
  front and utilization plots.
- **simulink/build_simulink_model.m** programmatically builds a Simulink
  model with a Stateflow chart implementing the DVFS-level-selection /
  clock-gating policy (IDLE → clock-gated/level 1; ACTIVE → level chosen
  from measured utilization).

## Tech Stack

- MATLAB (base, no toolboxes required for `matlab/*.m`)
- Simulink + Stateflow (for `simulink/build_simulink_model.m` and the
  resulting `.slx` model)
- Real characterized 180nm Liberty data from
  [CMOS-StdCell-Library](https://github.com/mayankish) (`cells_180nm_{TT,SS,FF}.lib`)
- Real RTL dataflow semantics from
  [8x8_systolic_MAC-ARRAY](https://github.com/mayankish) (`mac_array_top.v`, `README.md`)

## Repo Structure

```
data/liberty/              Real characterized 180nm Liberty corners (copied verbatim)
  cells_180nm_TT.lib          Typical-Typical, 25°C, 1.80V
  cells_180nm_SS.lib          Slow-Slow, 125°C, 1.62V
  cells_180nm_FF.lib          Fast-Fast, -40°C, 1.98V
matlab/
  parse_liberty.m             Liberty file parser (area/leakage/cap/delay)
  pe_gate_counts.m            Architectural gate-equivalent PE decomposition
  pe_characterize.m           Per-PE energy/leakage/f_max from Liberty + gate counts
  dvfs_levels.m               5-point DVFS V/F sweep (alpha-power law)
  workload_generator.m        Synthetic INT8 matmul job sequence generator
  job_activity_trace.m        Per-cycle active-PE trace from real dataflow timing
  run_dse.m                   Top-level DSE sweep -> results/*.csv
  plot_results.m              Generates results/*.png from the CSVs
  run_all.m                   Convenience wrapper (run_dse + plot_results)
simulink/
  build_simulink_model.m      Builds dvfs_systolic_model.slx programmatically
results/                     Real, executed output (see Results)
docs/                        Supplementary notes
LICENSE
```

## Setup & Build

Requires MATLAB (R2020a+ recommended) for `matlab/*.m`. Simulink + Stateflow
are required only for `simulink/build_simulink_model.m`.

```matlab
cd matlab
```

No build/compile step — this is interpreted MATLAB, no toolboxes beyond
base MATLAB needed for the power/DSE model.

## How to Run

```matlab
cd matlab
run_all            % runs run_dse.m then plot_results.m
```

This writes `results/dse_sweep.csv`, `results/job_trace_example.csv`,
`results/pvt_corner_leakage.csv`, and three PNGs
(`pareto_power_vs_throughput.png`, `pe_activity_timeline.png`,
`pvt_leakage_comparison.png`).

To (re)build the Simulink/Stateflow DVFS controller model:

```matlab
cd simulink
build_simulink_model
```

This produces `dvfs_systolic_model.slx` in `simulink/`.

## Results

**Pending real execution.** The code above is complete and was authored and
hand-traced against the real Liberty numbers for plausibility (see Data
Sources / Assumptions), but this repository was built in an environment
without a licensed MATLAB/Simulink/Stateflow install to run it. The actual
`results/*.csv` and `results/*.png` files, and the `simulink/*.slx` model,
will be generated by running the commands above and committed once
available — no numbers are hand-entered here in their place.

Expected outputs once run:

| File | Content |
|---|---|
| `results/dse_sweep.csv` | Voltage, frequency, avg power, energy, latency, throughput — one row per DVFS level |
| `results/job_trace_example.csv` | Per-cycle active-PE-count trace for one representative job |
| `results/pvt_corner_leakage.csv` | Real per-PE leakage power at the SS/TT/FF corners (cross-check, independent of the analytical DVFS scaling) |
| `results/pareto_power_vs_throughput.png` | Power-vs-throughput Pareto front across the 5 DVFS levels |
| `results/pe_activity_timeline.png` | Active-PE-count over time for one job |
| `results/pvt_leakage_comparison.png` | Bar chart of real leakage across the 3 PVT corners |
| `simulink/dvfs_systolic_model.slx` | The built Stateflow DVFS/clock-gating controller model |

## Data Sources / Assumptions

- **Cell area, leakage power, pin capacitance, and `cell_rise` delay** are
  parsed directly from the real characterized Liberty files in
  `data/liberty/` (produced by `03_cmos_cell_library/char/characterize.py`).
  Nothing in `parse_liberty.m`'s output is hand-entered.
- **PE gate-equivalent decomposition** (`pe_gate_counts.m`) is an
  architectural proxy, not a synthesized netlist: an 8x8 array multiplier
  (64 partial-product AND gates + 56 ripple full adders) plus a 32-bit
  ripple-carry accumulator (32 full adders), each full adder counted as
  2×XOR2 + 2×AND2 + 1×OR2. This is a standard textbook gate count, stated
  explicitly because it is an estimate, not RTL-synthesis output.
- **Activity factor of 1 toggle/gate/active-MAC-cycle** is a simplifying,
  worst-case assumption (`pe_characterize.m`). A real design's toggle rate
  is lower and data-dependent — this is exactly what the companion
  Activity-Based PPA Estimation project measures from real VCD traces
  instead of assuming.
- **DVFS voltage/frequency sweep** (`dvfs_levels.m`) is derived
  analytically from the single real TT-corner (1.80V) characterization
  using standard scaling laws — CV² for dynamic energy, linear-in-V for
  leakage, and the alpha-power law (Vth=0.45V, alpha=1.3, both assumed
  typical 180nm constants, not characterized by this library) for
  frequency. The Liberty data does characterize 3 real PVT corners
  (SS 1.62V/125°C, TT 1.80V/25°C, FF 1.98V/-40°C); their real leakage
  values are reported separately in `pvt_corner_leakage.csv` as a
  cross-check, but are not used as the DVFS sweep itself since each corner
  conflates voltage with process and temperature.
- **Per-cycle PE activity during a job** (`job_activity_trace.m`) is
  derived from the real array's documented skewed-feed dataflow timing
  (`systolic_mac_array/README.md`), but conservatively treats all 64 PEs
  as active for the full fill+stream+drain window, over-counting the true
  diagonal-wavefront activity at the first/last (N-1) cycles of each job.
- **Workload (job sizes, idle gaps)** is synthetic, generated by
  `workload_generator.m` — no real instruction/activity trace exists for
  this RTL. Same honesty stance as Project 1's CPU/DMA traffic generator.
- **Weight-load-phase energy** uses the same per-PE dynamic energy figure
  as a full MAC cycle, which over-estimates load-phase power (the real
  weight-load operation only toggles the weight register, not the full
  multiply-add datapath).
- **Stateflow DVFS/clock-gating policy** (utilization thresholds at
  0.2/0.4/0.6/0.8) is an illustrative control policy authored for this
  project, not derived from a reference DVFS controller.

## JD Requirement Mapping

| Infineon JD requirement | Where this project addresses it |
|---|---|
| System-level power/performance modeling | `pe_characterize.m` + `dvfs_levels.m` + `run_dse.m` |
| DVFS / low-power design awareness | Stateflow DVFS-level-selection + clock-gating controller (`simulink/build_simulink_model.m`) |
| Bridging RTL/cell-level detail to system-level estimation | Gate-equivalent PE model built on real Liberty data, not invented constants |
| Design-space exploration / PPA trade-off analysis | 5-point DVFS sweep, power-vs-throughput Pareto front (`plot_results.m`) |
| Tooling/automation mindset | Fully scripted MATLAB pipeline, `run_all.m` regenerates all results from scratch |

## Limitations & Future Work

- **No live MATLAB validation yet.** This repo's MATLAB/Simulink code was
  authored without access to a licensed MATLAB/Simulink/Stateflow session
  in the build environment; it has been hand-traced against the real
  Liberty numbers for physical plausibility, but not yet executed. Results
  and the `.slx` model are pending a real run (see Results).
- **Architectural gate-count power proxy, not synthesis-derived.** A real
  synthesis run (e.g., through `03_cmos_cell_library`'s flow) would give
  exact cell counts and a netlist-derived power number instead of the
  textbook multiplier/adder decomposition used here.
- **Fixed activity factor, not measured toggle rates.** See the companion
  Activity-Based PPA Estimation project for a VCD-derived alternative.
- **DVFS frequency scaling uses assumed (not characterized) Vth/alpha.**
  A real DVFS curve would come from silicon characterization or SPICE
  corner sweeps across multiple voltages at fixed temperature, which this
  library's 3-corner characterization does not provide.
- **Conservative (over-counted) fill/drain activity.** Exact per-PE
  activity during pipeline fill/drain would tighten the power estimate at
  small job sizes.
- **Single, illustrative DVFS policy.** A more realistic controller might
  use hysteresis, predictive utilization, or per-row/column clock gating
  rather than a single whole-array gate/ungate decision.

## License

MIT
