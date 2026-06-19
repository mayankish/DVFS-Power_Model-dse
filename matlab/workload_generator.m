function jobs = workload_generator(num_jobs, seed)
%WORKLOAD_GENERATOR Synthetic INT8 systolic-array workload generator.
%
%   Generates a sequence of matrix-multiply "jobs" (C = A x W, see
%   systolic_mac_array/README.md's documented dataflow), each with a
%   random activation row-count M and a random idle gap before it starts
%   (modeling between-job dead time -- the DVFS/clock-gating controller's
%   opportunity window).
%
%   SYNTHETIC: no real instruction/activity trace exists for this RTL
%   (same honesty stance as Project 1's CPU/DMA traffic generator -- see
%   that project's README Data Sources / Assumptions). Every number this
%   produces is clearly a randomized stand-in, not a measured workload.
%
%   jobs = WORKLOAD_GENERATOR(20, 42)
%   jobs(i).M                    -- activation rows streamed this job (4-64)
%   jobs(i).idle_cycles_before   -- idle gap before this job starts (0-40 cycles)

    rng(seed);
    jobs = struct('M', {}, 'idle_cycles_before', {});
    for i = 1:num_jobs
        jobs(i).M                   = randi([4, 64]);
        jobs(i).idle_cycles_before  = randi([0, 40]);
    end
end
