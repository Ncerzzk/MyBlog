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


[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/mips_op_code.png