% PLOT_RESULTS  Generate the README's figures from run_dse.m's real CSV
% output. Run AFTER run_dse.m. Requires base MATLAB only (no toolboxes).

clear; clc;
results_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'results');

%% Figure 1: Power vs. throughput Pareto front across DVFS levels
sweep = readtable(fullfile(results_dir, 'dse_sweep.csv'));

fig1 = figure('Color', 'w', 'Position', [100 100 700 480]);
plot(sweep.throughput_GMACs_per_s, sweep.avg_power_mW, '-o', ...
    'LineWidth', 1.6, 'MarkerSize', 7, 'MarkerFaceColor', [0.2 0.4 0.8]);
for i = 1:height(sweep)
    text(sweep.throughput_GMACs_per_s(i), sweep.avg_power_mW(i), ...
        sprintf('  %.2fV / %.0fMHz', sweep.voltage_V(i), sweep.freq_MHz(i)), ...
        'FontSize', 8);
end
xlabel('Throughput (GMACs/s)');
ylabel('Average Power (mW)');
title('DVFS Power-Throughput Pareto Front (8x8 INT8 Systolic Array)');
grid on;
saveas(fig1, fullfile(results_dir, 'pareto_power_vs_throughput.png'));

%% Figure 2: Per-cycle active-PE utilization for one representative job
trace = readtable(fullfile(results_dir, 'job_trace_example.csv'));

fig2 = figure('Color', 'w', 'Position', [100 100 800 420]);
plot(trace.cycle, trace.active_pe_count, '-', 'LineWidth', 1.4, 'Color', [0.8 0.3 0.2]);
xlabel('Cycle');
ylabel('Active PE count (of 64)');
title(sprintf('Per-Cycle PE Activity — One Job (M = %d activation rows)', trace.job_M(1)));
ylim([0 70]);
grid on;
saveas(fig2, fullfile(results_dir, 'pe_activity_timeline.png'));

%% Figure 3: Real-corner leakage cross-check (SS / TT / FF)
pvt = readtable(fullfile(results_dir, 'pvt_corner_leakage.csv'));

fig3 = figure('Color', 'w', 'Position', [100 100 600 420]);
bar(categorical(pvt.corner), pvt.P_leak_per_PE_nW);
ylabel('Leakage power per PE (nW)');
title('Real Characterized Leakage by PVT Corner (Liberty data)');
grid on;
saveas(fig3, fullfile(results_dir, 'pvt_leakage_comparison.png'));

fprintf('Saved 3 figures to %s\n', results_dir);
