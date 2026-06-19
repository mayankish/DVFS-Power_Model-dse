function trace = job_activity_trace(M, N)
%JOB_ACTIVITY_TRACE Per-cycle active-PE count for one systolic-array
%   matmul job, derived from systolic_mac_array's documented dataflow
%   (README.md "Skewed feed": output C[m][n] valid (N-1)+m+n cycles after
%   streaming starts; weight_loader streams one row per cycle).
%
%   Two phases:
%     1. Weight load   : N cycles, N PEs active per cycle (one row of the
%                         array latches its weight register each cycle).
%     2. MAC streaming  : M + 2*(N-1) - 1 cycles (pipeline fill + steady
%                         stream + drain), modeled CONSERVATIVELY as all
%                         N*N PEs active every cycle of this window.
%
%   Documented simplification: the true fill/drain edges only have a
%   diagonal wavefront of active PEs (1, 2, ... N-1, N, N-1, ... 1), not
%   the full N*N -- this model over-counts activity (and therefore power)
%   during the first/last (N-1) cycles of each job. See Limitations &
%   Future Work; an exact per-PE accounting would mirror the companion
%   Activity-Based PPA project's VCD-derived toggle-rate approach.
%
%   trace = JOB_ACTIVITY_TRACE(32, 8)   -- row vector, one entry per cycle

    load_cycles   = N;
    stream_cycles = M + 2 * (N - 1) - 1;

    trace = [repmat(N, 1, load_cycles), repmat(N * N, 1, stream_cycles)];
end
