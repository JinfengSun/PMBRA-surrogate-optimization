%% 多目标优化算法比较主函数
% 功能：在MMF测试函数集上比较算法性能（NSGAII, DN_NSGAII, SPD_DN_SGAII）
% 输出指标（PSP、HV、IGD、IGDX）及可视化结果

%% 1. Add repository-relative paths
clear all; clc; close all;
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'problems'));
addpath(fullfile(script_dir, 'reference_data'));
addpath(fullfile(script_dir, 'indicators'));
addpath(fullfile(repo_root, 'optimization', 'algorithms'));

%% 2. Initialize shared objective-function name
global fname;  % 全局变量：目标函数名，供算法内部调用

%% 3. 比较参数设置
N_function = 22;    % 测试函数数量
runtimes = 31;      % 每个函数运行次数（奇数，便于取中位数）

%% 4. 存储所有结果的结构体（预定义）

% 存储 NSGAII 结果
Table.NSGAII.rPSP = zeros(N_function, runtimes+5);
Table.NSGAII.rHV = zeros(N_function, runtimes+5);
Table.NSGAII.IGDX = zeros(N_function, runtimes+5);
Table.NSGAII.IGDF = zeros(N_function, runtimes+5);
% 存储 DN_NSGAII 结果
Table.DN_NSGAII.rPSP = zeros(N_function, runtimes+5);
Table.DN_NSGAII.rHV = zeros(N_function, runtimes+5);
Table.DN_NSGAII.IGDX = zeros(N_function, runtimes+5);
Table.DN_NSGAII.IGDF = zeros(N_function, runtimes+5);
% 存储 SPD_DN_SGAII 结果
Table.SPD_DN_NSGAII.rPSP = zeros(N_function, runtimes+5);
Table.SPD_DN_NSGAII.rHV = zeros(N_function, runtimes+5);
Table.SPD_DN_NSGAII.IGDX = zeros(N_function, runtimes+5);
Table.SPD_DN_NSGAII.IGDF = zeros(N_function, runtimes+5);

