---
layout: post
title: 操作系统笔记（一）分段机制、特权级
date: 2020-04-29 11:08:05 +0800
categories: 技术 操作系统
issue_id: 104
---

## 课程实验手册地址：https://legacy.gitbook.com/book/chyyuu/ucore_os_docs

## 练习3 分析bootload是如何从实模式进入保护模式的

很多东西还不清楚,这里单纯翻译一下bootasm.s里干了什么

### 开启A20

- cli;cld   关中断，清方向标志位
- 设置ds es ss为0
- 等待8042缓冲器为空，8042的的命令端口（地址:0x64）写入0xd1,此命令的意思为：“准备写Output端口。随后通过60h端口写入的字节，会被放置在Output Port中。”
- 继续等待8042缓冲器为空，向数据端口（地址:0x60）写入0xdf(b11011111)
- >    The output port of the keyboard controller has a number of functions.
    Bit 0 is used to reset the CPU (go to real mode) - a reset happens when bit 0 is 0.
   Bit 1is used to control A20 - it is enabled when bit 1 is 1, disabled when bit 1 is 0.
- 以上，通过写入8042，打开了A20。为什么要打开A20？因为按照以前16位CPU（8086），地址线只有20条，寻址空间为2^20。实模式是兼容8086的，所以有一个A20，专门控制地址线的第20位。如果没打开A20，第20位永远是0。
- 但是，需要注意的是，这个和是否进入保护模式无关，即使不打开A20，也可以进入保护模式。但是由于第20位永远为0，因此只能访问1M 3M 5M这样奇数的内存，内存就不连续了。参考地址：https://www.cnblogs.com/kuwoyidai/archive/2010/12/29/2046247.html    
https://chyyuu.gitbooks.io/ucore_os_docs/content/lab1/lab1_appendix_a20.html
  
### 进入保护模式

- 建立gdt（全局段描述符表 Global Descriptor Table）
- 设置CR0的PE标志位为1，进入保护模式
- 注意：进入保护模式之后，分段储存管理机制就开始了，此时会自动开启分段地址转换。
  - 分段地址转换会将CS的内容作为段选择子，去段表中（可能是gdt也可能是ldt，根据段选择子的某一位判断）找相应的段
  - 段表中，每个段的描述有：段基址、段界限、段属性（粒度：1字节为单位还是4K字节为单位、类型：代码段还是数据段、特权级、段存在位、已访问位）
  
```ASM
    lgdt gdtdesc
    # 建立gdt
    # gdtdesc 为48位的内容，包括16位的段表长度，32位的段表地址
    movl %cr0, %eax  # 包括以下两句，进入保护模式
    orl $CR0_PE_ON, %eax
    movl %eax, %cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.
    ljmp $PROT_MODE_CSEG, $protcseg
    # 跳入保护模式的代码，PROT_MODE_CSEG = 8，注意此时已经开启分段地址转换了，段索引从第三位开始，所以这个表示的段索引是1（段索引为0是一个空段）
```

再看看建立全局段表：

```ASM
gdt:
    SEG_NULLASM                                     # null seg
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel
```

第一个段为空，是CPU的要求。接下来是代码段，然后是数据段。这两个段的段基址都是0，界限都是4G。可以发现这两段是重叠的，唯一不同的是权限，
代码段可执行、可读，不可写。数据段可写（想必也可写）。

进入保护模式后，跳到保护模式的代码，接下来就是引导启动系统了。

### 补充说明

有关计算机启动。BIOS的入口点实际上0xFFFF0(CS:0xF000,IP:FFF0)，这里是BIOS执行的第一个指令，该指令是一个跳转指令（JMP F000:E05B），跳转到
BIOS的最初始部分开始执行。通过计算可以发现，这个BIOS占用的大小只有7KB(0xFFFF0-0xFE05B)。BIOS最大可以有64KB。

这个BIOS执行的内容是，硬件自检、初始化，然后选择启动设备，读取该设备的第一个扇区（主引导扇区）到内存的一个特定的地址0x7c00处。也就是将Bootloader读取到内存。BIOS并不亲自参与系统的引导和启动。本文以上分析的，是bootloader的内容。

#### 特权级保护

（80386）CPU分为0-3四种特权级，0为内核态，权限最高，3为用户态，权限最低。

在建立全局段描述符表的时候，会给每个段都设置一个DPL（描述符特权级）。

CS寄存器的最低两位，是CPL（当前代码段的特权级）

每次发起内存请求时，会有一个RPL（请求特权级），只有当max(CPL,RPL)<=DPL时，才可以正常访问内存，否则会发生一个一般保护异常。
