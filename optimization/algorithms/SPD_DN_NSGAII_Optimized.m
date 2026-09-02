function [ps,pf]=SPD_DN_NSGAII_Optimized(fname,xl,xu,n_obj,pop,Max_Gen,integer_idx)
% integer_idx lists mixed-integer decision-variable columns. The PMBRA
% application uses integer_idx = [1 2 3] for Nn, Nc and Ns. Benchmark
% calls remain continuous by omitting this optional argument.
    if nargin < 7
        integer_idx = [];
    end
% SPD_DN_NSGAII_Optimized: 增强版 SPD-DN-NSGAII 算法 (策略 3: 强化动态衰减)
    
    % --- 参数初始化 ---
    n = size(xl,2);               % 决策空间维度
    feval_max = Max_Gen * pop;
    gen_count = ceil(feval_max / pop);
    feval_count = 0;
    
    % SPDTLBO 中定义的参数
    num = 512; % 增大衰减指数，使 r1 衰减非常快，增强后期收敛
    
    % 初始化种群
    particle = zeros(pop, n + n_obj);
    for i = 1:pop
        particle(i,1:n) = xl + (xu-xl) .* rand(1,n);
        particle(i,1:n) = RepairVariables(particle(i,1:n), xl, xu, integer_idx);
        particle(i,n+1:n+n_obj) = feval(fname, particle(i,1:n));
        feval_count = feval_count + 1;
    end
    
    % 非支配排序 (DN-NSGAII 版本)
    % 额外列: [Rank, F-Dist, X-Dist]
    particle = non_domination_sort_mod(particle, n_obj, n);
    
    % --- 迭代开始 ---
    for i = 1:gen_count
        
        % [优化 1] 动态调整 Jumping_rate (策略 3: 强化衰减)
        Jumping_rate = cos(0.5 * pi * i / gen_count)^4;
                
        % --- SPD 算子依赖计算 (EK_1, EK_2) ---
        rank_1_indices = find(particle(:, n+n_obj+1) == 1);
        if isempty(rank_1_indices)
            rank_1_indices = 1:pop; % 容错
        end
        
        % 1. 从 Rank 1 前沿中随机选择两个 "领导者"
        PK_1_idx = rank_1_indices(randi(length(rank_1_indices)));
        PK_2_idx = rank_1_indices(randi(length(rank_1_indices)));
        PK_1 = particle(PK_1_idx, 1:n);
        PK_2 = particle(PK_2_idx, 1:n);
        
        % 2. 获取种群的随机排列
        dx1 = randperm(pop);
        dx2 = randperm(pop);
        
        % 3. 计算 EK_1 和 EK_2
        EK_1 = PK_1 - particle(dx1, 1:n);
        EK_2 = PK_2 - particle(dx2, 1:n);
        
        
        % --- 1. 标准遗传算子 (生成子代) ---
        pool = round(pop/2);
        % 注意：这里将 tour_crowdsize 设回了 2，因为 round(pop/2) 可能过大，不符合锦标赛选择的本意
        tour_crowdsize = 2; 
        
        % 使用 tournament_selection_optimized (基于 Rank 和 X-Dist)
        parent_chromosome = tournament_selection_optimized(particle, pool, tour_crowdsize, n, n_obj);
        
        mu = 20;  % Crossover index
        mum = 20; % Mutation index
        
        % 使用 global 传递 feval_count 到 genetic_operator
        global feval_count_global;
        feval_count_global = feval_count;
        
        % genetic_operator (保持不变，确保了标准的 GA 探索)
        offspring_chromosome = genetic_operator(parent_chromosome, n_obj, n, mu, mum, xl, xu, fname, integer_idx);
        
        feval_count = feval_count_global; % 取回更新后的 feval_count
        clear feval_count_global;
        
        
        % --- 2. SPD 算子 (生成子代) ---
        spd_offspring = [];
        
        if rand < Jumping_rate
            X = particle(:, 1:n);
            NP = pop;
            number_dimension = n;
            
            % r1: 随迭代次数 i 衰减的随机向量 (增强后期利用)
            r = rand(NP, number_dimension);
            r1 = r .* (cos(0.5 * pi * i / gen_count))^num; 
            
            % SPD 核心公式
            opposite_popu_x2 = X + r1 .* EK_1 + (1 - r1) .* (EK_1 - EK_2);
            
            % 边界检查
            opposite_popu_x2 = RepairVariables(opposite_popu_x2, xl, xu, integer_idx);
            
            % 评估新的 SPD 解
            spd_offspring = zeros(NP, n + n_obj);
            spd_offspring(:, 1:n) = opposite_popu_x2;
            
            for j = 1:NP
                if feval_count >= feval_max, break, end
                spd_offspring(j, n+1:n+n_obj) = feval(fname, opposite_popu_x2(j, :));
                feval_count = feval_count + 1;
            end
            
            % 仅保留有效评估的个体
            valid_spd_offspring = spd_offspring(1:min(NP, feval_max - feval_count + NP), :);
        else
            valid_spd_offspring = [];
        end
        
        % --- 3. 合并与选择 (DN-NSGAII 核心) ---
        
        [main_pop,~] = size(particle);
        [offspring_pop,~] = size(offspring_chromosome);
        [spd_pop, ~] = size(valid_spd_offspring);
        
        % 创建中间种群 (父代 + GA子代 + SPD子代)
        intermediate_chromosome = zeros(main_pop + offspring_pop + spd_pop, n + n_obj + 3);
        
        intermediate_chromosome(1:main_pop,:) = particle;
        intermediate_chromosome(main_pop + 1 : main_pop + offspring_pop, 1 : n+n_obj) = offspring_chromosome;
        
        if spd_pop > 0
            start_idx = main_pop + offspring_pop + 1;
            end_idx = main_pop + offspring_pop + spd_pop;
            intermediate_chromosome(start_idx : end_idx, 1 : n+n_obj) = valid_spd_offspring;
        end
        
        % 对合并的种群进行非支配排序 (计算 Rank, F-Dist, X-Dist)
        intermediate_chromosome = non_domination_sort_mod(intermediate_chromosome, n_obj, n);
        
        % 环境选择 (DN-NSGAII: 基于 Rank 和 X-Dist)
        particle = replace_chromosome(intermediate_chromosome, n_obj, n, pop);
        
        if feval_count >= feval_max, break, end
        
