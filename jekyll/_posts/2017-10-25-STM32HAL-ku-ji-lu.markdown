---
layout: post
title: STM32HAL库记录
date: 2017-10-25 11:11:26 +0800
categories: 技术 硬件
issue_id: 22
---
之前想做的PCB四旋翼已经开始动工了，这个四旋翼用了405的芯片，性能比以前103提升了很大。再加上ST在F4系列上推荐使用HAL库（实际上ST也有F4的STD库，但不知道藏在哪个角落），因此打算重新用HAL库写一下飞控的代码。

首先是刚用HAL库的印象，主要就是封装得比较完善。很多以前STD库上要自己封装的东西，他帮你封装好了。但由此也造成一个问题，就是人家封装的思路可能和你的不太一样，所以刚开始上手的时候很不习惯。后来慢慢看他的封装，总算能明白大概。

用HAL库，就不得不说ST的QubeMX这工具，通过可视化界面来配置你想要的功能，并生成__初始化代码__。

下面主要记录一下生成的HAL工程中，初始化的思路。
1. 调用 `HAL_Init()` 函数
     - 在这个函数中，设置了`HAL_NVIC_SetPriorityGrouping(NVIC_PRIORITYGROUP_4);`也就是设置了中断的优先级分组为4，需要注意的是，HAL库有个小BUG，他在多个地方都设置了优先级分组，因此最好把其他地方的删去，只留一个地方，不然之后要修改很麻烦。
     - ` HAL_InitTick(TICK_INT_PRIORITY);`设置了SysTick的中断，这个也多个地方都设置了。
     - 调用`HAL_MspInit();`这个函数在Hal.c中定义为weak，实际上它在Hal_msp.c中重定义了，主要也就是设置一些内部中断的优先级。
1. 调用`SystemClock_Config()`，设置时钟。
    - 需要注意的是，如果使用外部晶振，即HSE。因为使用的晶振是8M的，因此应该在hal_conf.h文件中，修改`HSE_VALUE`的值。
1. 接下来是各种外设的初始化。
    - 以串口为例子，`MX_USART2_UART_Init`为串口的初始化函数。需要注意的是，这个函数只设置了串口的“抽象层”，然后调用`HAL_UART_Init(&huart2)`进行抽象层的配置。至于IO口、时钟、中断等设置，在hal_msp.c文件中，会重定义一个函数`void HAL_UART_MspInit(UART_HandleTypeDef* huart)`。`HAL_UART_Init()`会在一个隐秘的角落调用这个底层初始化函数。这些是QubeMX帮你干的事，但实际上，要使串口正常工作，还需要设置串口的中断优先级，并使能串口中断。即
```
HAL_NVIC_SetPriority(USART2_IRQn,	10,0);
HAL_NVIC_EnableIRQ( USART2_IRQn);
```
中断服务函数在it.c中，一般是调用一个统一的串口中断服务函数`HAL_UART_IRQHandler(&huart2);`，将串口指针传入即可。该函数中处理了发送、接受、DMA中断等。







