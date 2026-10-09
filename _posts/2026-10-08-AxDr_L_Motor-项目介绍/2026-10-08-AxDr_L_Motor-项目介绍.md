---
title: "AxDr_L_Motor 项目介绍"
date: 2026-10-08 15:00:00 +0800
author: zhou_heng
categories: [AxDr_L_Motor]
tags: [PMSM, FOC, STM32G474, 电机控制]
---

## 简介

[AxDr_L_Motor](https://github.com/BJKJKZHOU/AxDr_L_Motor) 是我个人开发的永磁同步电机（PMSM）控制固件工程，主要用于学习、实现和验证电机控制算法。

最开始只是想把 FOC 的基本控制流程跑起来，后来随着开发和测试，逐渐加入了速度环、位置环、无感观测器、电机参数辨识、运动轨迹规划以及数据采集等功能。

这个项目没有预定的最终形态，主要根据实际需要增加功能、测试算法、修改存在的问题。有些算法已经经过实机验证，有些仍然处于实验阶段。源码已经公开，相关测试记录和使用工具也保存在仓库中。

## 硬件

当前使用的是基于 **STM32G474RET6** 的 AxDrive-L V1.3 电机驱动板。

- MCU：STM32G474RET6
- 电机类型：永磁同步电机（PMSM）
- 控制方式：三相逆变器 + FOC
- 电流反馈：ADC 同步采样
- 编码器：SPI 编码器 MT6816、MT6835
- 通信：USB CDC

AxDrive-L 是已有的开源硬件，相关项目地址：

- [AxDrive-L 硬件工程](https://oshwhub.com/lylssy/foc_driver)
- [AxDrive-L 原软件参考工程](https://github.com/disnox/AxDr_L)

我的固件是在这块硬件上开发和测试的，并不是 AxDrive-L 原项目的官方固件。目前只针对自己实际使用的开发板进行维护，不主动规划其他开发板或平台的适配；以后如果使用新的硬件，再根据实际情况调整。

## 固件功能架构

固件围绕 FOC 底层控制实现有感闭环控制、无感控制、电机参数辨识和状态估计等功能，并通过通信与参数接口进行配置和测试。

![AxDr_L_Motor 固件功能架构（浅色）](/assets/img/2026-10-08-AxDr_L_Motor-项目介绍/axdr-motor-architecture_light.svg){: .light }
![AxDr_L_Motor 固件功能架构（深色）](/assets/img/2026-10-08-AxDr_L_Motor-项目介绍/axdr-motor-architecture_dark.svg){: .dark }

图中展示固件的主要功能模块及其关系，具体控制流程与实现可查看对应源码。

## 已实现的主要功能

### FOC 与有感闭环控制

FOC 底层控制主要位于 `Motor/`，以 **20 kHz** 的频率运行。电流反馈采用两相 ADC 同步采样，测量 A、B 两相电流，并根据三相电流之和为零的关系重构 C 相电流。

采样电流经过 Clarke/Park 变换后，得到旋转坐标系下的 d、q 轴电流。电流环使用 PI 控制器，默认采用 Id=0 控制策略。PI 输出可叠加 dq 轴交叉耦合补偿及反电动势前馈，最后经过二维电压矢量限幅、反 Park 变换和 SVPWM，生成三相 PWM 指令。

工程在此基础上实现了三种基于编码器反馈的闭环控制方式：

- **Torque**：将目标转矩通过转矩常数换算为 q 轴电流参考，支持可配置的转矩变化率限制。
- **Speed**：速度闭环通过 PI 控制器生成 q 轴电流参考，支持线性速度斜坡和两种五次速度 S 曲线。
- **Position**：位置控制采用轨迹规划速度前馈与位置反馈修正相结合的结构，支持梯形位置轨迹和两种 S 曲线。

三种模式共用底层 FOC，主要控制环路运行频率如下：

| 控制环路 | 运行频率 | 主要作用 |
|---|---:|---|
| 电流环 | 20 kHz | dq 电流调节与电压指令生成 |
| 速度环 | 2 kHz | 根据速度误差生成转矩电流参考 |
| 位置环 | 1 kHz | 计算位置反馈修正速度 |

`Observer/` 中的机械扩张状态观测器（ESO）根据编码器位置等信号估计机械转速和扰动转矩。当前有感速度环使用机械 ESO 的速度估计作为反馈。

电流环和速度环支持两种参数配置方式：根据电机参数与目标带宽计算 PI 增益，或者直接设置 PI 增益。电流环还提供可选的 dq 解耦与反电动势前馈开关，便于对照不同控制方法的实际表现。

运动规划位于 `Motion/`。其中 S 曲线提供保持原梯形加减速时间、保持设定峰值加速度两种模式。前者在标准过渡段的峰值加速度达到设定值的 1.875 倍；后者通过延长过渡时间控制峰值加速度。

上述转矩斜坡、S 曲线、解耦前馈和相关调参功能参考固件的 [`feat/current-frf-injection`](https://github.com/BJKJKZHOU/AxDr_L_Motor/tree/feat/current-frf-injection) 开发分支，尚未全部合入 `main`。

### 电机参数辨识

电机参数辨识主要位于 `Identification/`，用于获取控制和电机模型所需的参数。目前包含：

- **Rs/Ls 辨识**：定子电阻和等效电感。
- **Flux 辨识**：永磁体磁链。
- **J/B 辨识**：转动惯量和粘性阻尼。

辨识功能通过控制动作启动。完成后，可以读取结果有效性状态及相应参数，再决定是否将辨识结果应用到当前电机模型。

不同辨识功能相互独立，辨识结果不会仅因为测量成功就自动保存到 Flash。这样可以先检查测量结果，再决定是否更新当前配置。

辨识算法已完成部分实机及重复性测试，但结果会受到电机、测试工况和激励条件等因素影响，需要结合具体实验数据判断其有效性。

### 无感控制与观测器

无感启动与控制逻辑主要位于 `Sensorless/`，相关磁链观测器与 PLL 位于 `Observer/`。目前包括：

- 电机转子初始对齐
- I/F 开环启动
- 非线性磁链观测器
- PLL 电角度、电角速度估计
- I/F 与 Observer 之间的控制接管

目前已实现无感启动、闭环运行及加减速测试，低速运行、观测器角度纹波等问题仍在分析中。

### 其他功能

- 编码器相位标定
- 电流、电压等保护机制
- 通过 `Parameter/` 统一读写参数，并由 `Storage/` 负责 Flash 非易失性存储
- USB 通信与实时波形采集
- Python 自动化测试与数据记录

这些功能主要用于电机调试和算法验证，不代表所有功能都已在各种工况下验证完成。

## 实测与验证

项目中的部分控制算法已经通过实机测试、参数采集与数据分析进行验证。下面选取两项实验作简要说明；完整测试条件和结果保存在固件仓库的 `docs/` 目录中。

### S 曲线运动规划

在梯形轨迹基础上，工程实现了两种五次速度 S 曲线，并分别对速度模式和位置模式进行了实机测试。

测试内容包括短行程、正反转、运动过程中修改目标、调整速度上限、Stop/Run，以及较高速的位置运动。

2026 年 10 月 7 日的五圈位置测试中，母线电压约 24.4～25.0 V，电机空载，目标速度为 1000 RPM，加减速度设置为 500 rad/s²。两种 S 曲线的规划结果如下：

| 指标 | 保持时间 | 保持峰值加速度 |
|---|---:|---:|
| 规划峰值速度 | 1000 RPM | 874 RPM |
| 规划运动时间 | 约 0.510 s | 约 0.686 s |
| 规划加速度峰值 | 937.49 rad/s² | 500.00 rad/s² |
| 位置环动态误差峰值 | 3.046° | 1.644° |

保持峰值加速度的 S 曲线由于过渡时间更长，在本次五圈行程中未能达到设定的 1000 RPM。

这两种模式的主要区别并不是简单的平滑程度，而是时间和加速度约束的不同。S 曲线也不一定在所有工况下都比梯形轨迹具有更小的跟踪误差。以上高速结果每种曲线只测试了一次，不能据此推断重复定位精度。

详细测试过程见：[轨迹规划测试记录](https://github.com/BJKJKZHOU/AxDr_L_Motor/blob/feat/current-frf-injection/docs/轨迹规划测试记录.md#scurve-20261007)。

### 电流环频率响应

为了检查电流环实际频率响应与控制器设计参数之间的关系，工程增加了 d 轴正弦信号注入功能。

固件以 20 kHz 频率生成激励并采集实际电流，PC 端完成数据拟合和 Bode 幅频、相频曲线分析。

2026 年 10 月 8 日的实验在静止、零转矩目标条件下，分别测试了 500 Hz、1000 Hz、2000 Hz 三组电流环设计带宽设置，扫频范围为 20～5000 Hz。

| PI 带宽设置 | 实测闭环 −3 dB 频率 |
|---|---|
| 500 Hz | 约 485 Hz |
| 1000 Hz | 约 3519 Hz |
| 2000 Hz | 测试频率范围内未找到 |

其中，2000 Hz 设置在约 4～4.5 kHz 出现约 +2.4 dB 的闭环幅值隆起。

这说明控制器设置的设计带宽不能直接视为实际闭环带宽。除了 −3 dB 截止点，还需要结合完整的幅频、相频响应和电流噪声判断控制器的实际表现。

本次结果对应特定电机、控制参数和静止工作点，不代表其他电机或运行工况下能够获得相同结果。

详细测试数据见：[电流环频响测试](https://github.com/BJKJKZHOU/AxDr_L_Motor/blob/feat/current-frf-injection/docs/电流环频响测试.md#frf-hw-20261008)。

## 如何使用

固件代码和编译说明位于 [AxDr_L_Motor GitHub 仓库](https://github.com/BJKJKZHOU/AxDr_L_Motor)。

工程使用 STM32CubeMX 管理部分底层配置，基于 CMake 构建，使用 ThreadX、USBX 等组件；相关第三方依赖位于 `ThirdParty/`。提供 GNU Arm GCC 和 ST Arm Clang 两套构建配置。克隆仓库时需要同时拉取子模块：

```bash
git clone --recursive https://github.com/BJKJKZHOU/AxDr_L_Motor.git
cd AxDr_L_Motor
```

如果使用 GNU Arm GCC，需要预先安装 CMake（3.22 或更新版本）、Ninja 和 Arm GNU Toolchain，然后执行：

```bash
cmake --preset gcc-release
cmake --build --preset gcc-release
```

也可以使用 ST Arm Clang 构建：

```bash
cmake --preset Release
cmake --build --preset Release
```

### 通信与基本操作

通信协议与数据采集功能主要位于 `Comm/`。固件通过 USB CDC 与计算机通信，使用 AxDr CAN-FD 风格的应用层消息，支持参数读写、控制动作、运行状态查询和实时波形采集。

`Parameter/` 提供统一的参数访问接口。主机通过 Parameter ID 读写参数，通过 Action ID 执行控制动作。参数写入 RAM 与保存到 Flash 是不同操作，部分参数也存在运行状态限制。

| 操作 | 作用 |
|---|---|
| Parameter Read | 读取参数、运行状态或反馈数据 |
| Parameter Write | 修改允许写入的参数 |
| Save | 将需要持久化的参数保存到 Flash |
| Enable | 使能控制器 |
| Run | 按当前模式开始执行指令 |
| Stop | 停止当前运动或控制过程 |
| Disable | 禁用控制器 |

#### 新电机配置与运行

首次使用新电机时，需要核对供电、接线、硬件保护、电机极对数和电流限值。对于未知电机，可以通过 Rs/Ls、Flux 等辨识动作获取电气参数，检查辨识结果后再决定是否应用或保存。使用编码器进行闭环控制时，还需要配置编码器并完成相位标定。

完成配置后，可以选择 Torque、Speed 或 Position 模式，设置目标转矩、转速或位置及运动参数，再执行 Enable 和 Run。运行时可以读取实际电流、速度、位置和控制器状态，或通过波形采集观察控制效果。测试结束后执行 Stop；Stop 和 Disable 并非同一操作，停止过程取决于当前控制模式。

#### Python 通信示例

固件通过 USB CDC 进行通信。以 Linux 中的 `/dev/ttyACM0` 为例，可以使用 Python 读取当前电机的极对数。

首先安装 `pyserial`：

```bash
python3 -m pip install pyserial
```

下面的程序使用固件的 Parameter Read 协议，读取 Parameter ID 为 `0x0101` 的电机极对数：

```python
import struct
import time
import serial

MAGIC = b"AXDR"
NODE_ID = 1

MSG_PARAMETER = 0x07
MSG_RESPONSE = 0x02
PARAM_READ = 0x01
PARAM_MOTOR_PP = 0x0101
PARAM_U8 = 0

TXN = 1


def read_exact(ser, count, deadline):
    data = bytearray()
    while len(data) < count:
        if time.monotonic() >= deadline:
            raise TimeoutError("USB read timeout")
        data.extend(ser.read(count - len(data)))
    return bytes(data)


def read_frame(ser, deadline):
    sync = b""

    while time.monotonic() < deadline:
        sync = (sync + ser.read(1))[-4:]
        if sync != MAGIC:
            continue

        msg_id, length = struct.unpack(
            "<HB", read_exact(ser, 3, deadline)
        )
        if length not in (
            *range(9), 12, 16, 20, 24, 32, 48, 64
        ):
            raise ValueError("Invalid frame length")

        return msg_id, read_exact(ser, length, deadline)

    raise TimeoutError("No response frame")


request_id = (MSG_PARAMETER << 6) | NODE_ID
response_id = (MSG_RESPONSE << 6) | NODE_ID

payload = struct.pack(
    "<BBH", TXN, PARAM_READ, PARAM_MOTOR_PP
)
frame = MAGIC + struct.pack(
    "<HB", request_id, len(payload)
) + payload

with serial.Serial(
    "/dev/ttyACM0", 115200,
    timeout=0.1, write_timeout=1
) as ser:
    ser.write(frame)
    deadline = time.monotonic() + 2.0

    while time.monotonic() < deadline:
        msg_id, data = read_frame(ser, deadline)

        if msg_id != response_id or len(data) < 4:
            continue

        txn, msg, op, status = struct.unpack_from(
            "<BBBB", data
        )
        if (txn, msg, op) != (
            TXN, MSG_PARAMETER, PARAM_READ
        ):
            continue

        if status != 0:
            raise RuntimeError(
                f"Parameter read failed: {status}"
            )

        if len(data) < 8:
            raise ValueError("Incomplete parameter data")

        param_id, param_type, pole_pairs = (
            struct.unpack_from("<HBB", data, 4)
        )
        if (param_id, param_type) != (
            PARAM_MOTOR_PP, PARAM_U8
        ):
            raise ValueError("Unexpected parameter")

        print(f"Motor pole pairs: {pole_pairs}")
        break
    else:
        raise TimeoutError("Parameter response timeout")
```

若固件中配置的极对数为 7，程序将输出：

```text
Motor pole pairs: 7
```

该程序只读取参数，不修改控制器配置，也不会触发电机运动。

这里展示的是一个独立通信示例。实际进行连续参数访问、波形采集或电机控制时，可以参考固件仓库 `tools/sensorless_test.py` 中已有的通信解析实现。该测试脚本不保证始终兼容最新固件，使用前仍需审查。

VOFA+ 的 JustCANFD 协议支持可参考 [Vodka / JustCANFD](https://github.com/BJKJKZHOU/Vodka/tree/master/dataengines/justcanfd)。

**注意：** 固件直接控制电机功率级。实际运行前需要确认电源、电机接线、电流限制、PWM 配置及硬件保护措施，不建议直接使用未经检查的默认参数驱动未知电机。

### 测试脚本

仓库 `tools/` 目录下保存了一些 Python 脚本，主要用于电机参数辨识、控制算法测试、数据采集和问题排查。

这些脚本是我在开发和调试过程中，根据当时的测试需求编写和修改的，**不会随着固件功能和接口的变化同步更新，也不保证与当前固件版本兼容**。

**每次使用前都需要先审查脚本的具体实现**，确认通信接口、参数定义、控制流程和测试条件是否符合当前固件及实际硬件配置，必要时需要自行修改。

我自己在使用时，也通常会根据当前需要验证的问题调整脚本，而不是直接重复运行以前的测试脚本。因此，`tools/` 更适合作为测试方法和实验代码的参考，而不是可以直接使用的固定工具集。

---

**项目地址：** [AxDr_L_Motor - GitHub](https://github.com/BJKJKZHOU/AxDr_L_Motor)

**开源协议：** Apache-2.0（第三方组件遵循各自许可证）