%       disp(['SPD-DN-NSGAII Optimized ' 'gen=  ' num2str(i) ])
    end
    
    ps = particle(:,1:n);
    pf = particle(:,n+1:n+n_obj);
end


% [优化函数] tournament_selection_optimized (使用 X-Dist 增强 PS 多样性)
function f = tournament_selection_optimized(chromosome, pool_size, tour_crowdsize, n, n_obj)
% 功能: DN-NSGAII 的锦标赛选择 (优先 Rank，其次 X-Dist (M+V+3))
    
    [pop, ~] = size(chromosome);
    rank_col = n+n_obj+1;
    x_dist_col = n+n_obj+3; % X-space distance
    
    if tour_crowdsize < 2
        tour_crowdsize = 2;
    end
    f = zeros(pool_size, size(chromosome, 2));
    
    for i = 1 : pool_size
        candidate_indices = randi(pop, 1, tour_crowdsize); 
        candidates = chromosome(candidate_indices, :);
        
        c_rank = candidates(:, rank_col);
        c_x_dist = candidates(:, x_dist_col); 
        
        min_rank = min(c_rank);
        best_rank_indices = find(c_rank == min_rank);
        
        if length(best_rank_indices) == 1
            f(i,:) = candidates(best_rank_indices(1),:);
        else
            best_candidates = candidates(best_rank_indices, :);
            best_x_dist = best_candidates(:, x_dist_col);
            
            max_x_dist = max(best_x_dist);
            max_x_dist_indices = find(best_x_dist == max_x_dist);
            
            if length(max_x_dist_indices) == 1
                final_choice_idx = best_rank_indices(max_x_dist_indices(1));
            else
                random_tie_break = randi(length(max_x_dist_indices));
                final_choice_idx = best_rank_indices(max_x_dist_indices(random_tie_break));
            end
            f(i,:) = candidates(final_choice_idx, :);
        end
    end
end


