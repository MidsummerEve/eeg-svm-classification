%% ===================== 健康 vs 发作间期：二分类 SVM（70/30 划分 + 类别加权） =====================
% 用途：hold-out 划分下的二分类，用类别权重平衡两类样本，对照 10 折版本
% 输入：data/bonn_features.mat
% 输出：控制台指标 + results/svm_binary_weighted.png
% 依赖：MATLAB R2021b 及以上，Statistics and Machine Learning Toolbox
%
% 与 svm_binary_10fold.m 的区别：
%   - 本脚本用 70/30 单次划分，10 折版本做交叉验证
%   - 本脚本手动计算类别权重（Weights），适合低版本 MATLAB（无 ClassWeights 参数）
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
load(fullfile(rootDir, 'data', 'bonn_features.mat'));
rng(42);

%% ---------- 1. 数据准备 ----------
X = zscore(global_feature_matrix(:, 1:16));   % 16 个特征标准化
y_original = global_feature_matrix(:, 17);    % 原始 5 类标签

% 二分类：Z/O/N/F(1-4) = 0，S(5) = 1
y_binary = zeros(size(y_original));
y_binary(y_original == 5) = 1;
y_binary = categorical(y_binary);
category_names = {'正常/间期(Z/O/N/F)', '癫痫发作(S)'};

%% ---------- 2. 分层划分 70/30 ----------
cv = cvpartition(y_binary, 'HoldOut', 0.3, 'Stratify', true);
X_train = X(training(cv), :);  y_train = y_binary(training(cv));
X_test  = X(test(cv), :);      y_test  = y_binary(test(cv));

%% ---------- 3. 手动计算类别权重 ----------
n0 = sum(y_train == '0');
n1 = sum(y_train == '1');
weights_train = zeros(size(y_train));
weights_train(y_train == '0') = (n0 + n1) / (2 * n0);
weights_train(y_train == '1') = (n0 + n1) / (2 * n1);

%% ---------- 4. 训练 RBF-SVM ----------
model = fitcsvm(X_train, y_train, ...
    'KernelFunction', 'rbf', ...
    'BoxConstraint', 1, ...
    'Weights', weights_train, ...
    'Verbose', false);

%% ---------- 5. 评估 ----------
y_pred = predict(model, X_test);
acc = mean(y_pred == y_test);
conf_mat = confusionmat(y_test, y_pred);

if (conf_mat(1, 2) + conf_mat(2, 2)) == 0
    precision = 0;
else
    precision = conf_mat(2, 2) / (conf_mat(1, 2) + conf_mat(2, 2));
end

if (conf_mat(2, 1) + conf_mat(2, 2)) == 0
    recall = 0;
else
    recall = conf_mat(2, 2) / (conf_mat(2, 1) + conf_mat(2, 2));
end

fprintf('===== 二分类 SVM（70/30 + 类别加权）=====\n');
fprintf('总体准确率：%.2f%%\n', acc * 100);
fprintf('癫痫发作类(S) 精准率：%.2f%%\n', precision * 100);
fprintf('癫痫发作类(S) 召回率：%.2f%%\n', recall * 100);
fprintf('----------------------------------------\n');
disp('混淆矩阵（行=真实，列=预测）：');
disp(['真实：正常/间期  ', num2str(conf_mat(1, 1)), '  ', num2str(conf_mat(1, 2))]);
disp(['真实：癫痫发作   ', num2str(conf_mat(2, 1)), '  ', num2str(conf_mat(2, 2))]);

%% ---------- 6. 混淆矩阵 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 700, 500]);
imagesc(conf_mat); colorbar; colormap(jet);
title(sprintf('二分类 SVM 混淆矩阵（准确率：%.2f%%）', acc * 100), 'FontSize', 14);
xlabel('预测类别', 'FontSize', 12);
ylabel('真实类别', 'FontSize', 12);
set(gca, 'XTick', 1:2, 'XTickLabel', category_names);
set(gca, 'YTick', 1:2, 'YTickLabel', category_names);
xtickangle(45);

for i = 1:2
    for j = 1:2
        text(j, i, num2str(conf_mat(i, j)), ...
            'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 12);
    end
end

print(gcf, fullfile(outDir, 'svm_binary_weighted.png'), '-dpng', '-r300');
fprintf('混淆矩阵已保存至 results/svm_binary_weighted.png\n');
