---
layout: post
title: ARM学习笔记5——Flash、MMU
date: 2020-04-18 17:50:32 +0800
categories: 技术 arm
issue_id: 96
---

## FLASH

### NOR Flash

- 可以随机读（像内存一样，意味着可以执行代码），但无法随机写（需要整块写）
- 有专门的地址线 数据线

### NAND Flash

- 没有专门的地址线 数据线，发送指令、数据、地址都使用总线
- 擦除、写入速度比NOR flash快
 
一般来说，由于NOR FLASH可以执行代码，因此常用来作为BIOS等用途。

在STM32中，内置FLSAH应该也是NOR FLASH。

因为其在启动文件中，有一段汇编代码是将bin中data段（也就是代码部分）复制到内存中执行，而
这段汇编代码显然是在FLASH中执行的。

```asm
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

那么，如果不复制是否可以呢？

不行。arm的程序镜像（Image)，也就是烧录的bin文件中，包含RO段、RW段和ZI段。
由于ZI段全是0，因此实际上在bin文件中并没有包含ZO段，只是烧录的时候会将没用到的地方全写成0。

而RO段则是Read only的意思，RO段中包含指令和常量。

RW段则是Read Write的意思，RW段中包含变量。而在我们随便一个C程序中，基本上都要使用变量，而上面也说了
内置FLASH可以随机读，并不能随机写，也就是你只能读取变量的值，并不能改变，那不就是常量嘛

因此，如果不将程序复制到SRAM中，程序是无法正常运行的，当然了，如果写个1+1这种全是常量的语句，也是可以运行的，但是意义不大。


## MMU（内存管理单元）

对于32位的CPU而言，寻址空间为0-0xFFFF FFFF(4GB)。而实际的器件内存可能只有1GB。

通过MMU，可以将虚拟内存地址映射到物理内存地址，可能有多个虚拟内存地址映射到同一块物理内存，也可能有
虚拟内存地址并没有映射到物理内存上（等用到的时候再分配）

### MVA VA PA

VA:Virtual Address
MVA:Modified Virtual Address
PA:Physical Address

对于CPU而言，它发出的都是VA（当然了，得在MMU启动之后，在MMU启动之前，CPU操作的都是物理地址）
在VA转化为PA之前，它会先转化为MVA（硬件自动完成）（MMU只能看得见MVA）

在arm9中，VA转为MVA的算法为：

- 如果VA小于32M，则会 `VA|（PID<<25)`
- 如果VA大于32M，则`MVA=VA`
  
用这种方式，可以加快切换进程的速度，这样两个进程假设VA都是0，但由于进程PID不同则MVA也不同，映射的物理地址也不同。

这里有个问题，为什么是32M（2^25)，是因为这里取了PID的低7位来参与运算，如果只取PID的低4位，那么就是256M(2^28)了。

