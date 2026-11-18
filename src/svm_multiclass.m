%% ===================== 五类状态多分类 SVM =====================
% 用途：把 Z/O/N/F/S 五类一起分类，看模型能否区分到具体状态
% 输入：data/bonn_features.mat
% 输出：控制台混淆矩阵 + results/svm_multiclass_confusion.png
% 依赖：MATLAB R2021b 及以上，Statistics and Machine Learning Toolbox
%
% 说明：五类中 Z/O 来自健康志愿者，C/D 来自癫痫患者发作间期，E 来自发作期；
%       健康人与患者来自不同记录条件，因此多分类准确率天然会偏高。
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
load(fullfile(rootDir, 'data', 'bonn_features.mat'));
rng(42);

%% ---------- 1. 数据准备 ----------
X = zscore(global_feature_matrix(:, 1:16));
y = categorical(global_feature_matrix(:, 17));
category_names = {'睁眼正常(Z)', '闭眼正常(O)', '发作间期(N)', '发作间期(F)', '癫痫发作(S)'};

%% ---------- 2. 分层划分 70/30 ----------
cv = cvpartition(y, 'HoldOut', 0.3, 'Stratify', true);
X_train = X(training(cv), :);  y_train = y(training(cv));
X_test  = X(test(cv), :);      y_test  = y(test(cv));

%% ---------- 3. 训练多分类 SVM（一对多编码） ----------
model = fitcecoc(X_train, y_train, ...
    'Learners', 'svm', ...
    'FitPosterior', true, ...
    'Verbose', false);

%% ---------- 4. 评估 ----------
y_pred = predict(model, X_test);
acc = mean(y_pred == y_test);

fprintf('===== 五类状态多分类 SVM =====\n');
fprintf('总体准确率：%.2f%%\n', acc * 100);
fprintf('------------------------------\n');

conf_mat = confusionmat(y_test, y_pred);
disp('混淆矩阵（行=真实，列=预测）：');
disp(conf_mat);
disp('类别对应：1=Z 2=O 3=N 4=F 5=S');

%% ---------- 5. 混淆矩阵热力图 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 800, 600]);
imagesc(conf_mat); colorbar; colormap(parula);
title(sprintf('SVM 多分类混淆矩阵（准确率：%.2f%%）', acc * 100), 'FontSize', 14);
xlabel('预测类别', 'FontSize', 12);
ylabel('真实类别', 'FontSize', 12);
set(gca, 'XTick', 1:5, 'XTickLabel', category_names);
set(gca, 'YTick', 1:5, 'YTickLabel', category_names);
xtickangle(45);

for i = 1:5
    for j = 1:5
        text(j, i, num2str(conf_mat(i, j)), ...
            'HorizontalAlignment', 'center', 'Color', 'black', 'FontSize', 10);
    end
end

print(gcf, fullfile(outDir, 'svm_multiclass_confusion.png'), '-dpng', '-r300');
fprintf('混淆矩阵已保存至 results/svm_multiclass_confusion.png\n');
