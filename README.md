# EEG 片段分类（MATLAB）

本科毕业设计。用波恩大学的公开 EEG 数据集，从 500 段单通道信号里提取 16 个时频特征，训练 SVM 做状态分类。

数据分五组：A/B 来自健康志愿者，睁眼和闭眼；C/D 来自癫痫患者的发作间期，分别记录在病灶对侧和同侧；E 是发作期。我做的是片段级分类——给一段 23.6 秒的信号，判断它落在哪一组。

需要说明的是，这不是发作预测。C/D 是发作间期（interictal）而不是发作前（preictal），数据集本身也没有连续的长时间记录，所以拿它做"预测"是站不住的。另外交叉验证按片段随机划分，同一个被试的多个片段可能同时进训练集和测试集，存在信息泄漏，数字会偏高。

## 结果

二分类（健康 Z/O vs 发作间期 N/F），10 折交叉验证：准确率 98.25%，灵敏度 99.00%，特异性 97.50%，F1 98.28%。

![二分类混淆矩阵](results/svm_binary_confusion.png)

这个数字看着漂亮，但要结合前面说的两点来看。任务本身是"两类人群 + 两种记录条件"的区分，健康人和患者的脑电本来就有系统性差异；加上按片段随机划分，模型可能记住了某个被试而不是某种状态。所以这个 98% 更适合当作"特征有区分力"的证据，不太能当作"能预测发作"的证据。

另一个对照组用 70/30 划分加类别加权，准确率 97.33%，发作类召回率 100%——30 个发作样本全部检出，代价是 4 个正常样本被误报。预警场景下这个取舍是合理的。

这两个二分类用的样本量不一样：10 折那个只取 Z/O/N/F 四类共 400 段，把 E 组排除掉了；weighted 那个用全部 500 段，测试集 150 个。所以两边的混淆矩阵总数对不上是正常的。

五类多分类只有 85.33%，掉了十三个点。看混淆矩阵能看出问题在哪：

![五类混淆矩阵](results/svm_multiclass_confusion.png)

N 和 F 互相串了 14 次，占全部 22 个错误样本的六成多；Z/O/S 之间几乎不混。N 和 F 都来自患者发作间期，只是记录在病灶两侧，特征空间里本来就挨得近。剩下那 15% 的误差主要来自"同一状态的不同来源分不清"，不是模型没学会区分状态本身。

所有脚本都设了 `rng(42)`，上面的数字能复现。原始的版本没有固定种子，同一份代码两次运行会差一到两个百分点。

## 数据

波恩大学 EEG 数据库（Bonn University EEG Database），5 组各 100 段，每段 23.6 秒，单通道，采样率 173.61 Hz。

| 目录 | 组 | 内容 |
|---|---|---|
| `A_Z/` | A | 健康志愿者，睁眼 |
| `B_O/` | B | 健康志愿者，闭眼 |
| `C_N/` | C | 患者发作间期，病灶对侧海马 |
| `D_F/` | D | 患者发作间期，病灶同侧海马 |
| `E_S/` | E | 患者发作期 |

原始数据没放进仓库，一是第三方数据有使用条款，二是体积 5 MB 也不算小。仓库里的 `data/bonn_features.mat` 是提好的特征矩阵（500 × 18），跑所有模型脚本都够用。要重跑特征提取，按 `data/README.md` 把原始数据放到 `data/bonn/` 下。

## 代码

```
src/
  main_extract_features.m   遍历五组 → 预处理 → 提 16 维特征 → 存 mat
  preprocess_demo.m         拿一个片段做四联频谱对比，看每步滤波的效果
  svm_binary_10fold.m       健康 vs 发作间期，10 折交叉验证
  svm_binary_weighted.m     二分类对照，70/30 + 类别加权
  svm_multiclass.m          五类多分类
  feature_pca.m             16 维特征投到前两个主成分
  feature_boxplot.m         过零率、RMS、α 占比三个特征的分布对比
```

需要 MATLAB R2021b 或以上，用到 Statistics and Machine Learning Toolbox（`fitcsvm`、`fitcecoc`、`pca`、`boxplot`）和 Signal Processing Toolbox（`iirnotch`、`butter`、`filtfilt`）。

只跑模型的话不用原始数据：

```matlab
cd src
svm_binary_10fold
svm_multiclass
```

脚本都用 `mfilename('fullpath')` 定位仓库根目录，不依赖当前工作目录，在 MATLAB 里直接按 F5 就行。

## 特征是怎么来的

预处理四步：

| 步骤 | 做法 | 目的 |
|---|---|---|
| 基线校正 | `detrend` 线性去趋势 | 电极极化会有缓慢漂移，不去掉会污染低频功率 |
| 工频陷波 | `iirnotch`，Q = 35 | 滤 50 Hz 电网干扰 |
| 带通滤波 | 4 阶 Butterworth，0.5–40 Hz | 脑电有效频段，滤掉超低频漂移和高频肌电 |
| 异常值截断 | ±3σ | 防止单个尖峰主导 RMS、最大值这类特征 |

滤波都用 `filtfilt` 做零相位，避免波形整体平移。

16 维特征：时域 9 个（均值、标准差、方差、峰度、偏度、RMS、最大值、最小值、绝对均值）、过零率 1 个、频域 6 个（总功率加 δ/θ/α/β/γ 五个频段占比）。

过零率先减去均值再统计符号变化，不去直流的话几乎全是同一个符号，过零率会被压到接近 0。

频域用的是功率占比而不是绝对功率，因为不同被试的绝对幅值可能差几倍，但各节律的相对强弱可比。

## 做得不够的地方

除了开头说的被试级泄漏，还有三处：

特征没有筛选，16 维全用上了。加一步 mRMR 或者递归特征消除，可能用一半的特征拿到相近的效果，也更好解释。

手工特征的表达力有上限。16 个统计量能撑到 98% 的二分类，多分类就只有 85% 了。换成 EEGNet 这类模型通常能明显提升，但需要更多数据和调参。

"预测"这件事本身没做。真要做预测，得用 CHB-MIT 那种连续记录的数据集，自己切出 preictal 时间窗，这套代码的预处理和特征部分可以复用，但实验设计得重来。

## 参考

- R. G. Andrzejak, et al. *Indications of nonlinear deterministic and finite-dimensional structures in time series of brain electrical activity: Dependence on recording region and brain state.* Physical Review E, 64(6): 061907, 2001.
- 数据集主页：<https://www.ukbonn.de/epileptologie/arbeitsgruppen/ag-lehnertz-neurophysik/downloads/>

MIT License