function f = non_domination_sort_mod(x, M, V)
% 功能: DN-NSGAII 的非支配排序和距离计算 (Rank, F-Dist, X-Dist)
    [N, ~] = size(x);
    front = 1;
    F(front).f = [];
    individual = [];
    
    % 1. 非支配排序
    for i = 1 : N
        individual(i).n = 0; 
        individual(i).p = [];
        for j = 1 : N
            dom_less = 0; dom_equal = 0; dom_more = 0;
            for k = 1 : M
                if (x(i,V + k) < x(j,V + k)), dom_less = dom_less + 1;
                elseif (x(i,V + k) == x(j,V + k)), dom_equal = dom_equal + 1;
                else, dom_more = dom_more + 1;
                end
            end
            if dom_less == 0 && dom_equal ~= M
                individual(i).n = individual(i).n + 1;
            elseif dom_more == 0 && dom_equal ~= M
                individual(i).p = [individual(i).p j];
            end
        end   
        if individual(i).n == 0
            x(i,M + V + 1) = 1;
            F(front).f = [F(front).f i];
        end
    end
    
    while ~isempty(F(front).f)
       Q = [];
       for i = 1 : length(F(front).f)
           if ~isempty(individual(F(front).f(i)).p)
            	for j = 1 : length(individual(F(front).f(i)).p)
                	individual(individual(F(front).f(i)).p(j)).n = ...
                    	individual(individual(F(front).f(i)).p(j)).n - 1;
            	   	if individual(individual(F(front).f(i)).p(j)).n == 0
                   		x(individual(F(front).f(i)).p(j),M + V + 1) = ...
                            front + 1;
                        Q = [Q individual(F(front).f(i)).p(j)];
                    end
                end
           end
       end
       front =  front + 1;
       F(front).f = Q;
    end
    [~,index_of_fronts] = sort(x(:,M + V + 1));
    
    if size(x, 1) > 1
        sorted_based_on_front = x(index_of_fronts,:);
    else
        sorted_based_on_front = x;
    end
    current_index = 0;
    
    % 2. 拥挤度计算 (F-Dist 和 X-Dist)
    z = sorted_based_on_front;
    if size(z, 2) < (M + V + 3 + M + V)
        z(:, M + V + 3 + M + V) = 0; % 预分配足够的列
    end
    for front = 1 : (length(F) - 1)
        previous_index = current_index + 1;
        if isempty(F(front).f), continue; end
        
        y = z(previous_index : previous_index + length(F(front).f) - 1, :);
        current_index = current_index + length(F(front).f);
        
        if length(F(front).f) <= 2
            y(:, M + V + 2) = Inf; % F-Dist
            y(:, M + V + 3) = Inf; % X-Dist
            z(previous_index:current_index,:) = y;
            continue;
        end
        
        % 循环 V 个决策变量 + M 个目标
        for i = 1 : M+V
            [~, index_of_objectives] = sort(y(:,i));
            y = y(index_of_objectives, :);
            
            f_max = y(end, i);
            f_min = y(1, i);
            
            y(1, M + V + 1 + i) = Inf;
            y(end, M + V + 1 + i) = Inf;
            
             for j = 2 : size(y,1) - 1
                next_obj  = y(j + 1, i);
                previous_obj  = y(j - 1,i);
                if (f_max - f_min == 0)
                    y(j, M + V + 1 + i) = Inf;
                else
                    y(j, M + V + 1 + i) = (next_obj - previous_obj) / (f_max - f_min);
                end
             end
        end
        
        % 计算 X-space distance (distance1) 和 F-space distance (distance)
        distance1 = zeros(size(y,1), 1);
        for i = 1 : V, distance1 = distance1 + y(:, M + V + 1 + i); end
        
        distance = zeros(size(y,1), 1);
        for i = 1 : M, distance = distance + y(:, M + V + 1 + V + i); end
        
        y(:,M + V + 2) = distance;
        y(:,M + V + 3) = distance1;
        
        z(previous_index:current_index,:) = y;
    end
    f = z(:, 1 : M + V + 3);
end

