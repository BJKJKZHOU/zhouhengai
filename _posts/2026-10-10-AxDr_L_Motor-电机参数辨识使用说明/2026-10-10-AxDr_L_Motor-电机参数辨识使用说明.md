---
title: "电机参数辨识功能"
date: 2026-10-10 15:00:00 +0800
author: zhou_heng
categories: [AxDr_L_Motor]
tags: [PMSM, 电机参数辨识, Rs, Flux]
---

&emsp;&emsp;[AxDr_L_Motor](https://github.com/BJKJKZHOU/AxDr_L_Motor) 提供了电机参数辨识功能，可以在接入一台电机后，测量电阻、电感、磁链和惯量等参数，再把结果应用到控制器中。

&emsp;&emsp;目前可以单独使用三种辨识：

| 辨识项目 | 得到什么 | 电机的动作 |
|---|---|---|
| **Rs/Ls** | 定子电阻 Rs、等效电感 Ls | 施加直流偏置和正弦电压，期间有转子定位过程 |
| **Flux** | 永磁磁链 Flux | 电机会自动启动、旋转 |
| **J/B** | 转动惯量 J、粘性阻尼 B | 电机会旋转并改变转速 |

&emsp;&emsp;具体过程如下：

&emsp;&emsp;**Rs/Ls：** 先通过初步测试选择合适的激励频率，再施加直流偏置与正弦电压，根据实际电流响应调整测试幅值。固件对电压和电流进行正余弦同步检波，提取同一频率的分量，计算电阻 Rs 和电感 Ls，最后检查多组结果是否一致。

&emsp;&emsp;**Flux：** 先对齐转子，再通过 I/F 开环启动电机。磁链拟合器利用测得的电压、电流及转速拟合出粗略磁链，并用它初始化磁链观测器；观测器结合 PLL 估计转子角度和速度。待观测器输出稳定后，控制从 I/F 逐步切换到观测器，再在稳定转速下进行磁链精细拟合，得到最终 Flux。

&emsp;&emsp;**J/B：** 同样先经过对齐和 I/F 启动，再切换到磁链观测器控制。固件自动选择一个工作转速，在其附近加入小幅正弦速度激励，记录 q 轴电流与实际转速。通过离散傅里叶变换（DFT）提取两者在激励频率上的分量，再根据转矩与转速响应计算转动惯量 J 和粘性阻尼 B。

&emsp;&emsp;通常先做 **Rs/Ls → Flux → J/B**。只需要电阻、电感时，可以做完 Rs/Ls 就结束。Flux 需要前面已确认的电气参数，J/B 还需要已经确认的 Flux。

## 辨识前准备

&emsp;&emsp;连接电机和电源，确认三相接线、母线电压、电流保护正常。**Flux 和 J/B 会让电机转动**，应将电机可靠固定，保持转轴周围没有障碍物，并避免连接不适合自由旋转的负载。

&emsp;&emsp;开始前需要确认这些设置：

| 参数 | 用途 |
|---|---|
| **Pole Pairs** | 电机的实际极对数，不能把磁极数直接当成极对数 |
| **Imax** | 用户设置的相电流上限，不会超过固件的硬件限制 |
| **RL Injection Peak** | Rs/Ls 测试电流的目标峰值，必须低于实际允许的电流上限 |
| **Align Current、I/F Current** | Flux 和 J/B 启动旋转时使用的电流 |
| **Speed Limit** | Flux/J/B 旋转时允许的速度范围 |

&emsp;&emsp;极对数需要事先知道；当前这三种辨识不会自动识别极对数。以上参数可以通过 USB 写入，方法参见 [如何通过 USB 与固件通信](https://github.com/BJKJKZHOU/zhouhengai/blob/main/_posts/2026-10-09-AxDr_L_Motor-通信与实时数据采集/2026-10-09-AxDr_L_Motor-通信与实时数据采集.md)。

## 方法一：使用 Python 脚本

&emsp;&emsp;固件仓库里的 [`tools/identification_test.py`](https://github.com/BJKJKZHOU/AxDr_L_Motor/blob/204215f891810296f5a549909a76d97da9c9c2a4/tools/identification_test.py) 可以自动完成多次测试、检查结果，并输出 JSON 测试记录。建议第一次接触辨识时先使用这个脚本，不用逐条发送命令。

&emsp;&emsp;先安装串口依赖。Linux 下的串口通常是 `/dev/ttyACM0` 一类路径，Windows 下则使用 `COM` 端口，命令中的 `--port` 按实际设备修改：

```bash
python3 -m pip install pyserial
```

&emsp;&emsp;下面的 **7 极对、2 A 电流限制只是命令示例**，实际使用时改成自己的电机参数和允许电流。

### 只测 Rs/Ls

&emsp;&emsp;在固件仓库根目录运行：

```bash
python3 tools/identification_test.py \
  --port /dev/ttyACM0 \
  --pole-pairs 7 \
  --current-limit 2.0 \
  --rs-ls-count 5 \
  --ident-timeout 25 \
  --run
```

&emsp;&emsp;脚本会执行 5 次 Rs/Ls 辨识，报告每次结果、成功次数和重复性。没有 `--apply-rl` 时，只读取和记录结果，**不把新 Rs/Ls 应用到电机参数**。

&emsp;&emsp;如果确认需要应用这组结果，可以在命令中加上 `--apply-rl --skip-flux` 再运行；这样完成 Rs/Ls 后就结束，不进入 Flux。

### 连续辨识 Rs/Ls 和 Flux

```bash
python3 tools/identification_test.py \
  --port /dev/ttyACM0 \
  --pole-pairs 7 \
  --current-limit 2.0 \
  --if-current 0.5 \
  --rs-ls-count 5 --apply-rl \
  --flux-forward-count 2 --flux-reverse-count 2 --apply-flux \
  --ident-timeout 25 \
  --run
```

&emsp;&emsp;这个例子先完成并应用 Rs/Ls，再进行正向 2 次、反向 2 次 Flux 测量。脚本检查测量是否有效及重复性，只有通过检查才会执行对应的 Apply。

&emsp;&emsp;`--if-current` 是 Flux 启动旋转所用的电流，需要结合电机和保护限值设置。

&emsp;&emsp;还想测 J/B，可以在上述命令中增加：

```text
--jb-count 2 --apply-jb
```

&emsp;&emsp;J/B 会在 Rs/Ls、Flux 都已应用后运行。

&emsp;&emsp;脚本默认要求母线电压处于 **10～20 V**，如果实际供电不同，应通过 `--vbus-min` 和 `--vbus-max` 设置符合测试电源的范围。`--run` 是明确允许脚本给电机通电的参数。脚本结束时会 Disable，并将结果及测试情况写入 `build/Release/` 下的 JSON 文件。

&emsp;&emsp;脚本的测试配置和采集方法可能随开发调整，运行前应以当前脚本的 `--help` 和源码为准。

## 方法二：使用 VOFA+ 手动辨识

&emsp;&emsp;不使用脚本时，也可以通过 [VOFA+](https://www.vofa.plus/) 发送完整的十六进制数据。以下命令以 **Node ID=1** 为例，每行单独按 Hex 原始字节发送，不需要换行符。

### 先切换到辨识模式

&emsp;&emsp;先让电机处于 Disable 状态，再将控制模式设为 **IDENT（4）**，然后 Enable。

**Disable：**

```text
41 58 44 52 C1 01 05 01 02 04 10 06
```

**切换为 IDENT 模式：**

```text
41 58 44 52 C1 01 06 01 02 01 07 00 04
```

**Enable：**

```text
41 58 44 52 C1 01 05 01 02 01 10 06
```

&emsp;&emsp;辨识通过自己的启动命令进入运行过程，**不需要另外发送普通 Run**。启动前应已设置好对应的极对数、电流限值和测试电流。

### 启动 Rs/Ls

```text
41 58 44 52 C1 01 05 01 02 01 11 06
```

&emsp;&emsp;等待测试结束，再读取结果。成功时 `Rs/Ls Valid` 为 `1`，随后分别读取 Rs 和 Ls。读出的 Rs 单位为 Ω，Ls 单位为 H。

### 启动 Flux 或 J/B

&emsp;&emsp;Rs/Ls 结果确认并 Apply 后，可以继续 Flux。开始 Flux 前，确保电机的 Rs、Ld/Lq、极对数、Align Current、I/F Current 与速度限值设置正确。

**Flux：**

```text
41 58 44 52 C1 01 05 01 02 02 11 06
```

&emsp;&emsp;Flux 会自动选择实际辨识工作速度。其转向由 `Speed Target` 的正负号确定：零或正数表示正向，负数表示反向。需要比较正反向结果时，可分别设置方向并重新启动。

&emsp;&emsp;确认 Flux 结果并 Apply 后，可以进行 **J/B：**

```text
41 58 44 52 C1 01 05 01 02 05 11 06
```

&emsp;&emsp;J/B 自动选择工作转速，默认使用 20% 的速度激励幅值和 3 Hz 激励频率；对应设置可通过参数 ID `0x0923`、`0x0924` 修改。

### 怎样读取辨识结果

&emsp;&emsp;以下是常用的读取命令，右侧的 Valid 用来判断对应结果是否有效。

| 要读取的内容 | 发送的十六进制命令 |
|---|---|
| Rs/Ls 是否有效 | `41 58 44 52 C1 01 04 01 01 01 09` |
| Rs 结果（Ω） | `41 58 44 52 C1 01 04 01 01 02 09` |
| Ls 结果（H） | `41 58 44 52 C1 01 04 01 01 03 09` |
| Flux 是否有效 | `41 58 44 52 C1 01 04 01 01 10 09` |
| Flux 结果（Wb） | `41 58 44 52 C1 01 04 01 01 11 09` |
| J/B 是否有效 | `41 58 44 52 C1 01 04 01 01 20 09` |
| J 结果（kg·m²） | `41 58 44 52 C1 01 04 01 01 21 09` |
| B 结果（N·m·s/rad） | `41 58 44 52 C1 01 04 01 01 22 09` |
| 最近失败原因 | `41 58 44 52 C1 01 04 01 01 12 09` |

&emsp;&emsp;Valid 返回 `1` 才表示这次结果有效，结果数值通常是 4 字节 float32。原始响应的读取和解码格式与[上一篇通信文章](https://github.com/BJKJKZHOU/zhouhengai/blob/main/_posts/2026-10-09-AxDr_L_Motor-通信与实时数据采集/2026-10-09-AxDr_L_Motor-通信与实时数据采集.md)相同。

&emsp;&emsp;第一次启动辨识会收到启动请求的响应；测试结束后还会有一次辨识完成事件。**应等辨识结束、Valid 确认为 1 后，再考虑 Apply。**

## 确认结果后 Apply 和 Save

&emsp;&emsp;辨识得到的数值不会自动替换电机模型。检查结果之后，发送 **Apply**：

```text
41 58 44 52 C1 01 05 01 02 04 11 06
```

&emsp;&emsp;Apply 对最近一次成功的辨识结果生效，按类型更新 RAM 中的电机参数：

| 已完成的辨识 | Apply 后更新 |
|---|---|
| Rs/Ls | `Rs`、`Ld`、`Lq`（其中 Ld=Lq=测得的 Ls） |
| Flux | `Flux` |
| J/B | `J`、`B` |

&emsp;&emsp;完成一次辨识可以先多测几轮，检查结果是否接近，再决定是否 Apply。**Apply 不等于写入 Flash**，重新上电后是否保留取决于保存过的参数。

&emsp;&emsp;最终确认参数后，先 Disable：

```text
41 58 44 52 C1 01 05 01 02 04 10 06
```

&emsp;&emsp;再执行 Save（仅 DISABLED 状态允许）：

```text
41 58 44 52 C1 01 05 01 02 02 12 06
```

&emsp;&emsp;这样会将当前允许持久化的电机参数保存到 Flash。使用 Python 脚本进行 Apply 后，仍然需要单独保存，脚本本身不会自动 Save。

## 中断或失败怎么办

&emsp;&emsp;需要中止正在进行的辨识，可以发送 **Abort**：

```text
41 58 44 52 C1 01 05 01 02 03 11 06
```

&emsp;&emsp;若测试失败，先查看 Valid 和失败原因，再检查供电、电流限制、极对数和启动电流。Flux/J/B 还需要确认电机能够按预期旋转，以及前面的电气参数已应用。失败原因 `0x0912` 的数值 `3` 表示启动配置不满足要求；数值 `0` 不能代替 Valid 判断成功。

&emsp;&emsp;有多次测试结果时，优先比较重复性，不建议仅凭一次 Valid=1 就保存参数。若硬件保护已经触发，应先解决保护原因，再继续测试。

&emsp;&emsp;本文使用的 [辨识参数定义](https://github.com/BJKJKZHOU/AxDr_L_Motor/blob/204215f891810296f5a549909a76d97da9c9c2a4/Parameter/parameter.yaml) 和 [辨识调用入口](https://github.com/BJKJKZHOU/AxDr_L_Motor/blob/204215f891810296f5a549909a76d97da9c9c2a4/AZURE_RTOS/App/motor_thread.c) 均对应固件 `main @ 204215f`。
