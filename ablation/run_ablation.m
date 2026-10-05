function [RunTable, SummaryTable] = run_ablation(run_mode)
%RUN_ABLATION Minimal controlled experiment reported in Section 4.4.
%
%   run_ablation('smoke') performs a short code check.
%   run_ablation('paper') performs the manuscript study:
%   six representative CEC2019 MMOPs, 31 matched seeds, and five variants.
%
% The five variants isolate (1) the SPD branch, (2) adaptive versus
% constant participation, and (3) sensitivity to the Eq. (16) exponent q.
% Every variant uses the same population, strict function-evaluation budget,
% normalized decision-space distances, and matched random seed.

    if nargin < 1 || isempty(run_mode)
        run_mode = 'smoke';
    end
    if ~ismember(run_mode, {'smoke','paper'})
        error('run_mode must be smoke or paper.');
    end

    root_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(root_dir);
    benchmark_dir = fullfile(repo_root, 'benchmark', 'CEC2019');
    addpath(fullfile(repo_root, 'benchmark', 'SPD-DN-NSGA-II'));
    addpath(fullfile(benchmark_dir, 'problems'));
    addpath(fullfile(benchmark_dir, 'indicators'));

    if strcmp(run_mode, 'paper')
        problem_ids = [1 5 11 14 21 22];
        n_runs = 31;
        max_fevs_config = 10000;
    else
        problem_ids = 1;
        n_runs = 2;
        max_fevs_config = 1000;
    end

    variants = struct( ...
        'name', {'SPD-off','Adaptive-q512','Constant-q512', ...
                 'Adaptive-q64','Adaptive-q1024'}, ...
        'jr_mode', {'off','adaptive','constant','adaptive','adaptive'}, ...
        'jr_constant', {3/8,3/8,0.1,3/8,3/8}, ...
        'q_decay', {512,512,512,64,1024});

    Problem = {};
    Variant = {};
    Run = [];
    Seed = [];
    rPSP = [];
    IGDX = [];
    IGDF = [];
    FEvals = [];
    SPDEvals = [];
    Generations = [];
    JRMode = {};
    QDecay = [];

    for p = 1:numel(problem_ids)
        problem = GetProblem(problem_ids(p));
        reference_file = fullfile(benchmark_dir, 'reference_data', ...
            [problem.fname '_Reference_PSPF_data.mat']);
        reference = load(reference_file, 'PS', 'PF');

        popsize = 100 * problem.n_var;
        max_fevs = max_fevs_config;
        max_gen = ceil(max_fevs / popsize);

        for run_id = 1:n_runs
            common_seed = 20260926 + run_id;
            for v = 1:numel(variants)
                rng(common_seed, 'twister');
                options = struct( ...
                    'jr_mode', variants(v).jr_mode, ...
                    'jr_constant', variants(v).jr_constant, ...
                    'q_decay', variants(v).q_decay, ...
                    'max_fevals', max_fevs);

                [ps, pf, run_info] = SPD_DN_NSGAII_Optimized( ...
                    problem.fname, problem.xl, problem.xu, problem.n_obj, ...
                    popsize, max_gen, [], options);

                if run_info.fevals ~= run_info.max_fevals
                    error('Unequal FE budget in %s, run %d, variant %s.', ...
                        problem.fname, run_id, variants(v).name);
                end

                igdx_value = IGD_calculation(ps, reference.PS);
                igdf_value = IGD_calculation(pf, reference.PF);
                cr_value = CR_calculation(ps, reference.PS);
                if cr_value > 0
                    rpsp_value = igdx_value / cr_value;
                else
                    rpsp_value = Inf;
                end

                Problem{end+1,1} = problem.fname;
                Variant{end+1,1} = variants(v).name;
                Run(end+1,1) = run_id;
                Seed(end+1,1) = common_seed;
                rPSP(end+1,1) = rpsp_value;
                IGDX(end+1,1) = igdx_value;
                IGDF(end+1,1) = igdf_value;
                FEvals(end+1,1) = run_info.fevals;
                SPDEvals(end+1,1) = run_info.spd_evaluations;
                Generations(end+1,1) = run_info.generations;
                JRMode{end+1,1} = run_info.jr_mode;
                QDecay(end+1,1) = run_info.q_decay;

                fprintf('%s | run %02d/%02d | %-14s | rPSP %.4g | IGDX %.4g\n', ...
                    problem.fname, run_id, n_runs, variants(v).name, ...
                    rpsp_value, igdx_value);
            end
        end
    end

    RunTable = table(Problem, Variant, Run, Seed, rPSP, IGDX, IGDF, ...
        FEvals, SPDEvals, Generations, JRMode, QDecay);
    SummaryTable = BuildSummary(RunTable, problem_ids, variants);

    output_dir = fullfile(root_dir, 'reproduced_results');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    writetable(RunTable, fullfile(output_dir, ...
        [run_mode '_run_level.csv']));
    writetable(SummaryTable, fullfile(output_dir, ...
        [run_mode '_summary.csv']));
    save(fullfile(output_dir, [run_mode '_results.mat']), ...
        'RunTable', 'SummaryTable', 'variants', 'problem_ids', ...
        'n_runs', 'max_fevs_config');
