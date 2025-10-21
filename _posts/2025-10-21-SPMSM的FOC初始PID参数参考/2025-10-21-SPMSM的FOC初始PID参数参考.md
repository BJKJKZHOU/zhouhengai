---
layout: post
title: "SPMSM的FOC初始PID参数参考"
date: 2025-10-21
author: zhou_heng
categories: [文档笔记] 
tags: [文档笔记,PMSM,FOC,PID]
image: assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/Snipaste_2025-10-21_17-53-37.png
math: true
---

## SPMSM传递函数

&emsp;&emsp;永磁同步电机（SPMSM）的电气方程可以表示为：

## 电流环控制器的设计

&emsp;&emsp;本文采用的是 $$i_d = 0$$ 的控制方法，由于dq轴电流内环具有对称性和相似的系统特性，下面仅分析 $$q$$ 轴电流 PI 调节器的参数整定方法，$$d$$ 轴电流 PI 调节器的参数整定和 $$q$$ 轴类似。

![电流环控制框图-浅色](assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/电流环1 light.svg){: .light .w-75 .rounded-10 }
![电流环控制框图-深色](assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/电流环1 dark.svg){: .dark .w-75 .rounded-10 }

&emsp;&emsp;电流环的控制器输入由电流设定值和电流反馈之间的差值构成，其输出信号则是参考电压。  
&emsp;&emsp;第一个框图 $$\frac{1}{1+T_S}$$ 为系统延时环节，第二个为 PI 控制器，第三个为逆变器延时环节。$$T_s$$ 表示电流环的采样周期(可以是PWM基频或更高)，忽略掉动态项 $$𝜔𝜓_f$$ 和耦合项 $$𝜔𝐿_𝑑𝑖_𝑑$$（可以使用前馈电流环解耦实现），$$q$$轴的电磁方程可以写成：

$$
u_q=L_q\frac{di_q}{dt}+R_si_q \tag{1}
$$

由（1）式得电机的传递函数：

$$
G_p(s)=\frac{i_q}{u_q}=\frac{1}{L_qs+R_s} \tag{2}
$$

将PI调节器的传递函数化为零极点的形式为：

$$
C(s) = k_{Ip}+\frac{k_{Ii}}{s}=k_{Ip}\frac{\tau_{I}s+1}{\tau_{I}s} ，\tau_I=\frac{k_{Ip}}{k_{Ii}} \tag{3}
$$

其中 $$k_{Ip}$$ 为 PI 控制器的比例系数，$$k_{Ii}$$ 为 PI 控制器的积分系数。角标带 $$I$$ 表示电流环。
由于$$T_s$$足够小，可以将两个延时环节合并为 $$\frac{1}{1+2T_ss}$$ 。  
&emsp;&emsp;经过PI调节器校正后的电流环开环传递函数为：

$$
W_{oi}(s)=k_{Ip}\frac{\tau_Is+1}{\tau_Is}\frac{1}{(2T_ss+1)}\frac{1}{(L_qs+R_s)} \tag{4}
$$

令 $$\tau_{I}=\frac{L_{\mathrm{q}}}{R_{\mathrm{s}}}$$ (电机电气时间常数) ，使用极点对消法将开环传递函数校正成典型Ⅰ型系统：

$$
W_{oi}(s)=\frac{K_{Ip}\left(1+\frac{L_q}{R_s}s\right)}{\frac{L_q}{R_s}s}\frac{1}{(1+2T_ss)R_s\left(1+\frac{L_q}{R_s}s\right)}=\frac{K_{Ip}}{L_qs(1+2T_ss)} \tag{5}
$$

典型Ⅰ型系统的开环传函为：

$$
W(s)=\frac{K}{s(Ts+1)} \tag{6}
$$

由公式 (5) 和 (6) 可推出：

$$
\begin{cases}K=\frac{K_{Ip}}{L_{q}}\\T=2T_{s}&\end{cases} \tag{7}
$$

由典型Ⅰ型系统动态性能指标参数表，如果没有特殊要求，取 $$𝜉=0.707，𝐾𝑇=0.5$$ 。从而有：

$$
2T_s\cdot\frac{k_{Ip}}{L_q}=\frac{1}{2} \tag{8}
$$

