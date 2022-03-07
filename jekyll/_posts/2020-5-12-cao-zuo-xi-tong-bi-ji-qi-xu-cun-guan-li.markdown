---
layout: post
title: 操作系统笔记（七）虚存管理
date: 2020-05-12 17:37:32 +0800
categories: 技术 操作系统
issue_id: 107
---

虚拟内存管理的目标是使在物理内存不足的情况下，运行尽量多的程序。

方法使使用页置换机制，将暂时不用的页写到硬盘上，等到需要访问某个页而不在内存中时，再将其读入。

需要考虑几个问题：

- 如何决定哪些页被换出？
  - FIFO
  - 时钟算法
    - 一定时间内未访问过的页面换出
  - 增强时钟算法
    - 统计一定时间内访问页面的访问次数
- 何时换入换出？
  - 缺页时换入换出
  - 定时换出，缺页换入


有几个小问题：

- 前面的文章中提到了，ucore在bootloader里面建立了初始的页映射，实际上只建立了页目录表（一级页表），二级页表的页表项都是0。是在用到的时候，才去建立的映射。
  - 什么时候用到呢？具体到本次的实验(lab3)，访问某个地址后，第一次肯定是缺页异常，于是在缺页异常中分配物理页。
- 本实验是要做页的换入换出，那么它是如何设置要分配的物理页数量（比如限制物理页一共只有5页，毕竟如果整个内存有876MB，页的数量非常多，如果用来做的页的换入换出测试，很不直观）
  - 首先构建了一个虚拟内存管理器，用结构体mm_struct来管理
    ```c
    struct mm_struct {
    // linear list link which sorted by start addr of vma
    list_entry_t mmap_list;
    // current accessed vma, used for speed purpose
    struct vma_struct *mmap_cache;
    pde_t *pgdir; // the PDT of these vma
    int map_count; // the count of these vma
    void *sm_priv; // the private data for swap manager   此字段用来按顺序保存分配的物理页（fifo分配算法中用到）
    };
    ```
  - 构建虚拟地址空间，用结构体vma_struct管理
    ```c
    struct vma_struct {
    // the set of vma using the same PDT
    struct mm_struct *vm_mm;
    uintptr_t vm_start; // start addr of vma
    uintptr_t vm_end; // end addr of vma
    uint32_t vm_flags; // flags of vma
    //linear list link which sorted by start addr of vma
    list_entry_t list_link;
    };
    ```
  - 在测试函数中，先分配了n页，然后将nr_free(表示空闲页数的变量)改成了0，然后再将之前分配了的free掉，这样就有n页的空闲页了，接下来用这n个空闲页进行页的换入换出
  - 页的换出操作是在alloc_page中实现的，当要分配的页数超过空闲页时，就会返回NULL,外面函数捕捉到NULL后，就开始换出
  