---
layout: post
title: "SPMSM 的 FOC 初始 PID 参数参考"
date: 2025-10-21
author: zhou_heng
categories: [文档笔记] 
tags: [PMSM,FOC,PID]
image: 
  path: /assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/Snipaste_2025-10-21_17-53-37.png
math: true
---

## SPMSM 数学模型

### PMSM电机 $$dq$$ 方程

#### $$d$$ 轴电压方程

$$
u_d=R_si_d+L_d\frac{di_d}{dt}-\omega_eL_qi_q
$$

#### $$q$$ 轴电压方程

$$
u_q=R_si_q+L_q\frac{di_q}{dt}+\omega_eL_di_d+\omega_e\psi_f
$$

#### 电磁转矩方程

$$
T_e=\frac{3}{2}n_p[\psi_fi_q+(L_d-L_q)i_di_q]
$$

对于表贴式永磁同步电机（SPMSM），$$L_d = L_q $$，方程简化为：

$$
T_e=\frac{3}{2}n_p\psi_fi_q
$$

#### 运动方程

$$
T_e-T_L=J\frac{d\omega_m}{dt}+B\omega_m
$$

## 电流环控制器的设计

&emsp;&emsp;本文采用的是 $$i_d = 0$$ 的控制方法，由于dq轴电流内环具有对称性和相似的系统特性，下面仅分析 $$q$$ 轴电流 PI 调节器的参数整定方法，$$d$$ 轴电流 PI 调节器的参数整定和 $$q$$ 轴类似。

![Current_loop_light](/assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/电流环1_light.svg){: .light .w-75 .rounded-10 }
![Current_loop_dark](/assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/电流环1_dark.svg){: .dark .w-75 .rounded-10 }

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

![Speed_loop_light](/assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/转数环框图_1_light.svg){: .light .w-75 .rounded-10 }
![Speed_loop_dark](/assets/img/2025-10-21-SPMSM的FOC初始PID参数参考/转数环框图_1_dark.svg){: .dark .w-75 .rounded-10 }

&emsp;&emsp;第一个为控制系统延时环节，第二个为转数环 PI 控制器，第三个为电流闭环传递函数 公式(11)。  
第四个由电机转矩方程 $$T_\mathrm{e}=\frac{3}{2}n_p\psi_\mathrm{f}i_\mathrm{q}$$ 得到。

$$
T_e-T_L=\frac{J}{n_p}\cdot\frac{d\omega_m}{dt} \tag{12}
$$

&emsp;&emsp;第五个框图 $$\frac{1}{sJ}$$ 由公式 (12) 得到，在 $$s$$ 域 $$\omega_m(s)=\frac{1}{Js}\left(T_e(s)-T_L(s)\right)$$（注意角速度是电气角还是机械角，此公式是机械角）。  
&emsp;&emsp;将控制系统延时和电流环时间常数合并为 $${T}_{\Sigma} = 5T_{s}$$，且先忽略负载转矩，得开环传递函数为：

$$
W_{os}(s)=\frac{K_{sp}(1+\tau_ss)}{\tau_ss}\frac{1}{(1+5T_ss)}\left(\frac{3}{2}n_p\psi_f\right)\left(\frac{1}{Js}\right)=\frac{\frac{3}{2}n_p\psi_fk_{sp}(\tau_ss+1)}{J\tau_ss^2(5T_ss+1)} \tag{13}
$$

典型Ⅱ型系统的开环传递函数为：

$$
W(s)=\frac{K(\tau s+1)}{s^2(Ts+1)} \tag{14}
$$

&emsp;&emsp;典型II型系统的待定参数有 $$𝐾$$ 和 $$\tau_{s}$$ 。若要保证系统的稳定需要保证 $$τ>T$$，为了方便分析，引入一个新的变量 $$ℎ_s$$ ，其中 $$ℎ_s$$ 是斜率为 $$‐20dB/dec$$ 的中频段宽度（对数表示），在典型Ⅱ型系统的伯德图中：
>低频段：两个积分环节，斜率 -40dB/dec  
>中频段：由于零点作用，斜率变为 -20dB/dec  
>高频段：由于极点作用，斜率回到 -40dB/dec  

&emsp;&emsp;频段的连接位置 $$\frac{1}{\tau}$$ 零点转折频率 ，$$\frac{1}{T}$$ 惯性环节转折频率，使用单位（rad/s）。

$$
h_s=\lg\frac{\omega_2}{\omega_1}=\lg\omega_2-\lg\omega_1=\lg\frac{1}{\text{T}_{\Sigma}}-\lg\frac{1}{\tau_s} \tag{15}
$$

