---
layout: post
title: 操作系统笔记（四）中断
date: 2020-04-30 13:33:34 +0900
categories: 技术 操作系统
issue_id: 101
---

## 练习6

- 中断描述符表（也可简称为保护模式下的中断向量表）中一个表项占多少字节？其中哪几位代表中断处理代码的入口？
  - 8个字节
  - 16-31位表示段选择子，0-15位为偏移的低16位，高16位位于中断描述符的最高16位(48-64位)

8086（80386）的中断向量表并不像ARM的中断向量表放在地址0处，而是位置可变。当建好中断向量表之后，
通过lidt指令，将中断向量表的地址给IDTR寄存器，这样当CPU发生中断时，他会从这个IDTR寄存器获取到中断向量表的位置，
然后在里面找相应的中断服务函数的地址。

与gdt（全局内存分段描述表）一样，传给lidt除了要给中断向量表的地址外，还要给内存界限。因此也是32+16=48位。

建立idt的函数：

```c

#define SETGATE(gate, istrap, sel, off, dpl) {            \
    (gate).gd_off_15_0 = (uint32_t)(off) & 0xffff;        \
    (gate).gd_ss = (sel);                                \
    (gate).gd_args = 0;                                    \
    (gate).gd_rsv1 = 0;                                    \
    (gate).gd_type = (istrap) ? STS_TG32 : STS_IG32;    \
    (gate).gd_s = 0;                                    \
    (gate).gd_dpl = (dpl);                                \
    (gate).gd_p = 1;                                    \
    (gate).gd_off_31_16 = (uint32_t)(off) >> 16;        \
}


void
idt_init(void) {
     extern uintptr_t __vectors[];
     for(int i=0;i<256;++i){
         SETGATE(idt[i],0,0x08,__vectors[i],0);    // 0x08是内核的段选择子
     }
     lidt(&idt_pd);
}
```

### 中断门

中断门（IDT gate descriptors，实际上应该翻译成 中断描述符表的门描述符，很拗口)，共有三种门描述符。

- Task-gate 
- Interrupt-gate
- Trap-gate
  
第一种没用到，第二种在中断中使用，第三种在系统调用中使用。

中断门(Interrupt-gate)与陷阱门(Trap-gate)几乎一样，唯一的区别时，调用中断门时，CPU会关闭中断。而调用陷阱门时，CPU不会更改中断的开关。

- 当然了，这不是说使用中断门就不能进行中断嵌套了。只要在中断处理函数中，再打开中断即可，但是必须做好处理嵌套中断的准备。
- 为什么调用陷阱门不会更改中断开关的原因，可以看这里详细解释：https://chyyuu.gitbooks.io/ucore_os_docs/content/lab1/lab1_3_3_2_interrupt_exception.html

中断门的长度为8个字节，以下说的是中断门和陷阱门，任务门的分布不太一样。
包括：

- 中断服务函数的段选择子
- 中断服务函数的偏移
  - 以上两个属性可以确定函数的入口地址
- DPL（描述符特权级）

### 中断的特权级处理

#### 特权级检查

- 目标段的特权要高于或等于当前代码段的特权级(CPL)
  - 即用户态中发生了中断，要从用户态变到内核态
    - 如果这个中断是由用户引发的（如系统调用），则还需要检查中断门的特权必须低于CPL
      - 这个检查可以保证用户程序无法随意触发重要中断，只能触发特权等级比它低的中断（如系统调用）
      - 基于这个原因，很明显系统调用的DPL必须设置为3（用户态），才能被用户态程序调用。
  - 或者内核态中发生中断
  - 如果CPL发生改变，则需要切换堆栈。内核的堆栈信息（栈指针、栈基址）保存在TSS寄存器中。

### 中断的实现

- 中断发生后，首先将发生中断的地方eip压栈，然后从中断向量表中寻找中断服务函数
- 在ucore中，中断的服务函数定义在Vector.s中，统一都是压入错误码，再压入中断号（这是ucore自己的实现，未必要这样写），然后跳转到__alltraps函数中进行统一处理
- 在__alltraps中，继续压栈。压入ds es fs gs，然后调用Pushal，把EAX, ECX, EDX, EBX, ESP, EBP, ESI 及 EDI 顺序压入栈中
- 设置ds\es为内核的数据段
- 将此时的栈顶指针esp压栈
- 用call调用trap函数（调用call时，会自动将返回地址压如栈）
- 由于trap函数是c语言实现，因此实际上还有两句汇编（由编译器实现）
  ```asm
  pushl %ebp
  movl %esp,%ebp
  ```
- 于是，在C语言中trap函数中，调用的参数，就是ebp+8，刚好就是 调用trap之前的栈顶指针 esp，那么这有什么用处呢？trap函数的参数就是一个trapframe结构体的指针，而这个结构体的定义就是：
  ```c
  struct trapframe {
    struct pushregs tf_regs;
    uint16_t tf_gs;
    uint16_t tf_padding0;
    uint16_t tf_fs;
    uint16_t tf_padding1;
    uint16_t tf_es;
    uint16_t tf_padding2;
    uint16_t tf_ds;
    uint16_t tf_padding3;
    uint32_t tf_trapno;
    /* below here defined by x86 hardware */
    uint32_t tf_err;
    uintptr_t tf_eip;
    uint16_t tf_cs;
    uint16_t tf_padding4;
    uint32_t tf_eflags;
    /* below here only when crossing rings, such as from user to kernel */
    uintptr_t tf_esp;
    uint16_t tf_ss;
    uint16_t tf_padding5;
  } __attribute__((packed));
  ```
  刚好就是之前压栈的顺序，因此trap函数中通过操作这个tf指针，就可以操作之前压栈的这些东西，妙阿。
- 之后就是函数执行完之后，将东西出栈了，没什么好说的了。  