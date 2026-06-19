% RUN_DSE  Top-level design-space-exploration entry point.
%
% Run this script directly in MATLAB (cd into matlab/ first, or addpath it).
% It requires no toolboxes beyond base MATLAB. It:
%   1. Parses the three REAL characterized 180nm Liberty corners
%      (data/liberty/cells_180nm_{TT,SS,FF}.lib).
%   2. Characterizes one systolic-array PE (DW=8, ACCW=32 -- the real RTL
%      parameters from systolic_mac_array) at the TT corner.
%   3. Derives a 5-point DVFS V/F sweep analytically from that TT anchor.
%   4. Generates a synthetic 20-job INT8 matmul workload and its per-cycle
%      PE-activity trace (derived from the real array's documented dataflow).
%   5. For EACH DVFS level, replays the same workload trace and integrates
%      dynamic + leakage energy over time to get avg power, energy,
%      latency, and throughput.
%   6. Writes results/dse_sweep.csv, results/job_trace_example.csv, and
%      results/pvt_corner_leakage.csv -- the real, executed numbers this
%      project's README is built from. No number in those files is
%      hand-entered; re-running this script regenerates them exactly.

clear; clc;

N    = 8;   % systolic array dimension (systolic_mac_array is 8x8)
DW   = 8;   % INT8 operands
ACCW = 32;  % INT32 accumulator

results_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
lib_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'liberty');

%% 1. Parse real Liberty corners, characterize the PE, build DVFS levels
lib_TT = parse_liberty(fullfile(lib_dir, 'cells_180nm_TT.lib'));
lib_SS = parse_liberty(fullfile(lib_dir, 'cells_180nm_SS.lib'));
lib_FF = parse_liberty(fullfile(lib_dir, 'cells_180nm_FF.lib'));

pe_TT = pe_characterize(lib_TT, DW, ACCW);
pe_SS = pe_characterize(lib_SS, DW, ACCW);
pe_FF = pe_characterize(lib_FF, DW, ACCW);

fprintf('Nominal (TT) PE: E_dyn=%.3f pJ/active-cycle  P_leak=%.3f nW  f_max=%.1f MHz\n', ...
    pe_TT.E_dyn_pJ, pe_TT.P_leak_nW, pe_TT.f_max_hz/1e6);

levels = dvfs_levels(pe_TT);

% Real-corner cross-check (independent of the analytical DVFS scaling):
% how leakage actually varies across the 3 characterized PVT corners.
fid = fopen(fullfile(results_dir, 'pvt_corner_leakage.csv'), 'w');
fprintf(fid, 'corner,voltage_V,temperature_C,P_leak_per_PE_nW,f_max_MHz\n');
fprintf(fid, 'SS,%.2f,%.0f,%.4f,%.2f\n', lib_SS.nom_voltage, lib_SS.nom_temperature, pe_SS.P_leak_nW, pe_SS.f_max_hz/1e6);
fprintf(fid, 'TT,%.2f,%.0f,%.4f,%.2f\n', lib_TT.nom_voltage, lib_TT.nom_temperature, pe_TT.P_leak_nW, pe_TT.f_max_hz/1e6);
fprintf(fid, 'FF,%.2f,%.0f,%.4f,%.2f\n', lib_FF.nom_voltage, lib_FF.nom_temperature, pe_FF.P_leak_nW, pe_FF.f_max_hz/1e6);
fclose(fid);

%% 2. Synthetic workload + per-cycle activity trace (real RTL dataflow timing)
jobs = workload_generator(20, 42);

full_trace = [];
total_macs = 0;
for j = 1:numel(jobs)
    if jobs(j).idle_cycles_before > 0
        full_trace = [full_trace, zeros(1, jobs(j).idle_cycles_before)]; %#ok<AGROW>
    end
    jt = job_activity_trace(jobs(j).M, N);
    full_trace = [full_trace, jt]; %#ok<AGROW>
    total_macs = total_macs + jobs(j).M * N * N;  % MACs performed during streaming
end

% Save one representative job's trace for the utilization-style plot
example_trace = job_activity_trace(jobs(1).M, N);
fid = fopen(fullfile(results_dir, 'job_trace_example.csv'), 'w');
fprintf(fid, 'cycle,active_pe_count,job_M\n');
for c = 1:numel(example_trace)
    fprintf(fid, '%d,%d,%d\n', c, example_trace(c), jobs(1).M);
end
fclose(fid);

%% 3. DSE sweep: replay the SAME workload trace at every DVFS level
fid = fopen(fullfile(results_dir, 'dse_sweep.csv'), 'w');
fprintf(fid, 'voltage_V,freq_MHz,avg_power_mW,total_energy_uJ,total_cycles,latency_us,throughput_GMACs_per_s\n');

for L = 1:numel(levels)
    lvl = levels(L);
    period_s = 1 / lvl.freq_hz;

    E_dyn_J  = sum(full_trace) * lvl.E_dyn_pJ * 1e-12;          % sum(active PE-cycles) * energy/PE-cycle
    P_leak_W = (N * N) * lvl.P_leak_nW * 1e-9;                  % whole-array leakage, constant
    E_leak_J = P_leak_W * numel(full_trace) * period_s;         % leakage integrated over total time

    total_energy_J = E_dyn_J + E_leak_J;
    total_time_s   = numel(full_trace) * period_s;
    avg_power_W    = total_energy_J / total_time_s;
    throughput_GMACs = (total_macs / total_time_s) / 1e9;

    fprintf(fid, '%.3f,%.2f,%.4f,%.4f,%d,%.4f,%.4f\n', ...
        lvl.voltage, lvl.freq_hz/1e6, avg_power_W*1e3, total_energy_J*1e6, ...
        numel(full_trace), total_time_s*1e6, throughput_GMACs);
end
fclose(fid);

fprintf('Wrote %s\n', fullfile(results_dir, 'dse_sweep.csv'));
fprintf('Wrote %s\n', fullfile(results_dir, 'job_trace_example.csv'));
fprintf('Wrote %s\n', fullfile(results_dir, 'pvt_corner_leakage.csv'));
fprintf('Run plot_results.m next to generate the Pareto-front and utilization plots.\n');
