# 基于 FFT 时频特征与 SVM 的 EEG 片段分类

用波恩大学脑电数据集，从 400 个单通道片段中提取 16 维时频特征，训练 SVM 区分不同的脑电状态。本科毕业设计，MATLAB 实现。

## 先说清楚这个项目是什么、不是什么

**是**：片段级的状态分类。给一段 23.6 秒的 EEG，判断它属于「健康睁眼 / 健康闭眼 / 发作间期 / 发作期」中的哪一类。

**不是**：癫痫发作预测。波恩数据集的 C、D 组是**发作间期（interictal）**，不是发作前（preictal）。数据集里没有连续的长时间记录，也就没有「发作前窗口」这种东西，任何基于它的「预测」结论都不成立。

**另一个限制**：交叉验证按片段随机划分，同一被试的多个片段可能同时落进训练集和测试集，存在信息泄漏，准确率会偏高。要做严格的泛化评估，得按被试划分（leave-one-subject-out）。

这两点写在前面，是因为它们决定了这些数字该怎么读。

## 结果

| 任务 | 划分方式 | 结果 |
|---|---|---|
| 健康(Z/O) vs 发作间期(N/F) | 10 折交叉验证 | 准确率 **98.25%**，灵敏度 99.00%，特异性 97.50%，F1 98.28% |
| 二分类（对照，含类别加权） | 70/30 + 分层 | 准确率 **97.33%**，发作类召回率 100% |
| 五类状态多分类 | 70/30 分层划分 | 准确率 **85.33%** |

> 所有脚本都用 `rng(42)` 固定了随机种子，上面的数字可复现。原始设计没有固定种子，同一份代码两次运行的准确率会有 1–2 个百分点的浮动。

![二分类混淆矩阵](results/svm_binary_confusion.png)

多分类里最值得注意的一点：**N 和 F 互相混淆最严重**（N→F 9 例，F→N 5 例），共占全部 22 个错误样本的 64%；而 Z/O/S 三类之间几乎不串。

这两组都属于癫痫患者的发作间期，区别只在记录脑区不同，在特征空间里本来就挨得很近。也就是说，剩下那 15% 的误差主要来自「同一状态的不同来源难以区分」，而不是模型没学会区分状态本身。

![五类混淆矩阵](results/svm_multiclass_confusion.png)

## 数据集

用的是 **波恩大学 EEG 数据库（Bonn University EEG Database）**，也叫 Andrzejak 数据集：

- 5 组，每组 100 个单通道片段，共 500 段
- 每段 23.6 秒，采样率 173.61 Hz，12 位量化
- 分组含义：

| 组 | 简称 | 内容 |
|---|---|---|
| A | Z | 健康志愿者，睁眼 |
| B | O | 健康志愿者，闭眼 |
| C | N | 癫痫患者发作间期，病灶对侧海马 |
| D | F | 癫痫患者发作间期，病灶同侧海马 |
| E | S | 癫痫患者发作期 |

原始数据下载地址见 [`data/README.md`](data/README.md)。**仓库里不放原始数据**，只放提取好的特征文件 `data/bonn_features.mat`（约 1 MB），因为特征文件足够跑通所有模型脚本。

## 目录结构

```
.
├── src/
│   ├── main_extract_features.m   主流程：读数据→预处理→提特征→存 mat
│   ├── preprocess_demo.m         单文件预处理演示（四联频谱对比图）
│   ├── svm_binary_10fold.m       健康 vs 发作间期，10 折交叉验证
│   ├── svm_binary_weighted.m     二分类对照，70/30 + 类别加权
│   ├── svm_multiclass.m          五类状态多分类
│   ├── feature_pca.m             PCA 特征有效性验证
│   └── feature_boxplot.m         三个核心特征的箱线图
├── data/
│   ├── README.md                 数据集来源与放置说明
│   └── bonn_features.mat         16 维特征矩阵（400×18）
└── results/                      运行产出的图和结果
```

## 怎么跑

需要 **MATLAB R2021b 或以上**，以及两个工具箱：

- Statistics and Machine Learning Toolbox（`fitcsvm`、`fitcecoc`、`pca`、`boxplot`）
- Signal Processing Toolbox（`iirnotch`、`butter`、`filtfilt`）

**只跑模型**（不重新提特征）：

```matlab
cd src
svm_binary_10fold      % → 98.25% 那组指标 + 混淆矩阵
svm_multiclass         % → 83.33% 多分类
feature_pca            % → 主成分散点
feature_boxplot        % → 三个特征的分布对比
```

**从原始数据重跑**：

1. 按 `data/README.md` 把五个子目录放到 `data/bonn/` 下
2. 运行 `main_extract_features.m`，会重新生成 `data/bonn_features.mat`
3. 再跑上面的模型脚本

所有脚本都用 `mfilename('fullpath')` 定位仓库根目录，**不依赖当前工作目录**，在 MATLAB 里直接按 F5 就能跑。

## 特征怎么来的

预处理四步，每一步都有明确目的：

| 步骤 | 做法 | 为什么 |
|---|---|---|
| 基线校正 | `detrend` 线性去趋势 | 电极极化会产生缓慢的基线漂移，不去掉会污染低频功率 |
| 工频陷波 | `iirnotch`，Q = 35 | 50 Hz 电网干扰，国内必须处理 |
| 带通滤波 | 4 阶 Butterworth，0.5–40 Hz | 脑电有效频段，滤掉超低频漂移和高频肌电 |
| 异常值截断 | ±3σ 截断 | 防止单个尖峰主导 RMS、最大值这类特征 |

滤波全部用 `filtfilt` 做零相位滤波，避免波形在时间上整体平移。

16 维特征：

- **时域 9 个**：均值、标准差、方差、峰度、偏度、均方根、最大值、最小值、绝对均值
- **过零率 1 个**：先减去均值再统计符号变化，避免直流偏置把它压到 0
- **频域 6 个**：总功率 + δ(0.5–4) / θ(4–8) / α(8–13) / β(13–30) / γ(30–40) 五个频段的功率占比

用功率占比而不是绝对功率，是为了消除个体间幅值差异——不同被试的绝对电压可能差几倍，但节律的相对强弱可比。

## 已知问题与可以改进的方向

1. **被试级泄漏**：当前按片段随机划分。正确做法是 leave-one-subject-out，但波恩数据集没有给被试 ID，得自己去核对片段来源。
2. **「预测」这个说法不成立**：要真正做发作预测，得用 CHB-MIT 这类连续记录数据集，自己切出 preictal 时间窗。
3. **手工特征的表达力有限**：16 维统计量能到 98% 的二分类水平，但多分类只有 83%。换成深度模型（EEGNet、CNN-LSTM）通常能明显提升，代价是需要更大数据量和更多调参。
4. **没有做特征筛选**：16 维全用上了。加一步 mRMR 或递归特征消除，可能用更少特征拿到相近效果，也更利于解释。

## 环境

- MATLAB R2021b（代码里用到的 `sgtitle`、`xtickangle`、十六进制颜色都需要 R2018a 以上）
- 无第三方依赖，不需要额外安装工具箱之外的包

## 参考

- R. G. Andrzejak, et al. *Indications of nonlinear deterministic and finite-dimensional structures in time series of brain electrical activity: Dependence on recording region and brain state.* Physical Review E, 64(6): 061907, 2001.
- 波恩大学 EEG 数据库主页：https://www.ukbonn.de/epileptologie/arbeitsgruppen/ag-lehnertz-neurophysik/downloads/

## License

MIT
