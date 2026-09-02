function [ps,pf]=NSGAII(fname,xl,xu,n_obj,pop,Max_Gen)
% NSGAII - Standard NSGA-II implementation (no Decision-Niched modifications)
% Inputs:
%   fname    - function handle for objectives, e.g. @(x)[f1,f2,...]
%   xl, xu   - 1 x n vectors lower/upper bounds
%   n_obj    - number of objectives (M)
%   pop      - population size
%   Max_Gen  - maximum generations
%
% Outputs:
%   ps - decision variable matrix of final population (pop x n)
%   pf - objective values matrix of final population (pop x n_obj)

n = size(xl,2);
feval_max = Max_Gen * pop;
gen = ceil(feval_max / pop);
feval_count = 0;

% Initialize population (decision variables)
for i=1:pop
    particle(i,1:n) = xl + (xu - xl).*rand(1,n);
end

% Evaluate initial population objectives
for i=1:pop
    particle(i,n+1:n+n_obj) = feval(fname, particle(i,1:n));
    feval_count = feval_count + 1;
end

% Non-dominated sort + crowding distance (adds 2 cols: rank and crowding)
particle = non_domination_sort(particle, n_obj, n);

% Main generational loop
for iGen = 1:gen
    pool = round(pop/2);
    tour_crowdsize = 2; % standard NSGA-II tournament size is 2

    parent_chromosome = tournament_selection(particle, pool, tour_crowdsize, n, n_obj);

    mu = 20; mum = 20;
    [offspring_chromosome, feval_count] = genetic_operator(parent_chromosome, n_obj, n, mu, mum, xl, xu, fname, feval_count);

    [main_pop, ~] = size(particle);
    [offspring_pop, ~] = size(offspring_chromosome);

    intermediate_chromosome(1:main_pop,:) = particle;
    intermediate_chromosome(main_pop + 1 : main_pop + offspring_pop, 1 : n + n_obj) = offspring_chromosome;

    intermediate_chromosome = non_domination_sort(intermediate_chromosome, n_obj, n);

    particle = replace_chromosome(intermediate_chromosome, n_obj, n, pop);

    if feval_count > feval_max
        break;
    end
end

ps = particle(:,1:n);
pf = particle(:,n+1:n+n_obj);

end


%% -------------------------
%% Non-dominated sort + crowding distance (standard NSGA-II)
function f = non_domination_sort(x, M, V)
% x: N x (V + M) matrix (decision + objective)
% returns z: N x (V + M + 2) where last two cols are rank and crowding distance

[N, ~] = size(x);

% initialize
individual = struct();
for i = 1:N
    individual(i).n = 0;
    individual(i).p = [];
end
F = {};
front = 1;
F{front} = [];

% dominance counting
for i = 1:N
    for j = 1:N
        if i == j, continue; end
        dom_less = 0; dom_equal = 0; dom_more = 0;
        for k = 1:M
            if x(i,V + k) < x(j,V + k)
                dom_less = dom_less + 1;
            elseif x(i,V + k) == x(j,V + k)
                dom_equal = dom_equal + 1;
            else
                dom_more = dom_more + 1;
            end
        end
        if dom_less == 0 && dom_equal ~= M
            individual(i).n = individual(i).n + 1;
        elseif dom_more == 0 && dom_equal ~= M
            individual(i).p = [individual(i).p, j];
        end
    end
    if individual(i).n == 0
        x(i, M + V + 1) = 1; % rank column
        F{front} = [F{front}, i];
    else
        x(i, M + V + 1) = Inf;
    end
end

% find subsequent fronts
while ~isempty(F{front})
    Q = [];
    for idx = 1:length(F{front})
        i = F{front}(idx);
        if ~isempty(individual(i).p)
            for j = 1:length(individual(i).p)
                q = individual(i).p(j);
                individual(q).n = individual(q).n - 1;
                if individual(q).n == 0
                    x(q, M + V + 1) = front + 1;
                    Q = [Q, q];
                end
            end
        end
    end
    front = front + 1;
    F{front} = Q;
end

% sorting by front to build sorted_based_on_front
[temp, index_of_fronts] = sort(x(:, M + V + 1));
sorted_based_on_front = x(index_of_fronts, :);

% compute crowding distance per front (store in column M+V+2)
z = zeros(N, M + V + 2);
current_index = 0;
for f = 1:(length(F)-1) % last F may be empty
    indices = F{f};
    if isempty(indices)
        continue;
    end
    y = sorted_based_on_front(current_index + 1 : current_index + length(indices), :);
    current_index = current_index + length(indices);

    % initialize crowding distances
    distances = zeros(length(indices),1);

    % for each objective
    for obj = 1:M
        [~, idx_sort] = sort(y(:, V + obj));
        f_min = y(idx_sort(1), V + obj);
        f_max = y(idx_sort(end), V + obj);

        % boundary points
        distances(idx_sort(1)) = Inf;
        distances(idx_sort(end)) = Inf;

        if f_max - f_min == 0
            % all equal, internal distances remain 0 (but boundaries Inf)
            continue;
        end

        % internal points
        for jj = 2:length(idx_sort)-1
            next_obj = y(idx_sort(jj+1), V + obj);
            prev_obj = y(idx_sort(jj-1), V + obj);
            distances(idx_sort(jj)) = distances(idx_sort(jj)) + (next_obj - prev_obj) / (f_max - f_min);
        end
    end

    % fill y with rank and crowding
    y(:, M + V + 1) = f;      % rank
    y(:, M + V + 2) = distances;

    z(current_index - length(indices) + 1 : current_index, :) = y(:,1:M+V+2);
end

