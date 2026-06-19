function levels = dvfs_levels(pe_nom)
%DVFS_LEVELS Generate a DVFS voltage/frequency operating-point sweep,
%   anchored at the REAL nominal (TT-corner, 1.80V) PE characterization
%   pe_nom (from pe_characterize). The Liberty data only characterizes
%   three fixed PVT corners (no multi-voltage sweep at constant
%   temperature), so this project derives the DVFS sweep analytically
%   from the TT anchor using standard first-order CMOS scaling laws,
%   stated explicitly here and in the README:
%
%     - Dynamic energy/cycle:  E_dyn(V) = E_dyn_nom * (V / Vnom)^2
%         (CV^2 scaling; switched capacitance C assumed voltage-independent)
%     - Leakage power:         P_leak(V) = P_leak_nom * (V / Vnom)
%         (linear-in-V approximation of sub-threshold leakage; real
%         leakage is closer to exponential in V, but the Liberty data
%         does not characterize enough voltage points to fit that curve,
%         so linear is used as a conservative, clearly-labeled estimate)
%     - Max frequency:         alpha-power law (Sakurai-Newton):
%             f(V) = f_nom * ((V - Vth) / (Vnom - Vth))^alpha
%         Vth = 0.45 V and alpha = 1.3 are ASSUMED typical 180nm
%         technology constants -- NOT derived from this project's
%         characterized data, since that would require Vth extraction
%         from transistor-level I-V sweeps this library does not provide.
%
%   levels(i).voltage, .freq_hz, .E_dyn_pJ, .P_leak_nW

    Vth   = 0.45;
    alpha = 1.3;
    v_factors = [0.70, 0.85, 1.00, 1.10, 1.20];  % relative to nominal voltage

    V_nom = pe_nom.voltage;

    levels = struct('voltage', {}, 'freq_hz', {}, 'E_dyn_pJ', {}, 'P_leak_nW', {});
    for i = 1:numel(v_factors)
        V = V_nom * v_factors(i);
        levels(i).voltage   = V;
        levels(i).freq_hz   = pe_nom.f_max_hz * ((V - Vth) / (V_nom - Vth))^alpha;
        levels(i).E_dyn_pJ  = pe_nom.E_dyn_pJ * (V / V_nom)^2;
        levels(i).P_leak_nW = pe_nom.P_leak_nW * (V / V_nom);
    end
end