function f = genetic_operator(parent_chromosome, M, V, mu, mum, l_limit, u_limit, fname, integer_idx)
% 功能: NSGA-II 的遗传算子 (SBX Crossover 和 Polynomial Mutation)
global feval_count_global
[N,~] = size(parent_chromosome);
p = 1;
was_crossover = 0;
was_mutation = 0;
child = zeros(N, M + V); 
for i = 1 : N
    if rand(1) < 0.9 % 交叉率
        % SBX 交叉
        parent_1_idx = randi(N); parent_2_idx = randi(N);
        while parent_1_idx == parent_2_idx
            parent_2_idx = randi(N);
        end
        parent_1 = parent_chromosome(parent_1_idx,:);
        parent_2 = parent_chromosome(parent_2_idx,:);
        
        child_1 = zeros(1, V); child_2 = zeros(1, V);
        for j = 1 : V
            u = rand(1);
            if u <= 0.5
                bq = (2*u)^(1/(mu+1));
            else
                bq = (1/(2*(1 - u)))^(1/(mu+1));
            end
            child_1(j) = 0.5*(((1 + bq)*parent_1(j)) + (1 - bq)*parent_2(j));
            child_2(j) = 0.5*(((1 - bq)*parent_1(j)) + (1 + bq)*parent_2(j));
            
            % 边界检查
            child_1(j) = min(u_limit(j), max(l_limit(j), child_1(j)));
            child_2(j) = min(u_limit(j), max(l_limit(j), child_2(j)));
        end
          % Round integer variables first, then repair bounds, before feval.
          child_1(1:V) = RepairVariables(child_1(1:V), l_limit, u_limit, integer_idx);
          child_2(1:V) = RepairVariables(child_2(1:V), l_limit, u_limit, integer_idx);
          child_1(:,V + 1: M + V) = feval(fname,child_1(1:V));
          child_2(:,V + 1: M + V) = feval(fname,child_2(1:V));
          
          feval_count_global = feval_count_global+2;
        was_crossover = 1;
        was_mutation = 0;
    else
        % Polynomial Mutation
        parent_3_idx = randi(N);
        child_3 = parent_chromosome(parent_3_idx,:);
        
        for j = 1 : V
           r = rand(1);
           if r < 0.5
               delta = (2*r)^(1/(mum+1)) - 1;
           else
               delta = 1 - (2*(1 - r))^(1/(mum+1));
           end
           child_3(j) = child_3(j) + delta;
           
           % 边界检查
           child_3(j) = min(u_limit(j), max(l_limit(j), child_3(j)));
        end
        child_3(1:V) = RepairVariables(child_3(1:V), l_limit, u_limit, integer_idx);
        child_3(:,V + 1: M + V) = feval(fname,child_3(1:V));
        feval_count_global = feval_count_global+1;
        was_mutation = 1;
        was_crossover = 0;
    end
    if was_crossover && p + 1 <= N
        child(p,:) = child_1;
        child(p+1,:) = child_2;
        p = p + 2;
    elseif was_mutation && p <= N
        child(p,:) = child_3(1,1 : M + V);
        p = p + 1;
    end
end
f = child(1:p-1,:); % 截取有效子代
end

function f  = replace_chromosome(intermediate_chromosome, M, V,pop)
%第二判定标准选x空间距离，按x空间拥挤距离降序排列，选前几个
[N, m] = size(intermediate_chromosome);
% Get the index for the population sort based on the rank
[temp,index] = sort(intermediate_chromosome(:,M + V + 1));
clear temp m
% Now sort the individuals based on the index
for i = 1 : N
    sorted_chromosome(i,:) = intermediate_chromosome(index(i),:);
end
% Find the maximum rank in the current population
max_rank = max(intermediate_chromosome(:,M + V + 1));
% Start adding each front based on rank and crowing distance until the
% whole population is filled.
previous_index = 0;
for i = 1 : max_rank
    % Get the index for current rank i.e the last the last element in the
    % sorted_chromosome with rank i. 
    current_index = max(find(sorted_chromosome(:,M + V + 1) == i));
    % Check to see if the population is filled if all the individuals with
    % rank i is added to the population. 
    if current_index > pop
        % If so then find the number of individuals with in with current
        % rank i.
        remaining = pop - previous_index;
        % Get information about the individuals in the current rank i.
        temp_pop = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
        % Sort the individuals with rank i in the descending order based on
        % the crowding distance.
        [temp_sort,temp_sort_index] = ...
            sort(temp_pop(:, M + V + 3),'descend');
        % Start filling individuals into the population in descending order
        % until the population is filled.
        for j = 1 : remaining
            f(previous_index + j,:) = temp_pop(temp_sort_index(j),:);
        end
        return;
    elseif current_index < pop
        % Add all the individuals with rank i into the population.
        f(previous_index + 1 : current_index, :) = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
    else
        % Add all the individuals with rank i into the population.
        f(previous_index + 1 : current_index, :) = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
        return;
    end
    % Get the index for the last added individual.
    previous_index = current_index;
end
end

function X = Checkbound(X, L, U, pop, dim)
% 功能: 边界检查
    L_matrix = repmat(L, pop, 1);
    U_matrix = repmat(U, pop, 1);
    
    lower_viol = X < L_matrix;
    upper_viol = X > U_matrix;
    
    X(lower_viol) = L_matrix(lower_viol);
    X(upper_viol) = U_matrix(upper_viol);
end

function X = RepairVariables(X, L, U, integer_idx)
%REPAIRVARIABLES Enforce integrality before boundary repair.
% Every objective evaluation therefore receives a feasible mixed-integer
% design, while continuous columns remain unchanged.
    if ~isempty(integer_idx)
        X(:, integer_idx) = round(X(:, integer_idx));
    end
    X = max(X, repmat(L, size(X,1), 1));
    X = min(X, repmat(U, size(X,1), 1));
end
