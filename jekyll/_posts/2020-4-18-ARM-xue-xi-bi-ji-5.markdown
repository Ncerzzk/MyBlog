---
layout: post
title: ARM学习笔记5——Flash
date: 2020-04-18 18:50:32 +0900
categories: 技术 arm
issue_id: 95
---

NOR Flash
- 可以随机读（像内存一样，意味着可以执行代码），但无法随机写（需要整块写）
- 有专门的地址线 数据线

NAND Flash
- 没有专门的地址线 数据线，发送指令、数据、地址都使用总线
- 擦除、写入速度比NOR flash快
 

一般来说，由于NOR FLASH可以执行代码，因此常用来作为BIOS等用途。

在STM32中，内置FLSAH应该也是NOR FLASH。

因为其在启动文件中，有一段汇编代码是将bin中data段（也就是代码部分）复制到内存中执行，而
这段汇编代码显然是在FLASH中执行的。

```c
  movs r1, #0
  b LoopCopyDataInit

CopyDataInit:
  ldr r3, =_sidata
  ldr r3, [r3, r1]
  str r3, [r0, r1]
  adds r1, r1, #4

LoopCopyDataInit:     /* 复制bin文件中data段的数据到内存 */
  ldr r0, =_sdata
  ldr r3, =_edata
  adds r2, r0, r1
  cmp r2, r3
  bcc CopyDataInit
  ldr r2, =_sbss
  b LoopFillZerobss
```

