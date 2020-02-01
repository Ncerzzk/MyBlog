---
layout: post
title: STM32的一个狗屎BUG 
date: 2019-08-26 12:36:43 +0900
categories: 技术 硬件
---

机器人招新二面打算让他们调调飞机，前几天抽时间把以前那个F405的小飞机MCU改成了F103C8，
简化了电路，把5V升压和电池充电用一片ETA9640完成。

不过遇到了一个bug，就是PB5，也就是二号电机的PWM控制信号，一初始化PB5的GPIO为定时器复用
模式，PB5马上就输出为高电平，电机全速运转。

找了很久没找到原因。陆续找了几个原因，但后来都证明不是：

- PB5和3V3或者和什么引脚短路了（推翻）
- MOS短路（推翻，因为后来证实程序开始跑才会全速转，一按复位就停了）
- 单片机的PB5IO被烧了（因为一开始焊的一个mos是坏的（从某个板子拆的））（推翻，换了个芯片，情况依旧）
- STMF103c8t的部分重映射问题。我一度以为这就是问题所在，因为手册里写了TIM3的完全重映射只存在于
64 100 144引脚的型号，我怀疑48引脚的连部分重映射都不行。网上也有一些文章讲到C8的部分重映射有问题，不过他是PB4。
但我的PB4十分正常。


最后，看了某篇文章，突然想起来去找勘误手册，果然在上面找到了问题。


### I2C1 and TIM3_CH2 remapped
- Conditions
  - I2C1 and TIM3 are clocked.
  - I/O port pin PB5 is configured as an alternate function output.
Description:Conflict between the TIM3_CH2 signal and the I2C1 SMBA signal, (even if SMBA is not
used).

In these cases the I/O port pin PB5 is set to 1 by default if the I/O alternate function output is
selected and I2C1 is clocked. TIM3_CH2 cannot be used in output mode.
Workaround

To avoid this conflict, TIM3_CH2 can only be used in input mode.