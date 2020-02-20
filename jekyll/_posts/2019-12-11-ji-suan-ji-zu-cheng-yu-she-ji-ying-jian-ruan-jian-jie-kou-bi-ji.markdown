---
layout: post
title: 《计算机组成与设计 硬件软件接口》 笔记
date: 2019-12-11 00:23:25 +0900
categories: 技术 硬件
issue_id: 0
---
得好好学学计算机组成和体系结构了。

### 计算机系统的八个设计原则

- 面向摩尔定律
- 抽象简化设计
- 加速大概率事件
- 通过并行提高性能
- 通过流水线提高性能
- 通过预测提高性能
- 存储器分层
- 通过冗余提高可靠性 

### 组成计算机的五个部件
- 输入
- 输出
- 存储器
- 数据通路
- 控制器

处理器（CPU）指数据通路+控制

### 存储器
DRAM:dynamic random access memory: 动态随机访问存储器
SRAM:static random access memory:静态随机访问存储器

SRAM 速度比 DRAM快，一般用作缓存，在存储器分层中，是DRAM的上层

非易失性存储器：磁盘（硬盘）、闪存

### 性能的定义
- 响应时间:某个程序的执行时间
- 吞吐率:单位时间完成的任务数量

CPI:clock cycle per instruction(每条指令所需要的时钟周期平均数

## MIPS 指令集（32位 MIPS)

- 32个寄存器，每个寄存器32 bit
- 指令字段(R型指令)，从高到底分别为 op , rs , rt, rd, shamt , func
  - op 操作码
  - rs 第一个源操作数寄存器
  - rt 第二个源操作数寄存器
  - rd 结果保存寄存器
  - shamt 偏移量
  - func 功能码，用于指令变式
-  R型指令的偏移量shamt 只有5位，最大才32，因此为了加大偏移量，又有了I型指令，方便立即数的操作
-  I型指令：op rs rt constant_or_address(16位)
-  J型指令：op address(26位),用于立即数跳转
   
![MIPS指令编码][1]

### MIPS 过程（子程序）调用
过程调用寄存器分配：
- a0-a3,放置参数
- v0,v1,放置返回值
- ra,放置过程结束后要返回的指令地址

![过程执行][2]

那么，如果过程的参数超过4个，或者结果超过2个的情况如何处理呢。使用栈。栈也用来在过程调用前，保存一些寄存器的值，在过程调用后恢复。

除了寄存器的值，一些局部变量也可能需要用到栈，比如临时寄存器用完之后。

- 栈指针sp, 总是指向栈顶
- 帧指针fp, 总是指向活动帧的第一个字，实际上就是指向栈底
  - 帧指针不是必须的，因为实际上对于栈来说，它不需要知道栈底。入栈出栈只需知道栈顶即可
  - 有些编译器使用了帧指针(GNU MIPS C),有些编译器则没有使用(MIPS C)
  
![内存分配][3]

超过四个参数的处理方式：

![超过4个参数的处理方式][4]

### 跳转 条件分支
跳转方式：
- 立即数跳转（26位）
- 寄存器跳转（32位）
- 条件分支(16位)
  - 条件分支跳转目的地位：16位字地址X4（转为字节地址）+ (PC+4)(下一条指令的地址)

以上地址都是字地址，如果转为字节地址需要X4.

### 寻址模式
![寻址模式总结][5]

### 同步原语
这部分看得不是很懂。

锁的建立过程：
在储存器的某个单元作为加锁的标志，1为加锁，0为未加锁。那么多个处理器如果要对这个储存器加锁，先访问这个单元，并将1对这个单元写1，并取得返回值（返回值是原值），那么当返回值为0时，即加锁成功。

MIPS中使用指令对来实现同步原语。

关于原子性：如果处理器的操作都是在这对（这条）指令前，或者指令后执行的，那么该指令就是原子的。

在MIPS中，采用指令对。即第一条指令执行完之后，第二条指令来返回上条指令是不是原子的。怎么理解呢，第一条指令执行完之后，中间可能执行了其他指令，那么此时，返回值就是是非原子的。
对应的指令是：链接取数（load linked),条件存数(store conditional)


[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_op_code.png

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_process.png
[3]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_memory.png
[4]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_more_than_4.png
[5]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_find_address.png