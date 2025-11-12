---
title: "simulink FOC PMSM 仿真搭建"
date: 2025-11-12 13:08:00 +0800
author: zhou_heng
categories: [文档笔记] 
tags: [FOC,Simulink,PMSM]
 
---

## 电机及模型基本参数

&emsp;&emsp;此文件是设置一些模型的基本参数。  
&emsp;&emsp;首先要确定系统运行的周期(频率)，如果逆变器运行基频为20kHz,
就设置 PWM_frequency = 20e3 ，根据基频计算出 PWM 开关周期 T_pwm。  
&emsp;&emsp;其他运行周期基本都是由基频确定的，比如转数环 Ts_speed 。  
&emsp;&emsp;电机参数设置建议先看 MATLAB 帮助中心的 [Surface Mount PMSM](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/surfacemountpmsm.html#mw_be7e5c67-af8b-46dc-9afb-6df693d34e63) 模块文档，先搞清楚每个参数是什么，
特别注意单位是什么。

```matlab
%% Set PWM Switching frequency
PWM_frequency 	= 20e3;    %Hz          // converter s/w freq
T_pwm           = 1/PWM_frequency;  %s  // PWM switching time period

%% Set Sample Times
Ts          	= T_pwm;        %sec        // Sample time step for controller
Ts_simulink     = T_pwm/2;      %sec        // Simulation time step for model simulation
Ts_motor        = T_pwm/2;      %Sec        // Simulation sample time
Ts_inverter     = T_pwm/2;      %sec        // Simulation time step for average value inverter
Ts_speed        = 10*Ts;        %Sec        // Sample time for speed controller


%% Set data type for controller & code-gen
%dataType = fixdt(1,32,17);    % Fixed point code-generation
dataType = 'single';           % Floating point code-generation


% lingdong12v

pmsm.model             ='motor1_12v';
pmsm.sn                ='001';
pmsm.p                 =6;          %motor1 极对数
pmsm.Rs                =0.05500/2;    %motor1 相电阻
pmsm.Ld                =0.09e-3/2;    %motor1 d轴电感
pmsm.Lq                =0.09e-3/2;    %motor1 q轴电感
pmsm.J                 = 4.56e-5;     %转动惯量45.6Kg*mm^2
pmsm.B                 =2.53e-08;     %粘滞摩擦系数
%pmsm.N_max            =5300;       %motor1 最高转速
pmsm.Ke                =1.84;       %motor1 Vpk_LL/krpm 反电动势常数
pmsm.Kt                =0.02647;    %转矩常量Nm/A,
pmsm.FluxPM            =(pmsm.Ke)/((sqrt(3)*2*pi*1000*pmsm.p)/60); %永磁链
pmsm.DC                =12;     %V，电源

ISenseMax = 11.2;   %A，电流限制

Kp_C=pmsm.Lq/(4*Ts); % 电流环比例系数
Ki_C=pmsm.Rs/(4*Ts); % 电流环积分系数

Kp_C_fc = 2*pi*pmsm.Lq*2300; % 电流环比例系数，使用带宽计算
Ki_C_fc = 2*pi*pmsm.Rs*2300; % 电流环积分系数，使用带宽计算
 
Kp_S=(pi*pmsm.J)/(45*5*Ts*10^(2.5/2)*pmsm.p*pmsm.FluxPM);
Ki_S=(pi*pmsm.J)/(45*5*Ts*10^(2.5/2)*pmsm.p*pmsm.FluxPM*4*Ts*10^(2.5));

```
## 模型设置

&emsp;&emsp;在模型设置中配置求解器，类型：定步长，求解器：离散(无连续状态)，
步长(基础采样时间)设置为 Ts_simulink 。  
&emsp;&emsp;此设置是可以配置代码生成的，也可以配置硬件实现([需要下载硬件支持包](https://ww2.mathworks.cn/support/install/support-software-downloader.html))  
&emsp;&emsp;数据导入，在 建模-模型资源管理器，点击 Model Workspace ，右侧
工作区数据，数据源：matlab文件，文件名，将上面保存的文件导入，
然后点击 从源重新初始化。

## 选择模块及连接

&emsp;&emsp;为了较快的搭建验证模型，直接选择 [Motor Control Blockset](https://ww2.mathworks.cn/help/releases/R2025b/mcb/index.html?s_tid=CRUX_lftnav) 中的模块。
如果自己想搞清楚每个模块是怎么计算的，可以使用基础模块搭建，就比较考验耐心。

![img_foc_svpwm](/assets/img/2025-11-12-simulink搭建FOC仿真/Snipaste_2025-11-12_13-09-38.png)

### 模块信息
#### 计算模块
&emsp;&emsp;可以复制模块名称，在 simulink 空白处双击鼠标左键，粘贴进去，就可以选择模块添加到模型中。

[Inverse Park Transform](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/inverseparktransform.html)  
[PWM Reference Generator](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/pwmreferencegenerator.html)  
&emsp;&emsp;SVPWM模块，点击模块选择SVM，此模块的输出需要归一化，在后面添加一个 Gain 模块，
增益设置为 1/(2*pmsm.DC/sqrt(3)) ，再+0.5，将信号移到 [0,1] 范围。因为查看此模块封装内部可发现，在输出最终结果前 Gain 了个
2/sqrt(3) ，所以后面归一化把此参数补回去。

[Clarke Transform](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/clarketransform.html)  
[SinCos Embedded Optimized](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/sincosembeddedoptimized.html)  
&emsp;&emsp;新版 Sine-Cosine Lookup 模块变为了 SinCos Embedded Optimized ，使用方式是一样的。

[Park Transform](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/parktransform.html)    

&emsp;&emsp;部分信号可使用goto和from模块连接，避免过长的信号线。   

#### 电机模块
![img_foc_svpwm](/assets/img/2025-11-12-simulink搭建FOC仿真/Snipaste_2025-11-12_23-51-22.png)

[Average-Value Inverter](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/averagevalueinverter.html)   
&emsp;&emsp;逆变器，将 SVPWM 后的归一化信号转换为电压信号，输出到电机，
另一个输入直接选常数Constant模块，参数 pmsm.DC 。

[Surface Mount PMSM](https://ww2.mathworks.cn/help/releases/R2025b/mcb/ref/surfacemountpmsm.html)  

![img_foc_svpwm](/assets/img/2025-11-12-simulink搭建FOC仿真/Snipaste_2025-11-13_00-06-39.png)  

&emsp;&emsp;将上面的电机参数填写到模块中，
详细信息注意看帮助文档，输出总线信号 Info 可以使用 Bus Selector 模块展开选择。  
&emsp;&emsp;在总线信号中选择 MtrPos（电机的机械角位置，θm，弧度）引出，
接 Gain 模块，增益设置为 pmsm.p ，将机械角位置转换为电角度位置(rad 单位不变)，
角度输出到 SinCos Embedded Optimized 的输入。   
&emsp;&emsp;MtrSpd 电机的机械角速度，单位 rad/s ，将此参数反馈到转数环时注意单位要变换为rpm。
此参数的另一个作用是电流环的解耦，需要转换为电角频率，乘 pmsm.p 。
   
### 控制回路
&emsp;&emsp;双击搜索 PID ,选择 PID Controller，
控制器选择 PI，时域选择离散，速度环采样时间填 Ts_speed ，电流环可以默认。  
&emsp;&emsp;参数选择文件中的默认参数，基本是稳定的，可以在此基础上微调。  
&emsp;&emsp;按照一般的FOC控制框图将PID模块连接起来。  
&emsp;&emsp;在 调试 点击 叠加信息，选择采样时间下的颜色，就可以用不同的颜色
来反应模块的执行频率。

![img_foc_svpwm](/assets/img/2025-11-12-simulink搭建FOC仿真/Snipaste_2025-11-13_01-06-50.png)  

&emsp;&emsp;电机转数波形
![img_foc_svpwm](/assets/img/2025-11-12-simulink搭建FOC仿真/Snipaste_2025-11-13_01-13-13.png)  
