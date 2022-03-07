---
layout: post
title: 操作系统笔记（二）Bootload加载ELF文件
date: 2020-04-29 14:34:46 +0800
categories: 技术 操作系统
issue_id: 103
---

## 练习4 分析bootloader如何加载ELF文件

- 上一步，进入保护模式之后，跳转到此处，开始引导启动系统
- 首先从硬盘中，读入一定数量的数据(ELF文件，也就是系统镜像)(512字节*8，相当于读入8个扇区的内容)，放在ELFHDR处
  - `readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);`
  - 读完需要校验以下读入的是不是ELF文件，通过检查e_magic字段

ELFHDR的地址是 0x10000，仅仅是一个暂存地址。

ELF文件的文件头格式:

```c
struct elfhdr {
  uint magic;  // must equal ELF_MAGIC
  uchar elf[12];
  ushort type;
  ushort machine;
  uint version;
  uint entry;  // 程序入口的虚拟地址
  uint phoff;  // program header 表的位置偏移
  uint shoff;
  uint flags;
  ushort ehsize;
  ushort phentsize;
  ushort phnum; //program header表中的入口数目
  ushort shentsize;
  ushort shnum;
  ushort shstrndx;
};
```

一个ELF文件中分为好几个段，程序段、数据段等，每个数据段的定义：

```c
struct proghdr {
  uint type;   // 段类型
  uint offset;  // 段相对文件头的偏移值
  uint va;     // 段的第一个字节将被放到内存中的虚拟地址
  uint pa;
  uint filesz;
  uint memsz;  // 段在内存映像中占用的字节数
  uint flags;
  uint align;
};
```

通过ELF文件头中的phoff，可以找到第一个段描述的地址，而phnum提供了段的数量，因此通过遍历就可以获得所有的段的信息。

接下来把每个段给读出来，每个段要放在什么位置由每个段的va字段来决定。

```c
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    eph = ph + ELFHDR->e_phnum;
    for (; ph < eph; ph ++) {
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    }
```

数据复制完成后，跳转到程序的入口点执行。

```c
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();
```

程序的入口点e_entry由链接文件中设定。





