function pe = pe_characterize(lib, DW, ACCW)
%PE_CHARACTERIZE Combine the architectural gate decomposition
%   (pe_gate_counts) with a real characterized Liberty corner (lib, from
%   parse_liberty) to obtain, for ONE systolic-array PE at this corner's
%   nominal voltage:
%
%     - E_dyn_pJ:     dynamic energy per active MAC cycle, computed as
%                       sum_g  count_g * 0.5 * Cg_pF * V^2
%                     using each gate type's real Liberty input-pin
%                     capacitance as the switched-capacitance proxy, with
%                     an activity factor of 1 toggle per gate per active
%                     MAC (a worst-case/simplified architectural
%                     assumption -- see README; the companion
%                     Activity-Based PPA project replaces this fixed
%                     assumption with real VCD-derived toggle rates).
%     - P_leak_nW:    leakage power, ALWAYS present regardless of
%                     activity: sum_g count_g * leakage_g, including the
%                     idle weight register.
%     - crit_path_ps / f_max_hz: estimated combinational critical-path
%                     delay through the ripple multiply-add chain, using
%                     real characterized cell_rise delays, converted to a
%                     maximum clock frequency for this PE design.
%
%   pe = PE_CHARACTERIZE(lib, 8, 32)   % DW=8 (INT8), ACCW=32 (real RTL params)

    gc = pe_gate_counts(DW, ACCW);
    V  = lib.nom_voltage;

    E_dyn  = 0;
    P_leak = 0;
    comb_types = {'AND2', 'XOR2', 'OR2'};
    for i = 1:numel(comb_types)
        t = comb_types{i};
        n = gc.(t);
        E_dyn  = E_dyn  + n * 0.5 * lib.cells.(t).cap_pF * V^2;  % pJ (pF * V^2 == pJ)
        P_leak = P_leak + n * lib.cells.(t).leakage_nW;          % nW
    end

    n_dff_active = gc.DFF_psum + gc.DFF_actreg;
    n_dff_idle   = gc.DFF_weight;
    E_dyn  = E_dyn  + n_dff_active * 0.5 * lib.cells.DFF.cap_pF * V^2;
    P_leak = P_leak + (n_dff_active + n_dff_idle) * lib.cells.DFF.leakage_nW;

    % Critical path: crit_path_fa_stages full-adder stages in series, each
    % approximated as one AND2 delay + one XOR2 delay (the longest signal
    % path through a textbook full adder: A/B -> XOR -> AND/carry chain),
    % followed by the DFF's CLK-to-Q delay into the destination register.
    fa_stage_delay_ps = lib.cells.AND2.delay_ps + lib.cells.XOR2.delay_ps;
    crit_path_ps = gc.crit_path_fa_stages * fa_stage_delay_ps + lib.cells.DFF.delay_ps;
    f_max_hz = 1 / (crit_path_ps * 1e-12);

    pe.E_dyn_pJ     = E_dyn;
    pe.P_leak_nW    = P_leak;
    pe.crit_path_ps = crit_path_ps;
    pe.f_max_hz     = f_max_hz;
    pe.gate_counts  = gc;
    pe.voltage      = V;
    pe.DW           = DW;
    pe.ACCW         = ACCW;
end
