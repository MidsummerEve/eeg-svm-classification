%% ===================== 主流程：读取波恩数据集 → 预处理 → 提取特征 → 存 mat =====================
% 用途：遍历五个类别目录，逐文件做预处理并提取 16 维特征，汇总成特征矩阵
% 输入：data/bonn/{A_Z, B_O, C_N, D_F, E_S}/*.txt（波恩数据集原始片段）
% 输出：data/bonn_features.mat（后续所有模型脚本的输入）
%       results/preprocess_compare_*.png（每类取首文件做时域/频域对比）
% 依赖：MATLAB R2021b 及以上，Signal Processing Toolbox
%
% 特征清单（16 维）：
%   时域 9 个：均值、标准差、方差、峰度、偏度、均方根、最大值、最小值、绝对均值
%   过零率 1 个
%   频域 6 个：总功率 + δ/θ/α/β/γ 五个频段功率占比
% 第 17 列为类别标签（1-5），第 18 列为文件夹索引
% =====================================================================================

clear; clc; close all;

rootDir  = fileparts(fileparts(mfilename('fullpath')));
dataRoot = fullfile(rootDir, 'data', 'bonn');

folders = {'A_Z', 'B_O', 'C_N', 'D_F', 'E_S'};
labels  = [1, 2, 3, 4, 5];
label_names = {'睁眼正常(Z)', '闭眼正常(O)', '发作间期(N)', '发作间期(F)', '癫痫发作(S)'};

fs         = 173.61;      % 波恩数据集采样率
notch_freq = 50;          % 工频
passband   = [0.5, 40];   % 脑电有效频段

global_feature_matrix = [];
global_file_info = [];

%% ---------- 1. 逐类逐文件处理 ----------
for folder_idx = 1:length(folders)
    current_folder = fullfile(dataRoot, folders{folder_idx});
    if ~exist(current_folder, 'dir')
        fprintf('警告：目录不存在，跳过 -> %s\n', current_folder);
        continue;
    end

    file_list = dir(fullfile(current_folder, '*.txt'));
    n_files = length(file_list);
    fprintf('\n处理 %s（%s），共 %d 个文件\n', ...
        folders{folder_idx}, label_names{folder_idx}, n_files);

    for file_idx = 1:n_files
        file_name = file_list(file_idx).name;
        file_path = fullfile(current_folder, file_name);
        try
            eeg_raw = load(file_path);
            eeg_raw = eeg_raw(:);

            % 预处理
            eeg_clean = eeg_preprocess(eeg_raw, fs, notch_freq, passband);

            % ---------- 时域特征 ----------
            eeg_mean = mean(eeg_clean);
            eeg_std  = std(eeg_clean);
            eeg_var  = var(eeg_clean);
            eeg_kurt = kurtosis(eeg_clean);
            eeg_skew = skewness(eeg_clean);
            eeg_rms  = rms(eeg_clean);
            eeg_max  = max(eeg_clean);
            eeg_min  = min(eeg_clean);
            eeg_abs_mean = mean(abs(eeg_clean));

            % 过零率：先去直流再计数，避免直流偏置把过零率压到 0
            eeg_centered = eeg_clean - mean(eeg_clean);
            eeg_zcr = sum(abs(diff(sign(eeg_centered)))) / (length(eeg_centered) - 1);

            % ---------- 频域特征 ----------
            N = length(eeg_clean);
            f = (0:N/2-1) * (fs / N);            % 只取正频率轴
            eeg_amp   = 2 * abs(fft(eeg_clean)) / N;
            eeg_amp   = eeg_amp(1:length(f));
            eeg_power = eeg_amp .^ 2;
            total_power = sum(eeg_power);

            delta_power = sum(eeg_power(f >= 0.5 & f <= 4));
            theta_power = sum(eeg_power(f >= 4   & f <= 8));
            alpha_power = sum(eeg_power(f >= 8   & f <= 13));
            beta_power  = sum(eeg_power(f >= 13  & f <= 30));
            gamma_power = sum(eeg_power(f >= 30  & f <= 40));

            delta_ratio = delta_power / total_power * 100;
            theta_ratio = theta_power / total_power * 100;
            alpha_ratio = alpha_power / total_power * 100;
            beta_ratio  = beta_power  / total_power * 100;
            gamma_ratio = gamma_power / total_power * 100;

            single_feature = [eeg_mean, eeg_std, eeg_var, eeg_kurt, eeg_skew, ...
                              eeg_rms, eeg_max, eeg_min, eeg_abs_mean, eeg_zcr, ...
                              total_power, delta_ratio, theta_ratio, alpha_ratio, ...
                              beta_ratio, gamma_ratio, ...
                              labels(folder_idx), folder_idx];

            global_feature_matrix = [global_feature_matrix; single_feature];
            global_file_info = [global_file_info; {file_name, label_names{folder_idx}}];

        catch ME
            fprintf('  处理失败 %s：%s\n', file_name, ME.message);
        end
    end
end

%% ---------- 2. 保存特征矩阵 ----------
feature_names = {'均值', '标准差', '方差', '峰度', '偏度', '均方根', '最大值', '最小值', '绝对均值', '过零率', ...
                 '总功率', 'δ功率(0.5-4Hz)占比', 'θ功率(4-8Hz)占比', 'α功率(8-13Hz)占比', ...
                 'β功率(13-30Hz)占比', 'γ功率(30-40Hz)占比', ...
                 '类别标签', '文件夹索引'};

outPath = fullfile(rootDir, 'data', 'bonn_features.mat');
save(outPath, 'global_feature_matrix', 'global_file_info', 'feature_names', ...
    'labels', 'label_names', 'fs');

fprintf('\n===== 特征提取完成 =====\n');
fprintf('成功处理文件数：%d\n', size(global_feature_matrix, 1));
fprintf('特征矩阵尺寸：%d × %d\n', size(global_feature_matrix, 1), size(global_feature_matrix, 2));
fprintf('已保存至：%s\n', outPath);

%% ---------- 3. 每类取首文件做预处理对比图 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

for folder_idx = 1:length(folders)
    folder_path = fullfile(dataRoot, folders{folder_idx});
    if ~exist(folder_path, 'dir'), continue; end

    txt_files = dir(fullfile(folder_path, '*.txt'));
    if isempty(txt_files), continue; end

    first_file = fullfile(folder_path, txt_files(1).name);
    eeg_raw = load(first_file);
    eeg_raw = eeg_raw(:);
    eeg_clean = eeg_preprocess(eeg_raw, fs, notch_freq, passband);

    fig = figure('Color', 'w', 'Position', [100 + (folder_idx - 1) * 80, 100, 1200, 600], 'Visible', 'off');
    fig.Name = sprintf('EEG 预处理对比 - %s', label_names{folder_idx});

    % 时域
    subplot(2, 1, 1);
    t = (0:length(eeg_raw) - 1) / fs;
    plot(t, eeg_raw, 'r', 'LineWidth', 0.8); hold on;
    plot(t, eeg_clean, 'b', 'LineWidth', 0.8);
    y_lim = max(abs([eeg_raw; eeg_clean])) * 1.1;
    ylim([-y_lim, y_lim]);
    title(sprintf('时域对比 — %s（%s）', folders{folder_idx}, label_names{folder_idx}));
    xlabel('时间 (s)'); ylabel('幅值 (μV)');
    legend('原始信号', '去噪信号', 'Location', 'best');
    grid on; box on;

    % 频域
    subplot(2, 1, 2);
    N = length(eeg_raw);
    f = (0:N/2-1) * (fs / N);
    raw_fft = 2 * abs(fft(eeg_raw)) / N;   raw_fft = raw_fft(1:length(f));
    cln_fft = 2 * abs(fft(eeg_clean)) / N; cln_fft = cln_fft(1:length(f));

    plot(f, raw_fft, 'r', 'LineWidth', 0.8); hold on;
    plot(f, cln_fft, 'b', 'LineWidth', 0.8);
    xlim([0, 60]);
    xline(passband(1), 'm--', 'LineWidth', 0.6);
    xline(passband(2), 'm--', 'LineWidth', 0.6);
    xline(notch_freq, 'g--', 'LineWidth', 0.8);
    title(sprintf('频域对比 — %s（%s）0-60 Hz', folders{folder_idx}, label_names{folder_idx}));
    xlabel('频率 (Hz)'); ylabel('幅度');
    legend('原始信号', '去噪信号', 'Location', 'best');
    grid on; box on;

    sgtitle(sprintf('EEG 预处理效果 — %s', label_names{folder_idx}), 'FontSize', 14);

    save_name = sprintf('preprocess_compare_%s.png', folders{folder_idx});
    print(fig, fullfile(outDir, save_name), '-dpng', '-r200');
    close(fig);
    fprintf('已生成对比图：%s\n', save_name);
end

%% ---------- 预处理函数 ----------
function eeg_clean = eeg_preprocess(eeg_raw, fs, notch_freq, passband)
    % 输入：原始 EEG、采样率、工频、带通范围
    % 输出：去噪后的 EEG
    % 步骤：线性去趋势 → 工频陷波 → 带通滤波 → 3σ 截断异常值

    % 1. 基线校正：线性去趋势，消除基线漂移
    eeg_detrend = detrend(eeg_raw);

    % 2. 工频陷波：Q = 35 的窄带 IIR，零相位滤波避免相位失真
    [b_notch, a_notch] = iirnotch(notch_freq / (fs / 2), (notch_freq / 35) / (fs / 2));
    eeg_notch = filtfilt(b_notch, a_notch, eeg_detrend);

    % 3. 带通滤波：4 阶 Butterworth，保留 0.5-40 Hz
    [b_band, a_band] = butter(4, passband / (fs / 2), 'bandpass');
    eeg_clean = filtfilt(b_band, a_band, eeg_notch);

    % 4. 异常值处理：超出 ±3σ 的样本截断到边界
    sigma = std(eeg_clean);
    mu    = mean(eeg_clean);
    upper = mu + 3 * sigma;
    lower = mu - 3 * sigma;
    eeg_clean(eeg_clean > upper) = upper;
    eeg_clean(eeg_clean < lower) = lower;
end