&emsp;&emsp;还有的中频宽定义为 $$h= \frac{\tau}{T} =\frac{\omega_2}{\omega_1}$$ ，两个转折频率的比值，是一个无量纲的线性数值。
&emsp;&emsp;为保证系统获得最大的稳定裕度，一般将截止频率 $$𝜔_c$$ 设置在 $$\frac{1}{\tau_s}$$ 和 $$\frac{1}{\text{T}_{\Sigma}}$$ 的中点。由此可推出 $$𝜔_c$$：

$$
\omega_c = \sqrt{\omega_1 \cdot \omega_2} = \sqrt{\frac{1}{\tau_s} \cdot \frac{1}{T_{\Sigma}}} = \frac{1}{\sqrt{\tau_s T_{\Sigma}}} \tag{16}
$$

当 $$𝜔 = 1 \text{ rad/s}$$ 时，可推出开环增益 $$K$$ 。

$$
20\lg K=40(\lg\omega_1-\lg1)+20(\lg\omega_c-\lg\omega_1) \tag{17}
$$

$$
20\lg K=20(2\lg\omega_1+(\lg\omega_c-\lg\omega_1))=20(\lg\omega_1+\lg\omega_c)=20\lg(\omega_1\omega_c) \tag{18}
$$

$$
K=\omega_c\omega_1 \tag{19}
$$

由系统开环传递函数（13）和典型Ⅱ系统开环传递函数（14）可推出：

$$
\begin{cases}K=\frac{3}{2}\frac{n_p\psi_fK_p}{J\tau_s}\\T=5T_s&&\end{cases} \tag{20}
$$

根据典型Ⅱ型系统的参数整定关系可得:

$$
\frac{\frac{3}{2}n_p\varphi_fk_{sp}}{J\tau_s}=\frac{h+1}{2h^2(5T_s)^2} \tag{21}
$$

解出 $$k_{sp}$$ ：

$$
k_{sp}=\frac{2}{3}\frac{J\tau_s}{n_p\psi_f}\cdot\frac{h+1}{50h^2T_s^2} \tag{21.1}
$$

代入 $$ \tau_s=h\cdot T_\Sigma $$ 且 $$T_\Sigma=5T_s$$ 得：$$\tau_s=h\cdot5T_s$$ ，带入公式（21.1）得：

$$
k_{sp}=\frac{2}{3}\frac{J(h\cdot5T_s)}{n_p\psi_f}\cdot\frac{h+1}{50h^2T_s^2}=\frac{2}{3}\cdot\frac{J(h+1)}{10hT_sn_p\psi_f} \tag{21.2}
$$

计算积分增益 $$k_{si}$$ ：

$$
k_{si}=\frac{k_{sp}}{\tau_s}=\frac{\frac{2}{3}\cdot\frac{J(h+1)}{10hT_sn_p\psi_f}}{h\cdot5T_s}=\frac{2}{3}\cdot\frac{J(h+1)}{50h^2T_s^2n_p\psi_f} \tag{21.3}
$$

整理得出转速外环的PI参数为:
>
>$$
>\begin{cases}K_{sp}=\frac{2}{3}\cdot\frac{J(h+1)}{10hT_sn_p\psi_f}\\K_{si}=\frac{2}{3}\cdot\frac{J(h+1)}{50h^2T_s^2n_p\psi_f}&&&\end{cases} \tag{22}
>$$
{: .prompt-tip style="font-size: 1.5em;"}

&emsp;&emsp;当系统采样周期 $$𝑇_𝑠=0.00005$$ 时(PWM基频为20kHz)，$$ω = 2πf$$ ，由公式（15）得出第二个转折频率:  

$$
lg𝜔_2 = lg({2π}\frac{1}{5T_s}) = lg({2π}× 4000) = lg(25132)= 4.40 \tag{23}
$$

## 带宽设计 快速估算

&emsp;&emsp;系统开环传递函数（PI控制器、等效电流环和负载）：

$$
G(s)H(s)=\frac{K_p(\tau s+1)}{\tau s}\times\frac{1}{\text{T}_{\Sigma}s+1}\times\frac{1}{Js} \tag{24}
$$

将 $$K_p=2πfJ$$ 代入公式（24），得：

$$
G(s)H(s)=\frac{\omega_x(\tau s+1)}{\tau s^2(T_ss+1)} \tag{25}
$$

其中 $$\omega_x=2πf$$ 。
将式（25）与典型Ⅱ型系统开环传递函数（14）对比，得：$$K=\omega_x/\tau$$。 转折频率$$\omega_1=1/\tau$$。  
将 $$K$$ 和 $$\omega_1$$ 代入公式 (19) $$K=\omega_c\omega_1$$ 得：

$$
\frac{\omega_x}{\tau}=\frac{1}{\tau}\cdot\omega_c\quad\Rightarrow\quad\omega_x=\omega_c \tag{26}
$$

即 $$\omega_x$$ 能反应系统的开环截止频率。
