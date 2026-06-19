function build_simulink_model()
%BUILD_SIMULINK_MODEL Programmatically construct dvfs_systolic_model.slx:
%   a small Simulink model wrapping a Stateflow chart that implements the
%   DVFS level-selection / clock-gating policy described in the README.
%
%   Run this ONCE in MATLAB (Simulink + Stateflow required) to materialize
%   the .slx file alongside this script. This .m file is the reviewable
%   source of truth for the model's structure -- re-running it regenerates
%   the same model from scratch.
%
%   NOTE: this script was authored and reviewed carefully, but could not
%   be executed against a live MATLAB/Stateflow session in this
%   environment (no license available here). If it errors on first run,
%   the most likely culprits are version-specific Stateflow API property
%   names (e.g. transition geometry) -- those are wrapped in try/catch
%   below so a cosmetic failure won't block the functional model. Please
%   report back the exact error text if anything fails so it can be fixed.
%
%   Chart inputs:
%     job_pending  (boolean)  -- 1 while a matmul job is in flight
%     utilization  (double, 0..1) -- recent active-PE fraction
%   Chart outputs:
%     dvfs_level   (uint8, 1..5)  -- index into dvfs_levels.m's 5-level
%                                     sweep (1 = lowest V/F, 5 = highest)
%     clk_gate     (boolean)      -- 1 = array clock gated (IDLE state)
%
%   Policy (simple, explicitly illustrative -- not derived from any
%   reference controller): IDLE (no job) -> level 1, clock gated.
%   ACTIVE (job in flight) -> clock ungated, dvfs_level chosen from
%   measured utilization in 5 bands (>0.8/0.6/0.4/0.2/else), i.e. scale
%   voltage/frequency up with demand and down when demand is low.

    mdl_name = 'dvfs_systolic_model';
    if bdIsLoaded(mdl_name)
        close_system(mdl_name, 0);
    end
    if exist([mdl_name '.slx'], 'file')
        delete([mdl_name '.slx']);
    end

    new_system(mdl_name);
    open_system(mdl_name);

    chart_block_path = [mdl_name '/DVFS_ClockGate_Controller'];
    add_block('sflib/Chart', chart_block_path);

    rt = sfroot;
    chart = rt.find('-isa', 'Stateflow.Chart', 'Path', chart_block_path);

    % --- Chart-local data (creation order determines Simulink port order) ---
    d_job = Stateflow.Data(chart);
    d_job.Name = 'job_pending';
    d_job.Scope = 'Input';
    d_job.DataType = 'boolean';

    d_util = Stateflow.Data(chart);
    d_util.Name = 'utilization';
    d_util.Scope = 'Input';
    d_util.DataType = 'double';

    d_level = Stateflow.Data(chart);
    d_level.Name = 'dvfs_level';
    d_level.Scope = 'Output';
    d_level.DataType = 'uint8';

    d_gate = Stateflow.Data(chart);
    d_gate.Name = 'clk_gate';
    d_gate.Scope = 'Output';
    d_gate.DataType = 'boolean';

    % --- States ---
    s_idle = Stateflow.State(chart);
    s_idle.Name = 'IDLE';
    s_idle.LabelString = sprintf('IDLE\nentry: dvfs_level = 1; clk_gate = true;');
    try, s_idle.Position = [40 40 160 90]; catch, end %#ok<CTCH>

    s_active = Stateflow.State(chart);
    s_active.Name = 'ACTIVE';
    s_active.LabelString = sprintf([ ...
        'ACTIVE\n' ...
        'entry: clk_gate = false;\n' ...
        'during: if utilization > 0.8\n' ...
        'dvfs_level = 5;\n' ...
        'elseif utilization > 0.6\n' ...
        'dvfs_level = 4;\n' ...
        'elseif utilization > 0.4\n' ...
        'dvfs_level = 3;\n' ...
        'elseif utilization > 0.2\n' ...
        'dvfs_level = 2;\n' ...
        'else\n' ...
        'dvfs_level = 1;\n' ...
        'end']);
    try, s_active.Position = [300 40 240 170]; catch, end %#ok<CTCH>

    % --- Default transition (chart's initial state) into IDLE ---
    try
        dt = Stateflow.Transition(chart);
        dt.Destination = s_idle;
        dt.DestinationOClock = 9;
        dt.SourceEndPoint = [10 20];
        dt.DestinationEndPoint = [40 70];
    catch ME
        warning('Default transition geometry failed (cosmetic only): %s', ME.message);
    end

    % --- IDLE -> ACTIVE on job_pending ---
    t1 = Stateflow.Transition(chart);
    t1.Source = s_idle;
    t1.Destination = s_active;
    t1.LabelString = '[job_pending == true]';

    % --- ACTIVE -> IDLE when job finishes ---
    t2 = Stateflow.Transition(chart);
    t2.Source = s_active;
    t2.Destination = s_idle;
    t2.LabelString = '[job_pending == false]';

    % --- Model-level In/Out ports, wired to the chart ---
    add_block('built-in/Inport', [mdl_name '/job_pending_in']);
    add_block('built-in/Inport', [mdl_name '/utilization_in']);
    add_block('built-in/Outport', [mdl_name '/dvfs_level_out']);
    add_block('built-in/Outport', [mdl_name '/clk_gate_out']);

    try
        set_param([mdl_name '/job_pending_in'], 'Position', [40 200 70 220]);
        set_param([mdl_name '/utilization_in'], 'Position', [40 260 70 280]);
        set_param([mdl_name '/dvfs_level_out'], 'Position', [600 200 630 220]);
        set_param([mdl_name '/clk_gate_out'], 'Position', [600 260 630 280]);
    catch ME
        warning('Port layout failed (cosmetic only): %s', ME.message);
    end

    add_line(mdl_name, 'job_pending_in/1', 'DVFS_ClockGate_Controller/1', 'autorouting', 'on');
    add_line(mdl_name, 'utilization_in/1', 'DVFS_ClockGate_Controller/2', 'autorouting', 'on');
    add_line(mdl_name, 'DVFS_ClockGate_Controller/1', 'dvfs_level_out/1', 'autorouting', 'on');
    add_line(mdl_name, 'DVFS_ClockGate_Controller/2', 'clk_gate_out/1', 'autorouting', 'on');

    save_system(mdl_name, fullfile(pwd, [mdl_name '.slx']));
    fprintf('Saved %s.slx in %s\n', mdl_name, pwd);
end