% Return z rows corresponding to sorted_based_on_front order. But to keep
% original order consistent with input, we reconstruct so that rows map to
% original individuals:
% We have z in the order of sorted_based_on_front; map back:
sorted_with_rank_and_cd = z; % in order of index_of_fronts
% create full matrix in original order:
f = zeros(N, M + V + 2);
for i = 1:N
    f(index_of_fronts(i), :) = sorted_with_rank_and_cd(i, :);
end

end


%% -------------------------
%% Genetic operator (SBX + polynomial mutation). Returns child population and updated feval_count
function [f, feval_count] = genetic_operator(parent_chromosome, M, V, mu, mum, l_limit, u_limit, fname, feval_count)

[N, ~] = size(parent_chromosome);
p = 1;
child = [];

for i = 1:N
    if rand(1) < 0.9
        % crossover (SBX)
        child_1 = zeros(1,V);
        child_2 = zeros(1,V);
        parent_1_idx = randi(N);
        parent_2_idx = randi(N);
        while isequal(parent_chromosome(parent_1_idx,1:V), parent_chromosome(parent_2_idx,1:V))
            parent_2_idx = randi(N);
        end
        parent_1 = parent_chromosome(parent_1_idx,1:V);
        parent_2 = parent_chromosome(parent_2_idx,1:V);
        for j = 1:V
            u = rand(1);
            if u <= 0.5
                bq = (2*u)^(1/(mu+1));
            else
                bq = (1/(2*(1-u)))^(1/(mu+1));
            end
            child_1(j) = 0.5*((1 + bq)*parent_1(j) + (1 - bq)*parent_2(j));
            child_2(j) = 0.5*((1 - bq)*parent_1(j) + (1 + bq)*parent_2(j));
            % bounds
            if child_1(j) > u_limit(j), child_1(j) = u_limit(j); end
            if child_1(j) < l_limit(j), child_1(j) = l_limit(j); end
            if child_2(j) > u_limit(j), child_2(j) = u_limit(j); end
            if child_2(j) < l_limit(j), child_2(j) = l_limit(j); end
        end
        % evaluate objectives
        child_1(1,V+1:V+M) = feval(fname, child_1(1:V));
        child_2(1,V+1:V+M) = feval(fname, child_2(1:V));
        feval_count = feval_count + 2;

        child(p,:) = child_1;
        child(p+1,:) = child_2;
        p = p + 2;
    else
        % mutation (polynomial)
        parent_idx = randi(N);
        child_3 = parent_chromosome(parent_idx,1:V);
        for j = 1:V
            r = rand(1);
            if r < 0.5
                delta = (2*r)^(1/(mum+1)) - 1;
            else
                delta = 1 - (2*(1 - r))^(1/(mum+1));
            end
            child_3(j) = child_3(j) + delta;
            if child_3(j) > u_limit(j), child_3(j) = u_limit(j); end
            if child_3(j) < l_limit(j), child_3(j) = l_limit(j); end
        end
        child_3(1,V+1:V+M) = feval(fname, child_3(1:V));
        feval_count = feval_count + 1;

        child(p,:) = child_3(1,1:V+M);
        p = p + 1;
    end
end

f = child;

end


%% -------------------------
%% Tournament selection (standard NSGA-II: rank then crowding distance)
function f = tournament_selection(chromosome, pool_size, tour_crowdsize, n, n_obj)
[pop, ~] = size(chromosome);
rank_col = n + n_obj + 1;
cd_col = n + n_obj + 2;

for i = 1:pool_size
    % pick tour_crowdsize distinct individuals
    candidates = zeros(1,tour_crowdsize);
    for j = 1:tour_crowdsize
        idx = randi(pop);
        while any(candidates == idx)
            idx = randi(pop);
        end
        candidates(j) = idx;
    end

    % compare by rank then crowding distance
    ranks = chromosome(candidates, rank_col);
    [minRank, minIdxs] = min(ranks);
    minCandidates = candidates(ranks == minRank);

    if length(minCandidates) == 1
        winner = minCandidates;
    else
        % tie, pick one with larger crowding distance
        cds = chromosome(minCandidates, cd_col);
        [~, maxIdxLocal] = max(cds);
        winner = minCandidates(maxIdxLocal);
    end

    f(i,:) = chromosome(winner, 1 : (n + n_obj));
end

end


%% -------------------------
%% Replacement: fill new population from intermediate (sorted + crowding), standard NSGA-II
function f = replace_chromosome(intermediate_chromosome, M, V, pop)
% intermediate_chromosome: rows with columns [x (V) | f (M) | rank | crowding]
[N, ~] = size(intermediate_chromosome);

% sort by rank
[~, index] = sort(intermediate_chromosome(:, M + V + 1));
sorted_chromosome = intermediate_chromosome(index, :);

max_rank = max(sorted_chromosome(:, M + V + 1));
previous_index = 0;
f = [];

for r = 1:max_rank
    current_index = max(find(sorted_chromosome(:, M + V + 1) == r));
    if isempty(current_index)
        continue;
    end
    if current_index > pop
        remaining = pop - previous_index;
        temp_pop = sorted_chromosome(previous_index + 1 : current_index, :);
        % sort by crowding distance descending
        [~, temp_sort_index] = sort(temp_pop(:, M + V + 2),'descend');
        for j = 1:remaining
            f(previous_index + j, :) = temp_pop(temp_sort_index(j), :);
        end
        return;
    elseif current_index < pop
        f(previous_index + 1 : current_index, :) = sorted_chromosome(previous_index + 1 : current_index, :);
    else
        f(previous_index + 1 : current_index, :) = sorted_chromosome(previous_index + 1 : current_index, :);
        return;
    end
    previous_index = current_index;
end

end
