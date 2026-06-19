function gc = pe_gate_counts(DW, ACCW)
%PE_GATE_COUNTS Architectural gate-equivalent decomposition of ONE
%   systolic-array PE's combinational datapath:
%       psum_out <= psum_in + weight * act_in
%   (see systolic_mac_array/rtl/mac_pe.v).
%
%   This is a documented, simplified gate-level PROXY used for
%   system-level PPA estimation -- it is NOT a synthesized netlist and
%   does not claim cycle-accurate or gate-accurate parity with a real
%   multiplier/adder implementation. Two structural assumptions, stated
%   explicitly here and in the README's Data Sources / Assumptions:
%
%     1. DWxDW unsigned array multiplier:
%          DW*DW          AND2 gates  (partial products)
%          DW*(DW-1)      full adders (ripple reduction array)
%     2. ACCW-bit ripple-carry adder for psum accumulation:
%          ACCW           full adders
%
%   Each full adder is counted as 2x XOR2 + 2x AND2 + 1x OR2 (a standard
%   textbook full-adder gate decomposition).
%
%   Separately, gc.crit_path_fa_stages is the estimated *critical-path
%   depth* (in series full-adder stages) -- NOT the same as the total FA
%   count above, which is a parallel/additive total used for energy and
%   leakage. Depth is approximated as the textbook array-multiplier
%   diagonal critical path (2*(DW-1) FA stages) plus the ACCW-stage
%   ripple-carry accumulator that follows it in series.

    n_fa_total = DW * (DW - 1) + ACCW;

    gc.AND2 = DW * DW + 2 * n_fa_total;
    gc.XOR2 = 2 * n_fa_total;
    gc.OR2  = n_fa_total;

    gc.DFF_psum   = ACCW;  % psum_out register: toggles every active MAC cycle
    gc.DFF_actreg = DW;    % act_out pass-through register: toggles every active MAC cycle
    gc.DFF_weight = DW;    % weight register: loaded once per job, NOT per-MAC-cycle (leakage only)

    gc.n_fa_total          = n_fa_total;
    gc.crit_path_fa_stages = 2 * (DW - 1) + ACCW;
end
