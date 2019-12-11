# 《计算机组成与设计 硬件软件接口》 笔记
ctime:2019-12-11 00:23:25 +0900|1575991405

标签（空格分隔）： 技术 硬件 

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

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_op_code.png

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_process.png
[3]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_memory.png