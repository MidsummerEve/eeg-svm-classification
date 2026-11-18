# 数据集说明

## 来源

波恩大学 EEG 数据库（Bonn University EEG Database），也称 Andrzejak 数据集：

- 论文：R. G. Andrzejak, et al. *Indications of nonlinear deterministic and finite-dimensional structures in time series of brain electrical activity: Dependence on recording region and brain state.* Phys. Rev. E, 64(6): 061907, 2001.
- 官方下载：<https://www.ukbonn.de/epileptologie/arbeitsgruppen/ag-lehnertz-neurophysik/downloads/>

## 规格

- 5 组（A/B/C/D/E），每组 100 个片段
- 每段 23.6 秒，单通道，采样率 173.61 Hz
- 每个片段是一个纯文本文件，内含 4097 个整数（12 位 ADC 原始值）

## 各组含义

| 目录 | 组 | 内容 |
|---|---|---|
| `A_Z/` | A | 健康志愿者，睁眼 |
| `B_O/` | B | 健康志愿者，闭眼 |
| `C_N/` | C | 癫痫患者发作间期，病灶对侧海马 |
| `D_F/` | D | 癫痫患者发作间期，病灶同侧海马 |
| `E_S/` | E | 癫痫患者发作期 |

## 放置方式

下载后解压，按下面的结构放到 `data/bonn/`：

```
data/
├── README.md
├── bonn_features.mat
└── bonn/
    ├── A_Z/
    │   ├── Z001.txt
    │   └── ...
    ├── B_O/
    ├── C_N/
    ├── D_F/
    └── E_S/
```

目录名必须保持 `A_Z`、`B_O`、`C_N`、`D_F`、`E_S`，`src/main_extract_features.m` 里是按这五个名字遍历的。

如果原始文件名不是这个格式也没关系，脚本只按 `*.txt` 通配，不依赖具体文件名。

## 为什么仓库里不放原始数据

原始数据约 5 MB（500 个 txt），体积不算大，但它是第三方数据，有独立的使用条款，不适合直接再分发。

仓库里的 `bonn_features.mat` 是提取好的 16 维特征矩阵（400 × 18），**跑所有模型脚本够用**，不需要重新下载原始数据。只有想从零重跑特征提取时，才需要准备 `data/bonn/`。
