%% ===================== 核心特征箱线图 =====================
% 用途：对比三个最具区分度的特征在五类状态下的分布，
%       用来说明「为什么选这几个特征」
% 输入：data/bonn_features.mat
% 输出：results/feature_boxplot.png
% 依赖：MATLAB R2021b 及以上，Statistics and Machine Learning Toolbox
%
% 选中的三个特征：
%   过零率（第 10 列）—— 反映信号振荡快慢
%   均方根（第 6 列）—— 反映信号能量
%   α 功率占比（第 14 列）—— 反映 8-13 Hz 节律强弱
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
load(fullfile(rootDir, 'data', 'bonn_features.mat'));

feature_idx = [10, 6, 14];
feature_names_sub = feature_names(feature_idx);
category_names = {'睁眼正常(Z)', '闭眼正常(O)', '发作间期(N)', '发作间期(F)', '癫痫发作(S)'};

%% ---------- 按标签分组 ----------
feature_group = cell(5, 1);
for i = 1:5
    idx = global_feature_matrix(:, 17) == i;
    feature_group{i} = global_feature_matrix(idx, feature_idx);
end

outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 1800, 600]);

%% ---------- 子图 1：过零率 ----------
subplot(1, 3, 1);
boxplot([feature_group{1}(:, 1), feature_group{2}(:, 1), feature_group{3}(:, 1), ...
         feature_group{4}(:, 1), feature_group{5}(:, 1)], ...
    'Labels', category_names, 'BoxStyle', 'outline');
title(['特征分布：', feature_names_sub{1}], 'FontSize', 14, 'FontWeight', 'normal');
ylabel('过零率（归一化）', 'FontSize', 12);
xtickangle(30);
grid on; grid minor;

h = findobj(gca, 'Tag', 'Box');
if length(h) >= 4
    set(h(4), 'Color', '#2E8B57', 'LineWidth', 2);   % 标绿：闭眼正常(O)
end
ylim([0.05, 0.32]);

%% ---------- 子图 2：均方根 ----------
subplot(1, 3, 2);
boxplot([feature_group{1}(:, 2), feature_group{2}(:, 2), feature_group{3}(:, 2), ...
         feature_group{4}(:, 2), feature_group{5}(:, 2)], ...
    'Labels', category_names, 'BoxStyle', 'outline');
title(['特征分布：', feature_names_sub{2}], 'FontSize', 14, 'FontWeight', 'normal');
xlabel('EEG 类别', 'FontSize', 12);
ylabel('均方根（RMS）', 'FontSize', 12);
xtickangle(30);
grid on; grid minor;

h = findobj(gca, 'Tag', 'Box');
if length(h) >= 1
    set(h(1), 'Color', '#DC143C', 'LineWidth', 2);   % 标红：癫痫发作(S)
end
ylim([0, 650]);

%% ---------- 子图 3：α 功率占比 ----------
subplot(1, 3, 3);
boxplot([feature_group{1}(:, 3), feature_group{2}(:, 3), feature_group{3}(:, 3), ...
         feature_group{4}(:, 3), feature_group{5}(:, 3)], ...
    'Labels', category_names, 'BoxStyle', 'outline');
title(['特征分布：', feature_names_sub{3}], 'FontSize', 14, 'FontWeight', 'normal');
xlabel('EEG 类别', 'FontSize', 12);
ylabel('α 波功率占比（%）', 'FontSize', 12);
xtickangle(30);
grid on; grid minor;

h = findobj(gca, 'Tag', 'Box');
if length(h) >= 4
    set(h(4), 'Color', '#2E8B57', 'LineWidth', 2);   % 标绿：闭眼正常(O)
end
ylim([0, 85]);

sgtitle('波恩数据集核心特征分布对比', 'FontSize', 16, 'FontWeight', 'bold');
set(gcf, 'DefaultAxesPosition', [0.08 0.1 0.26 0.75]);
set(subplot(1, 3, 2), 'Position', [0.38 0.1 0.26 0.75]);
set(subplot(1, 3, 3), 'Position', [0.68 0.1 0.26 0.75]);

print(gcf, fullfile(outDir, 'feature_boxplot.png'), '-dpng', '-r300');
fprintf('箱线图已保存至 results/feature_boxplot.png\n');
