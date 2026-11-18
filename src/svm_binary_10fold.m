%% ===================== 健康 vs 发作间期：二分类 SVM（10 折交叉验证） =====================
% 用途：在波恩脑电数据集的 16 维特征上做「健康(Z/O) vs 发作间期(N/F)」二分类
% 输入：data/bonn_features.mat（由 src/main_extract_features.m 生成）
% 输出：控制台指标 + results/svm_binary_confusion.png
% 依赖：MATLAB R2021b 及以上，Statistics and Machine Learning Toolbox
%
% 【口径说明】本脚本做的是**片段级分类**，不是时间序列上的发作预测。
%   波恩数据集的 C/D 组是发作间期（interictal），E 组才是发作期（ictal）；
%   数据集本身不含发作前（preictal）的时间窗，因此不能称为"预测"。
%   另外 10 折按片段随机划分，未做患者级隔离，准确率可能偏高。
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
load(fullfile(rootDir, 'data', 'bonn_features.mat'));
rng(42);   % 固定随机种子，保证结果可复现

%% ---------- 1. 构建数据集 ----------
% 只取 Z/O/N/F 四类，去掉 S（发作期）
X = global_feature_matrix(:, 1:16);
y_original = global_feature_matrix(:, 17);

idx = find(y_original == 1 | y_original == 2 | y_original == 3 | y_original == 4);
X_pred = X(idx, :);
y_pred_label = y_original(idx);

% 二分类标签：0 = 健康(Z/O)，1 = 发作间期(N/F)
y_binary = zeros(size(y_pred_label));
y_binary(y_pred_label == 3 | y_pred_label == 4) = 1;

% 强制指定类别顺序，防止混淆矩阵算反
y_binary = categorical(y_binary, [0, 1], {'健康(Z/O)', '发作间期(N/F)'});
category_names = {'健康(Z/O)', '发作间期(N/F)'};

%% ---------- 2. 10 折交叉验证 ----------
cv = cvpartition(y_binary, 'Kfold', 10);

acc_all = []; sens_all = []; spec_all = []; prec_all = []; f1_all = [];
cm_total = zeros(2, 2);

for i = 1:cv.NumTestSets
    X_train = X_pred(training(cv, i), :);
    y_train = y_binary(training(cv, i));
    X_test = X_pred(test(cv, i), :);
    y_test = y_binary(test(cv, i));

    % RBF 核 SVM，内部自动标准化（不提前 zscore，避免数据泄露）
    model = fitcsvm(X_train, y_train, ...
        'KernelFunction', 'rbf', ...
        'Standardize', true);

    y_pred = predict(model, X_test);

    cm = confusionmat(y_test, y_pred, 'Order', categories(y_binary));
    cm_total = cm_total + cm;

    TN = cm(1, 1); FP = cm(1, 2);
    FN = cm(2, 1); TP = cm(2, 2);

    acc  = (TP + TN) / (TP + TN + FP + FN + eps);
    sens = TP / (TP + FN + eps);          % 灵敏度（发作间期被正确检出）
    spec = TN / (TN + FP + eps);          % 特异性（健康被正确排除）
    prec = TP / (TP + FP + eps);
    f1   = 2 * prec * sens / (prec + sens + eps);

    acc_all  = [acc_all;  acc];
    sens_all = [sens_all; sens];
    spec_all = [spec_all; spec];
    prec_all = [prec_all; prec];
    f1_all   = [f1_all;   f1];
end

%% ---------- 3. 汇总 ----------
acc_mean  = mean(acc_all);
sens_mean = mean(sens_all);
spec_mean = mean(spec_all);
prec_mean = mean(prec_all);
f1_mean   = mean(f1_all);

fprintf('===== 健康 vs 发作间期 二分类（10 折交叉验证）=====\n');
fprintf('平均准确率：%.2f%%\n', acc_mean  * 100);
fprintf('平均灵敏度：%.2f%%\n', sens_mean * 100);
fprintf('平均特异性：%.2f%%\n', spec_mean * 100);
fprintf('平均精确率：%.2f%%\n', prec_mean * 100);
fprintf('平均 F1    ：%.2f%%\n', f1_mean   * 100);
fprintf('==================================================\n');

%% ---------- 4. 混淆矩阵 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 700, 500]);
imagesc(cm_total); colorbar; colormap(jet);
title(sprintf('10 折总和混淆矩阵\n准确率：%.2f%%  灵敏度：%.2f%%  特异性：%.2f%%', ...
    acc_mean * 100, sens_mean * 100, spec_mean * 100), 'FontSize', 13);
xlabel('预测类别'); ylabel('真实类别');
set(gca, 'XTick', 1:2, 'XTickLabel', category_names);
set(gca, 'YTick', 1:2, 'YTickLabel', category_names);
xtickangle(45);

for i = 1:2
    for j = 1:2
        text(j, i, num2str(cm_total(i, j)), ...
            'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 14);
    end
end

saveas(gcf, fullfile(outDir, 'svm_binary_confusion.png'));
fprintf('混淆矩阵已保存至 results/svm_binary_confusion.png\n');