%% 5. Initialize the parameters in MMO test functions
for i_func=1:N_function
    switch i_func
        case 1
            fname='MMF1';  
            n_obj=2;       
            n_var=2;       
            xl=[1 -1];     
            xu=[3 1];      
            repoint=[1.1,1.1]; 
        case 2
            fname='MMF2';
            n_obj=2;
            n_var=2;
            xl=[0 0];
            xu=[1 2];
            repoint=[1.1,1.1];
        case 3
            fname='MMF3';
            n_obj=2;
            n_var=2;
            xl=[0 0];
            xu=[1 1.5];
            repoint=[1.1,1.1];
        case 4
            fname='MMF4';
            n_obj=2;
            n_var=2;
            xl=[-1 0];
            xu=[1 2];
            repoint=[1.1,1.1];
        case 5
            fname='MMF5';
            n_obj=2;
            n_var=2;
            xl=[1 -1];
            xu=[3 3];
            repoint=[1.1,1.1];
         case 6
            fname='MMF6';
            n_obj=2;
            n_var=2;
            xl=[1 -1];
            xu=[3 2];
            repoint=[1.1,1.1];
        case 7
            fname='MMF7';
            n_obj=2;
            n_var=2;
            xl=[1 -1];
            xu=[3 1];
            repoint=[1.1,1.1];
         case 8
            fname='MMF8';
            n_obj=2;
            n_var=2;
            xl=[-pi 0];
            xu=[pi 9];
           repoint=[1.1,1.1];
          case 9
            fname='MMF9';  
            n_obj=2;       
            n_var=2;       
            xl=[0.1 0.1];     
            xu=[1.1 1.1];      
            repoint=[1.21,11]; 
        case 10
           fname='MMF10';  
            n_obj=2;       
            n_var=2;       
            xl=[0.1 0.1];     
            xu=[1.1 1.1];      
           repoint=[1.21,13.2]; 
        case 11
            fname='MMF11';  
            n_obj=2;       
            n_var=2;       
            xl=[0.1 0.1];     
            xu=[1.1 1.1];      
            repoint=[1.21,15.4];
        case 12
            fname='MMF12';  
            n_obj=2;       
            n_var=2;       
            xl=[0 0];     
            xu=[1 1];      
            repoint=[1.54,1.1];
         case 13
             %*need to be modified
            fname='MMF13';  
            n_obj=2;       
            n_var=3;       
            xl=[0.1 0.1 0.1];     
            xu=[1.1 1.1 1.1];      
            repoint=[1.54,15.4];
         case 14
            fname='MMF14';  
            n_obj=3;       
            n_var=3;       
            xl=[0 0 0];     
            xu=[1 1 1];      
            repoint=[2.2,2.2,2.2];
          case 15
            fname='MMF15';  
            n_obj=3;       
            n_var=3;       
            xl=[0 0 0];     
            xu=[1 1 1];      
            repoint=[2.5,2.5,2.5];
         case 16
            fname='MMF1_z';  
            n_obj=2;       
            n_var=2;       
            xl=[1 -1];     
            xu=[3 1];      
            repoint=[1.1,1.1];
        case 17
            fname='MMF1_e';  
            n_obj=2;       
            n_var=2;       
            xl=[1 -20];     
            xu=[3 20];      
            repoint=[1.1,1.1];
        case 18
            fname='MMF14_a';  
            n_obj=3;
            n_var=3;
            xl=[0 0 0];
            xu=[1 1 1];
            repoint=[2.2,2.2,2.2];
        case 19
            fname='MMF15_a';  
            n_obj=3;
            n_var=3;
            xl=[0 0 0];
            xu=[1 1 1]; 
            repoint=[2.5,2.5,2.5];
        case 20
            fname='SYM_PART_simple';
            n_obj=2;
            n_var=2;
            xl=[-20 -20];
            xu=[20 20];
            repoint=[4.4,4.4];
         case 21
            fname='SYM_PART_rotated';
            n_obj=2;
            n_var=2;
            xl=[-20 -20];
            xu=[20 20];
            repoint=[4.4,4.4];
        case 22
            fname='Omni_test';
            n_obj=2;
            n_var=3;
            xl=[0 0 0];
            xu=[6 6 6];
            repoint=[4.4,4.4];
    end
    
    %% 5.2 加载参考解集
    load(strcat(fname, '_Reference_PSPF_data'), 'PS', 'PF');
    
    %% 5.3 设置算法参数
    popsize = 100 * n_var;
    Max_fevs = 10000 * n_var;
    Max_Gen = fix(Max_fevs / popsize);
    
    %% 5.4 多次运行三种算法并计算指标
    for j = 1:runtimes
        fprintf('正在运行测试函数 %s（第%d/%d次）...\n', fname, j, runtimes);
                  
            [ps1, pf1] = NSGAII(fname, xl, xu, n_obj, popsize, Max_Gen);
            hyp1 = Hypervolume_calculation(pf1, repoint);
            IGDx1 = IGD_calculation(ps1, PS);
            IGDf1 = IGD_calculation(pf1, PF);
            CR1 = CR_calculation(ps1, PS);
            PSP1 = CR1 / IGDx1;
            Indicator1 = [1./PSP1, 1./hyp1, IGDx1, IGDf1];
            Table.NSGAII.rPSP(i_func, j) = Indicator1(1);
            Table.NSGAII.rHV(i_func, j) = Indicator1(2);
            Table.NSGAII.IGDX(i_func, j) = Indicator1(3);
            Table.NSGAII.IGDF(i_func, j) = Indicator1(4);

            [ps2, pf2] = DN_NSGAII(fname, xl, xu, n_obj, popsize, Max_Gen); 
            hyp2 = Hypervolume_calculation(pf2, repoint);
            IGDx2 = IGD_calculation(ps2, PS);
            IGDf2 = IGD_calculation(pf2, PF);
            CR2 = CR_calculation(ps2, PS);
            PSP2 = CR2 / IGDx2;
            Indicator2 = [1./PSP2, 1./hyp2, IGDx2, IGDf2];
            Table.DN_NSGAII.rPSP(i_func, j) = Indicator2(1);
            Table.DN_NSGAII.rHV(i_func, j) = Indicator2(2);
            Table.DN_NSGAII.IGDX(i_func, j) = Indicator2(3);
            Table.DN_NSGAII.IGDF(i_func, j) = Indicator2(4);
            
       
            [ps3, pf3] = SPD_DN_NSGAII_Optimized(fname, xl, xu, n_obj, popsize, Max_Gen); 
            hyp3 = Hypervolume_calculation(pf3, repoint);
            IGDx3 = IGD_calculation(ps3, PS);
            IGDf3 = IGD_calculation(pf3, PF);
            CR3 = CR_calculation(ps3, PS);
            PSP3 = CR3 / IGDx3;
            Indicator3 = [1./PSP3, 1./hyp3, IGDx3, IGDf3];
            Table.SPD_DN_NSGAII.rPSP(i_func, j) = Indicator3(1);
            Table.SPD_DN_NSGAII.rHV(i_func, j) = Indicator3(2);
            Table.SPD_DN_NSGAII.IGDX(i_func, j) = Indicator3(3);
            Table.SPD_DN_NSGAII.IGDF(i_func, j) = Indicator3(4);


        clear ps1 pf1 hyp1 IGDx1 IGDf1 CR1 PSP1 Indicator1
        clear ps2 pf2 hyp2 IGDx2 IGDf2 CR2 PSP2 Indicator2
        clear ps3 pf3 hyp3 IGDx3 IGDf3 CR3 PSP3 Indicator3
    end
    
    %% 5.5 计算每个函数的统计指标（min,max,mean,median,std）
    algorithms = {'NSGAII', 'DN_NSGAII', 'SPD_DN_NSGAII'};
    metrics = {'rPSP','rHV','IGDX','IGDF'};
    for a = 1:length(algorithms)
        for m = 1:length(metrics)
            data = Table.(algorithms{a}).(metrics{m})(i_func, 1:runtimes);
            stats = [min(data), max(data), mean(data), median(data), std(data)];
            Table.(algorithms{a}).(metrics{m})(i_func, runtimes+1:runtimes+5) = stats;
        end
    end
    
   %% 5.6 可视化当前函数的结果（中位数PS）
    
    [ps1_med, ~] = NSGAII(fname, xl, xu, n_obj, popsize, Max_Gen);
    [ps2_med, ~] = DN_NSGAII(fname, xl, xu, n_obj, popsize, Max_Gen);
    [ps3_med, ~] = SPD_DN_NSGAII_Optimized(fname, xl, xu, n_obj, popsize, Max_Gen);

    
    % --- 专业的颜色和标记定义 ---
    % 颜色遵循冷暖色调，避免混淆；标记使用不同形状增强区分度
    Color_True = [0 0 0];       % 黑色 (True PS)
    Color_NSGAII = [0 0 0.8];   % 深红
    Color_DN = [0 0.5 0];       % 深绿
    Color_SPD = [0 0 0.8];      % 深蓝

    Marker_True = '+';
    Marker_NSGAII = 'o';
    Marker_DN = 's'; % 方块
    Marker_SPD = '^'; % 三角

    FigureHandle = figure('Name', sprintf('测试函数%s的决策空间PS对比', fname));
    FigureHandle.Position = [100 100 800 600]; % 设置图窗大小

    if n_var == 2
        % --- 2D 绘图 ---
        plot(PS(:,1), PS(:,2), Marker_True, 'Color', Color_True, ...
             'MarkerSize', 8, 'LineWidth', 1.5); hold on;
        
        plot(ps1_med(:,1), ps1_med(:,2), Marker_NSGAII, 'Color', Color_NSGAII, ...
             'MarkerSize', 6, 'MarkerFaceColor', Color_NSGAII, 'LineStyle', 'none');   % NSGAII
        
        plot(ps2_med(:,1), ps2_med(:,2), Marker_DN, 'Color', Color_DN, ...
             'MarkerSize', 6, 'MarkerFaceColor', Color_DN, 'LineStyle', 'none');   % DN_NSGAII
        
        plot(ps3_med(:,1), ps3_med(:,2), Marker_SPD, 'Color', Color_SPD, ...
             'MarkerSize', 6, 'MarkerFaceColor', Color_SPD, 'LineStyle', 'none');   % SPD_DN_SGAII
        
        
        xlabel('Decision Variable 1', 'FontSize', 14, 'FontName', 'Times New Roman');
        ylabel('Decision Variable 2', 'FontSize', 14, 'FontName', 'Times New Roman');
        
    elseif n_var == 3
        % --- 3D 绘图 ---
        plot3(PS(:,1), PS(:,2), PS(:,3), Marker_True, 'Color', Color_True, ...
              'MarkerSize', 8, 'LineWidth', 1.5); hold on;
          
        plot3(ps1_med(:,1), ps1_med(:,2), ps1_med(:,3), Marker_NSGAII, 'Color', Color_NSGAII, ...
              'MarkerSize', 6, 'MarkerFaceColor', Color_NSGAII, 'LineStyle', 'none'); % NSGAII
          
        plot3(ps2_med(:,1), ps2_med(:,2), ps2_med(:,3), Marker_DN, 'Color', Color_DN, ...
              'MarkerSize', 6, 'MarkerFaceColor', Color_DN, 'LineStyle', 'none'); % DN_NSGAII
          
        plot3(ps3_med(:,1), ps3_med(:,2), ps3_med(:,3), Marker_SPD, 'Color', Color_SPD, ...
              'MarkerSize', 6, 'MarkerFaceColor', Color_SPD, 'LineStyle', 'none'); % SPD_DN_SGAII
          
          
        xlabel('Decision Variable 1', 'FontSize', 14, 'FontName', 'Times New Roman');
        ylabel('Decision Variable 2', 'FontSize', 14, 'FontName', 'Times New Roman');
        zlabel('Decision Variable 3', 'FontSize', 14, 'FontName', 'Times New Roman');
        
        view(3); % 设置为 3D 视图
    end
    
    % --- 通用美化设置 ---
    
    % 标题和图例
    TitleText = sprintf('Pareto Set (PS) Comparison in Decision Space for %s', fname);
    title(TitleText, 'FontSize', 16, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    
    legend('True PS', 'NSGAII', 'DN-NSGAII', 'SPD-DN-NSGAII', 'Location', 'best', 'FontSize', 10, 'FontName', 'Times New Roman');
    
    grid on; % 添加网格线
    box on;  % 显示图形边框
    
    % 标准化坐标轴刻度线字体
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman', ...
             'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', ... % 确保 3D 网格也开启
             'LineWidth', 1); % 轴线加粗

    hold off; % End plot hold state
    
    fprintf('测试函数 %s 比较完成！\n\n', fname);
    
end
%% 6. 最终保存所有结果为单个 Table
results_dir = fullfile(script_dir, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save(fullfile(results_dir, 'All_Algorithms_Comparison_Results3.mat'), 'Table');
fprintf('所有测试函数比较完成，结果已保存为 Table。\n');