end

function SummaryTable = BuildSummary(RunTable, problem_ids, variants)
    Problem = {};
    Variant = {};
    rPSP_Median = [];
    rPSP_IQR = [];
    IGDX_Median = [];
    IGDX_IQR = [];
    IGDF_Median = [];
    IGDF_IQR = [];
    Median_SPDEvals = [];

    row = 0;
    for p = 1:numel(problem_ids)
        problem = GetProblem(problem_ids(p));
        for v = 1:numel(variants)
            mask = strcmp(RunTable.Problem, problem.fname) & ...
                strcmp(RunTable.Variant, variants(v).name);
            row = row + 1;
            Problem{row,1} = problem.fname;
            Variant{row,1} = variants(v).name;
            [rPSP_Median(row,1), rPSP_IQR(row,1)] = ...
                MedianIQR(RunTable.rPSP(mask));
            [IGDX_Median(row,1), IGDX_IQR(row,1)] = ...
                MedianIQR(RunTable.IGDX(mask));
            [IGDF_Median(row,1), IGDF_IQR(row,1)] = ...
                MedianIQR(RunTable.IGDF(mask));
            Median_SPDEvals(row,1) = median(RunTable.SPDEvals(mask));
        end
    end

    SummaryTable = table(Problem, Variant, rPSP_Median, rPSP_IQR, ...
        IGDX_Median, IGDX_IQR, IGDF_Median, IGDF_IQR, Median_SPDEvals);
end

function [median_value, iqr_value] = MedianIQR(values)
    median_value = median(values);
    quartiles = prctile(values, [25 75]);
    iqr_value = quartiles(2) - quartiles(1);
end

function problem = GetProblem(problem_id)
    switch problem_id
        case 1
            problem = MakeProblem('MMF1', 2, 2, [1 -1], [3 1]);
        case 5
            problem = MakeProblem('MMF5', 2, 2, [1 -1], [3 3]);
        case 11
            problem = MakeProblem('MMF11', 2, 2, [0.1 0.1], [1.1 1.1]);
        case 14
            problem = MakeProblem('MMF14', 3, 3, [0 0 0], [1 1 1]);
        case 21
            problem = MakeProblem('SYM_PART_rotated', 2, 2, ...
                [-20 -20], [20 20]);
        case 22
            problem = MakeProblem('Omni_test', 2, 3, [0 0 0], [6 6 6]);
        otherwise
            error('Unsupported minimal-ablation problem id: %d.', problem_id);
    end
end

function problem = MakeProblem(fname, n_obj, n_var, xl, xu)
    problem = struct('fname', fname, 'n_obj', n_obj, ...
        'n_var', n_var, 'xl', xl, 'xu', xu);
end
