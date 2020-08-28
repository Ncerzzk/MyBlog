---
layout: post
title: 操作系统笔记（五）内存管理_临时页表建立
date: 2020-05-06 12:00:21 +0800
categories: 技术 操作系统
issue_id: 105
---

## 执行流程

- BIOS入口，然后进入到bootloader
- bootloader中探测物理内存大小，临时建立段映射、页映射，调用kern_init
- 以页划分空间，设定每页的可用状态
- 建立页表，将（部分）页表读入MMU的TLB（快表）中

## 检测物理内存的方式

```asm
probe_memory:
    movl $0, 0x8000             # 0x8000是地址范围描述符的地址,0x8000保存的是nr_map，是地址描述符的个数。
    xorl %ebx, %ebx
    movw $0x8004, %di           # 0x8004是第一个地址范围描述符
start_probe:
    movl $0xE820, %eax          # int15中断的参数
    movl $20, %ecx              # 一个地址范围描述符的大小(20字节)
    movl $SMAP, %edx            # 中断参数
    int $0x15                   # 调用中断，如果成功，则cf不置位，否则cf=1
                                # 调用成功后，会往es:di的地址，写入地址描述符，分别是 基址(8字节) 大小(8字节) 内存类型(4字节)    
    jnc cont                    # 检查cf，等于0跳转
    movw $12345, 0x8000
    jmp finish_probe
cont:
    addw $20, %di               # di递增，指向下一个地址描述符
    incl 0x8000                 # 地址描述符个数增加
    cmpl $0, %ebx               # 中断调用成功，ebx保存上次调用的计数值。如果ebx为0则扫描完毕 
    jnz start_probe
finish_probe:
    # 建立全局段表，进入保护模式
    lgdt gdtdesc
    movl %cr0, %eax
    orl $CR0_PE_ON, %eax
    movl %eax, %cr0
```

## 临时页映射（段映射前面的文章讲过了）

```asm
kern_entry:     # 内核的入口点，bootloader读取完毕后，跳到此处
    # load pa of boot pgdir
    movl $REALLOC(__boot_pgdir), %eax   # 这里使用的是物理地址，因为页表映射还没开 
    movl %eax, %cr3                     # 将临时页表，存到cr3中。
                                        # CR3中含有页目录表物理内存基地址，因此该寄存器也被称为页目录基地址寄存器PDBR（Page-Directory Base address Register）

    # enable paging
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0

    # 开启页映射了，但此时内核还是运行在0-4M的地址上（因为EIP还在这个范围中）
    # 但内核要运行的虚拟地址应该是在 KERNBASE~KERNBASE+4M这个范围 中
    # 下面，更新eip，将其跳转到高虚拟地址中

    # update eip
    # now, eip = 0x1.....
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
```

临时的页表映射关系：
```asm
.section .data.pgdir
.align PGSIZE
__boot_pgdir:
.globl __boot_pgdir
    # 这是两级页表
    # boot_pgdir是页目录表（一级页表），页表目录必须是4KB（一页的大小），即使只有一项
    # 下面是把虚拟地址为 0-4M 和KERNBASE + (0 ~ 4M)  映射到物理地址的0-4M上
    # 两句.space 是为了填充
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # pad to PDE of KERNBASE
    # map va KERNBASE + (0 ~ 4M) to pa 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # pad to PGSIZE

.set i, 0
__boot_pt1:
    # 二极页表，最多1024项，一项4字节
.rept 1024
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr
```

几个需要注意的地址：
- 0xC0100000 程序的起始地址，可从链接文件中获取
  
     ```ASM
    SECTIONS {
    /* Load the kernel at this address: "." means the current address */
    . = 0xC0100000;

    .text : {
        *(.text .stub .text.* .gnu.linkonce.t.*)
    }
    ...
    ```
    - 此地址是一个虚地址，决定了bootloader将内核加载到哪个内存地址上。需要注意的是，由于内核加载的时候，页表映射还没开，虚拟地址=物理地址。我们从上文的分析中可以知道，0xC0000000以后的4M虚拟地址实际上映射到了0-4M的物理地址上。因此在加载的时候，内核手动做了一个映射，直接将地址&上0xFFFFFF(7个F)。
    - 需要注意的，程序的其他地址都是相对于这个地址进行编址的
- 程序入口地址：ENTRY(kern_entry)。具体是多少，不清楚。
  - 此地址决定了bootloader搬完内核之后，跳转到哪里继续执行。
- KERNBASE            0xC000000
  - 此地址与程序的起始地址相关联，决定了高虚拟地址的映射关系。