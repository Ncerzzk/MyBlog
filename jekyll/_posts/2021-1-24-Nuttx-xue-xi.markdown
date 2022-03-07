---
layout: post
title: Nuttx学习
date: 2021-01-24 21:28:41 +0800
categories: 技术 硬件
issue_id: 149
---

Nuttx是一个开源的RTOS，PX4中用的操作系统就是它，据手册描述，坚持POSIX兼容，因此可以当作一个简单版的RTOS linux来学习。

## 启动过程分析(以STM32为例)

'''
__Start(定义于:stm32_start.c)
  /* Configure the UART so that we can get debug output as soon as possible */
  stm32_clockconfig();
  stm32_fpuconfig();
  stm32_lowsetup();
  stm32_gpioinit();
  /* Clear .bss.  We'll do this inline (vs. calling memset) just to be
   * certain that there are no issues with the state of global variables.
   */

  for (dest = _START_BSS; dest < _END_BSS; )
    {
      *dest++ = 0;  // 手动将BSS段清空，BSS段用于放置全局变量，没有初始化的全局变量必须都为0
    }
  
  for (src = _DATA_INIT, dest = _START_DATA; dest < _END_DATA; )
    {
      *dest++ = *src++;   // 复制数据段
    }
  
  

'''