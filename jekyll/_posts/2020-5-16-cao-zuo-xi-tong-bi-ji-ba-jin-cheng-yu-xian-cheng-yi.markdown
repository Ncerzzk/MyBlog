---
layout: post
title: 操作系统笔记（八）进程与线程一
date: 2020-05-16 12:51:10 +0800
categories: 技术 操作系统
issue_id: 109
---

进程=程序+程序状态（上下文、寄存器、堆栈等）

## 进程三状态

- 就绪(ready)：程序已经准备好执行，只要CPU准备好马上可以执行
- 执行
- 等待（阻塞\block)：等待某个事件发生。如果事件发生，则转入就绪态

如果考虑到内存管理，还有挂起。所谓挂起就是当内存不够的时候，将目前不运行的进程的内存空间交换到外存中。

- 就绪挂起：程序已经准备好执行，只要内存足够且CPU准备好，马上可以执行
- 等待挂起：等待某个事件发生，如果发生，则转入就绪挂起态。如果内存足够，则转入挂起态。

## 进程与线程

一个进程如果有多个任务要并发执行，如果分成多个进程，那么每个进程都要维护一段内存空间，而且其中很大部分数据是重复的。
进程间的通信也要通过系统调用来实现。因此，线程应运而出，一个进程下的多个线程公用一段内存空间，这样可以访问共有数据。

线程的实现可以在用户态中实现，这样在系统调度的时候，还是将其当作一个进程处理。这种方法在早期操作系统不支持线程的时候比较常见。
如果线程在操作系统中支持，则系统调度以线程为单位，多线程的进程会分配到比较多的运行时间。

### 线程控制块(Thread Control Block|TCB)

```c
struct proc_struct {
    enum proc_state state; // Process state
    int pid; // Process ID
    int runs; // the running times of Proces
    uintptr_t kstack; // Process kernel stack
    volatile bool need_resched; // need to be rescheduled to release CPU?
    struct proc_struct *parent; // the parent process
    struct mm_struct *mm; // Process's memory management field
    struct context context; // Switch here to run process
    struct trapframe *tf; // Trap frame for current interrupt
    uintptr_t cr3; // the base addr of Page Directroy Table(PDT)
    uint32_t flags; // Process flag
    char name[PROC_NAME_LEN + 1]; // Process name
    list_entry_t list_link; // Process link list
    list_entry_t hash_link; // Process hash list
};
```

- 其中，context为上下文结构体，主要用途是保存线程调度时，当前的执行环境。也就是当前线程执行到哪儿了（eip），这样下次恢复到本进程执行的时候，可以从eip继续执行。同时，其他的寄存器也要保存。




## 进程(线程)创建执行流程

### 创建流程

- 初始化线程
  - 初始化一个临时的trapframe，调用do_fork
  ```c
  kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
    {
    struct trapframe tf;
    memset(&tf, 0, sizeof(struct trapframe));
    tf.tf_cs = KERNEL_CS;
    tf.tf_ds = tf_struct.tf_es = tf_struct.tf_ss = KERNEL_DS;
    tf.tf_regs.reg_ebx = (uint32_t)fn;
    tf.tf_regs.reg_edx = (uint32_t)arg;
    tf.tf_eip = (uint32_t)kernel_thread_entry;
    return do_fork(clone_flags | CLONE_VM, 0, &tf);
    }
  ```
- 在do_fork中
  - 分配初始化TCB
  - 分配初始化内核栈
  - 根据clone_flag标志 复制 内存管理结构（copy_mm)
  - 设置中断帧和上下文(copy_thread)
    - 前面函数中已经初始化了一个临时的中断帧，此处是在内核栈的栈顶，把那个临时中断帧复制进去。为什么要放在栈顶？为了发生中断的时候压栈时，能直接压到中断帧里去
    - 妙阿
  - 把TCB加入进程链表中
  - 将进程设置为就绪
  - 返回ID

### 执行流程

- 遍历线程链表，找到一个就绪线程，设置为next
- 保存任务状态段ts的esp0（表示内核栈的栈顶）为next的内核栈栈顶
  - 这是为了将来如果进程在用户态和内核态之间切换的时候，能知道此内核的内核栈的栈顶
- 设置cr3为next的cr3（用于页表切换，也就是将当前页表切换为next的页表）
- 调用switch_to进行上下文切换
  - swich_to实现(参数分别是from 和to两个进程的上下文结构体的地址)
  ```asm
  switch_to:                      # switch_to(from, to)

    # save from's registers
    movl 4(%esp), %eax          # eax points to from
    popl 0(%eax)                # save eip !popl
    movl %esp, 4(%eax)          # save esp::context of from
    movl %ebx, 8(%eax)          # save ebx::context of from
    movl %ecx, 12(%eax)         # save ecx::context of from
    movl %edx, 16(%eax)         # save edx::context of from
    movl %esi, 20(%eax)         # save esi::context of from
    movl %edi, 24(%eax)         # save edi::context of from
    movl %ebp, 28(%eax)         # save ebp::context of from

    # restore to's registers
    movl 4(%esp), %eax          # not 8(%esp): popped return address already
                                # eax now points to to
    movl 28(%eax), %ebp         # restore ebp::context of to
    movl 24(%eax), %edi         # restore edi::context of to
    movl 20(%eax), %esi         # restore esi::context of to
    movl 16(%eax), %edx         # restore edx::context of to
    movl 12(%eax), %ecx         # restore ecx::context of to
    movl 8(%eax), %ebx          # restore ebx::context of to
    movl 4(%eax), %esp          # restore esp::context of to

    pushl 0(%eax)               # push eip

    ret
  ```
  - 注意，当switch执行到最后调用ret时，由于之前将0(%eax)（也就是eip）压栈了，因此调用ret之后，会跳到eip的地址中进行执行。那么，此时eip指向什么地方呢？指向的是forkret函数(proc.c)
    - forkret函数实现
    ```c
    static void
    forkret(void) {
        forkrets(current->tf);
    }
    ```
    - forkrets函数是一个汇编实现的函数，因此编译器不会再自己增加那两句汇编代码
        ```asm
        pushl %ebp
         movl %esp,%eb
        ```
    - forkrets函数实现
    ```asm
    forkrets:
    # set stack to this new process's trapframe
    movl 4(%esp), %esp
    jmp __trapret
    ```
    此时esp+4的指向的内存地址保存的值就是current->tf，也就是中断帧（还记得么，保存在内核栈栈顶的那个）
  - 好了，接下来就是__trapret
    ```asm
    __trapret:
    # restore registers from stack
    popal

    # restore %ds, %es, %fs and %gs
    popl %gs
    popl %fs
    popl %es
    popl %ds

    # get rid of the trap number and error code
    addl $0x8, %esp
    iret
    ```
    - 在这里将保存在中断帧里的信息恢复，最后那两句，esp+=8，为了跳过中断帧的错误码和中断号，因为此处这两个值没用。跳过之后，esp指向的，就是中断帧中的eip字段。于是调用iret，跳到eip指向的地方。
      - eip指向哪里呢，就是在创建进程时候写的，     kernel_thread_entry。
      ```asm
        kernel_thread_entry: # void kernel_thread(void)
        pushl %edx # push arg
        call *%ebx # call fn
        pushl %eax # save the return value of fn(arg)
        call do_exit # call do_exit to terminate current thread
      ```
    - 最终，总算跳到线程真正要执行的函数fn里去了。
   