由公式 (8) 可推导 PI 控制器参数公式：

>$$
>\begin{cases}k_{Ip}=\frac{L_q}{4T_s}\\k_{Ii}=\frac{k_{Ip}}{\tau_I}=\frac{k_{Ip}}{L_q/R_s}=\frac{R_s}
>{4T_s}&\end{cases}  
>\tag{9}
>$$
{: .prompt-tip style="font-size: 1.5em;"}

由公式 (5) 开环传递函数可得出闭环传递函数：

$$
G_{oi}(s)=\frac{\frac{K_{Ip}}{L_qs(1+2T_ss)}}{1+\frac{K_{Ip}}{L_qs(1+2T_ss)}}=\frac{K_{Ip}}{2T_sL_qs^2+L_qs+K_{Ip}} \tag{10}
$$

当具有较高的开关频率时，$$T_s$$ 的取值够小，就可以认为 $$s^2$$ 的系数为零，并将式 (8) 带入。由此可以得到电流环等效闭环传递函数：

$$
G_{oi}(s)=\frac{K_{Ip}}{L_qs+K_{Ip}}=\frac{1}{\frac{L_q}{K_{Ip}}s+1}=\frac{1}{4T_ss+1} \tag{11}
$$

## 转数环控制器设计

&emsp;&emsp;将负载转矩 $$T_L$$ 当作扰动引入，由于粘滞摩擦系数 $$B$$ 在实际工程中不容易测量，忽略不计后对控制系统影响较小。由电机数学模型可以得到转速环近似控制框图。

![转数环控制框图-浅色](assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/转数环框图 1 light.svg){: .light .w-75 .rounded-10 }
![转数环控制框图-深色](assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/转数环框图 1 dark.svg){: .dark .w-75 .rounded-10 }

&emsp;&emsp;第一个为控制系统延时环节，第二个为转数环 PI 控制器，第三个为电流闭环传递函数 公式(11)。  
第四个由电机转矩方程 $$T_\mathrm{e}=\frac{3}{2}n_p\psi_\mathrm{f}i_\mathrm{q}$$ 得到。

$$
T_e-T_L=\frac{J}{n_p}\cdot\frac{d\omega_m}{dt} \tag{12}
$$

&emsp;&emsp;第五个框图 $$\frac{1}{sJ}$$ 由公式 (12) 得到，在 $$s$$ 域 $$\omega_m(s)=\frac{1}{Js}\left(T_e(s)-T_L(s)\right)$$（注意角速度是电气角还是机械角，此公式是机械角）。  
&emsp;&emsp;将控制系统延时和电流环时间常数合并为 $$5T_{s}$$，且先忽略负载转矩，得开环传递函数为：

$$
W_{os}(s)=\frac{K_{sp}(1+\tau_ss)}{\tau_ss}\frac{1}{(1+5T_ss)}\left(\frac{3}{2}n_p\psi_f\right)\left(\frac{1}{Js}\right)=\frac{\frac{3}{2}n_p\psi_fk_{sp}(\tau_ss+1)}{J\tau_ss^2(5T_ss+1)} \tag{13}
$$

典型Ⅱ型系统的开环传递函数为：

$$
W(s)=\frac{K(\tau s+1)}{s^2(Ts+1)} \tag{14}
$$

典型II型系统的待定参数有 $$𝐾$$ 和 $$\tau_{s}$$。为了方便分析，引入一个新的变量 $$ℎ_s$$ 中频宽，在典型Ⅱ型系统的伯德图中：
>低频段：两个积分环节，斜率 -40dB/dec
>中频段：由于零点作用，斜率变为 -20dB/dec
>高频段：由于极点作用，斜率回到 -40dB/dec

$$
h_s=\lg\frac{\omega_2}{\omega_1}=\lg\omega_2-\lg\omega_1=\lg\frac{1}{T_{sm}}-\lg\frac{1}{\tau_s}
$$

为保证系统获得最大的稳定裕度，一般将截止频率 $$𝜔_c$$ 设置 $$\frac{1}{\tau_s}$$ 在 $$\frac{1}{T_{sm}}$$ 和的中点。
