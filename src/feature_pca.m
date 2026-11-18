%% ===================== PCA 特征有效性验证 =====================
% 用途：把 16 维特征投影到前两个主成分，看五类样本在低维空间是否可分，
%       以此判断手工特征本身是否携带足够的类别信息
% 输入：data/bonn_features.mat
% 输出：控制台贡献率 + results/pca_scatter.png
% 依赖：MATLAB R2021b 及以上，Statistics and Machine Learning Toolbox
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
load(fullfile(rootDir, 'data', 'bonn_features.mat'));

%% ---------- 1. 取特征与标签 ----------
X = global_feature_matrix(:, 1:16);   % 1-16 列是特征
y = global_feature_matrix(:, 17);     % 第 17 列是标签（1-5）
category_names = {'睁眼正常(Z)', '闭眼正常(O)', '发作间期(N)', '发作间期(F)', '癫痫发作(S)'};

%% ---------- 2. 标准化后做 PCA ----------
X = zscore(X);

[coeff, score, latent, ~, explained] = pca(X);
% coeff(:,i)  第 i 个主成分由哪些原始特征组成
% score(i,j)  第 i 个样本在第 j 个主成分上的坐标
% latent(i)   第 i 个主成分的方差（信息量）
% explained(i) 第 i 个主成分的方差占比

fprintf('PC1 贡献率：%.2f%%\n', explained(1));
fprintf('PC2 贡献率：%.2f%%\n', explained(2));
fprintf('累计贡献率：%.2f%%\n', sum(explained(1:2)));

%% ---------- 3. 二维散点 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 800, 700]);
colors  = {[0, 0.45, 0.74], [0.85, 0.33, 0.10], [0.93, 0.69, 0.13], [0.49, 0.18, 0.56], [0.0, 0.6, 0.22]};
markers = {'o', 's', '^', 'd', 'p'};

for i = 1:5
    idx = y == i;
    scatter(score(idx, 1), score(idx, 2), 50, ...
        colors{i}, 'filled', ...
        'MarkerEdgeColor', 'k', ...
        'Marker', markers{i});
    hold on;
end

xlabel(sprintf('主成分 1 (PC1) — 贡献度 %.1f%%', explained(1)), 'FontSize', 11);
ylabel(sprintf('主成分 2 (PC2) — 贡献度 %.1f%%', explained(2)), 'FontSize', 11);
title('16 维特征 PCA 降维分布（验证特征有效性）', 'FontSize', 14, 'FontWeight', 'bold');
legend(category_names, 'Location', 'bestoutside');
grid on; box on;

print(gcf, fullfile(outDir, 'pca_scatter.png'), '-dpng', '-r300');
fprintf('PCA 图已保存至 results/pca_scatter.png\n');
