%% ===================== 预处理流程演示（单文件，逐步频谱对比） =====================
% 用途：取一个原始片段，展示「基线校正 → 50 Hz 陷波 → 0.5-40 Hz 带通」
%       三步预处理各自的频谱效果，用于论文插图和结果说明
% 输入：data/bonn/E_S/ 下的任一 txt 文件（波恩数据集 E 组，采样率 173.61 Hz）
% 输出：results/preprocess_spectrum.png
% 依赖：MATLAB R2021b 及以上，Signal Processing Toolbox（iirnotch / butter / filtfilt）
%
% 目录要求：
%   data/bonn/
%   ├── A_Z/  B_O/  C_N/  D_F/  E_S/     ← 五个子目录，各放 100 个 .txt
%   波恩数据集下载见 data/README.md
% =====================================================================================

clear; clc; close all;

rootDir = fileparts(fileparts(mfilename('fullpath')));
dataRoot = fullfile(rootDir, 'data', 'bonn');

target_folder = 'E_S';        % 演示用发作期数据，也可改成 A_Z 等
fs = 173.61;                  % 波恩数据集采样率
notch_freq = 50;              % 工频干扰（国内 50 Hz）
passband = [0.5, 40];         % 脑电有效频段

%% ---------- 1. 读一个文件 ----------
current_folder = fullfile(dataRoot, target_folder);
file_list = dir(fullfile(current_folder, '*.txt'));
if isempty(file_list)
    error('未找到数据：%s\n请先按 data/README.md 下载波恩数据集并放到 data/bonn/ 下。', current_folder);
end

file_path = fullfile(current_folder, file_list(1).name);
eeg_raw = load(file_path);
eeg_raw = eeg_raw(:);

fprintf('处理文件：%s\n', file_list(1).name);

%% ---------- 2. 分步预处理 ----------
% 步骤 1：基线校正（去趋势，消除直流偏移与基线漂移）
eeg_step1 = detrend(eeg_raw);

% 步骤 2：工频陷波（窄带滤除 50 Hz）
wo = notch_freq / (fs / 2);
bw = 2 / (fs / 2);
[b_notch, a_notch] = iirnotch(wo, bw);
eeg_step2 = filtfilt(b_notch, a_notch, eeg_step1);

% 步骤 3：带通滤波（保留 0.5-40 Hz）
[b_band, a_band] = butter(4, passband / (fs / 2), 'bandpass');
eeg_step3 = filtfilt(b_band, a_band, eeg_step2);

eeg_clean = eeg_step3;

%% ---------- 3. 逐级频谱 ----------
[f, amp_raw] = local_spectrum(eeg_raw, fs);
[~, amp1]    = local_spectrum(eeg_step1, fs);
[~, amp2]    = local_spectrum(eeg_step2, fs);
[~, amp3]    = local_spectrum(eeg_clean, fs);

%% ---------- 4. 四联图 ----------
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end

figure('Color', 'w', 'Position', [100, 100, 1400, 700]);

subplot(4, 1, 1);
plot(f, amp_raw, 'k', 'LineWidth', 1);
xlim([0 60]);
title('1. 原始信号频谱', 'FontSize', 12);
grid on;
xline(0.5, 'm--', 'LineWidth', 1.2);
xline(40, 'm--', 'LineWidth', 1.2);
xline(50, 'g--', 'LineWidth', 1.2);
legend('原始信号', '0.5 Hz', '40 Hz', '50 Hz', 'Location', 'best');

subplot(4, 1, 2);
plot(f, amp1, 'b', 'LineWidth', 1);
xlim([0 60]);
title('2. 基线校正后频谱', 'FontSize', 12);
grid on;
xline(0.5, 'm--'); xline(40, 'm--'); xline(50, 'g--');

subplot(4, 1, 3);
plot(f, amp2, 'm', 'LineWidth', 1);
xlim([0 60]);
title('3. 50 Hz 工频陷波后频谱', 'FontSize', 12);
grid on;
xline(0.5, 'm--'); xline(40, 'm--'); xline(50, 'g--');

subplot(4, 1, 4);
plot(f, amp3, 'r', 'LineWidth', 1.2);
xlim([0 60]);
title('4. 0.5–40 Hz 带通滤波（最终干净信号）', 'FontSize', 12);
grid on;
xline(0.5, 'm--'); xline(40, 'm--'); xline(50, 'g--');

sgtitle('E 组（癫痫发作）预处理全过程频域对比', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('幅度', 'FontSize', 12);

print(gcf, fullfile(outDir, 'preprocess_spectrum.png'), '-dpng', '-r300');
fprintf('对比图已保存至 results/preprocess_spectrum.png\n');

%% ---------- 局部函数 ----------
function [f, amp] = local_spectrum(x, fs)
    % 单边幅度谱：只取 0~fs/2，幅度乘 2 补偿负频率能量
    N   = length(x);
    f   = (0:N/2-1) * fs / N;
    amp = 2 * abs(fft(x)) / N;
    amp = amp(1:length(f));
end
