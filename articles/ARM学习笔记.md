﻿# ARM学习笔记
ctime:2018-12-08 12:07:49 +0800|1544242069

标签（空格分隔）： 技术 硬件

---
### arm架构基本知识
cortex实际上是ARMV7架构的，分为cortex-A,cortex-M,cortex-R三类。前者性能较强，可跑linux等系统，中间是单片机，后者性能介于两者之间，跑实时操作系统。

cortex-A9是基于ARMV7-A架构的处理器。
以下内容若无特别说明，都是指cortex-A9处理器。

### 处理器状态及工作模式
处理器状态，四种：指令集状态，执行状态，安全状态，调试状态

- 指令集状态
    - arm 状态 （32位指令集）
    - Thumb 状态 （16位指令集）
    - Jazelle 状态 （java加速器）
    - ThumbEE 状态 （16位指令集 增加DSP指令）
- 执行状态等不太重要（看不懂），略过

工作模式
- 用户模式（USR）
- 快速中断模式（FIQ）
- 外部中断模式（IRQ）
- 管理模式（SVC）
- 监视模式（MON）
- 欲取指令中止异常（ABT）
- 超级管理模式（HYP）
- 未定义指令模式（UND）
- 系统模式（SYS）

除了用户模式与系统模式以外的模式称为异常模式。每种异常模式都有一组寄存器，进入异常时，直接使用异常模式的寄存器，就不必破坏用户模式下的寄存器，也不用再保存现场恢复现场等。

### 寄存器
共有42个寄存器（每个寄存器为32位寄存器），在不同的工作模式下，会使用不同的寄存器组，但在程序中，寄存器的名字是完全一样的。

- R0-R7 ，8个，用来保存数值，这个8个寄存器与工作模式无关，所有工作模式共用。
- R8-R14，取决于工作模式。
    - 其中R8-R12有两组，快速中断用一组（R8_fiq等后面带fiq后缀的），其他模式用一组。这是为了快速模式可以不用进行保护现场等操作
    - R13 R14 在不同模式下，对应不同寄存器。
        - R13（SP 堆栈指针寄存器），指向堆栈
        - R14 (LR 链接寄存器），用于保存子程序返回地址。啥意思呢，就是当你调用子程序时，要跳转过去的时候，先把调用完子程序之后指向的第一句话的地址存进LR里，当子程序执行完，此时读取LR，调回到主程序中。使用 **BL** 命令时，这些操作是自动完成的。因此，在子程序（或者中断处理程序中，不能破坏LR，或者说，即使你改动了，在子程序结束前，一定要改回去，否则程序就飞了）
    - R15 （PC 程序指针寄存器，指向当前要Fetch的指令）
    - CPSR 程序状态寄存器，控制处理器模式等就是通过改变CPSR的某些位来实现的
    - SPSR 程序状态保存寄存器（每个异常模式都有一个），当异常模式发生时（可能是进入中断或者什么），将CPSR的值保存到该模式下对应的SPSR，当异常模式退出，即要返回正常模式主程序时，通过SPSR保存的值把CPSR的值复原。

### CPSR里面有些啥
- 条件标志位（N Z C V，主要是负标志  零标志   进位标志  溢出标志），用于条件执行
- Q标志用于指示DAP指令（？啥玩意儿）是否溢出
- J标志位 和T 标志位，用于指示处理器的指令集状态
- IT标志位（IF—THEN），用于Thumb指令集的(IF-THEN)
- 大于等于标志位（SIMD指令集？是啥）
- 大小端控制位
- 异常（中断）屏蔽位，可以屏蔽 异步异常（是啥？） IRQ FIQ
- 模式控制，用于控制运行在什么模式下
    




