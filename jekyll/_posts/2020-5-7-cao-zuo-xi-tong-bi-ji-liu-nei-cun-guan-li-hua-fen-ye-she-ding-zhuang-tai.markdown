---
layout: post
title: 操作系统笔记（六）内存管理_划分页、设定状态
date: 2020-05-07 16:39:27 +0800
categories: 技术 操作系统
issue_id: 106
---

在bootloader中进行建立临时页表、开启页映射、以虚拟地址开始运行程序后，跳转到了内核的初始化函数kern_init中。

## pmm_init

干的事主要有：
- init_pmm_manager();
- page_init();
  ```c
    static void
    page_init(void) {
        struct e820map *memmap = (struct e820map *)(0x8000 + KERNBASE);
        uint64_t maxpa = 0;

        cprintf("e820map:\n");
        int i;
        for (i = 0; i < memmap->nr_map; i ++) {
            uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
            cprintf("  memory: %08llx, [%08llx, %08llx], type = %d.\n",
                    memmap->map[i].size, begin, end - 1, memmap->map[i].type);
            if (memmap->map[i].type == E820_ARM) {
                if (maxpa < end && begin < KMEMSIZE) {
                    maxpa = end;
                }
            }
        }
        if (maxpa > KMEMSIZE) {
            maxpa = KMEMSIZE;
        }

        // 以上代码作用是找到最大地址

        extern char end[];  // 这是一个全局变量，end保存的是ucore的结束地址

        npage = maxpa / PGSIZE;
        pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);  // 从ucore的结束地址之后，开始存放页的管理结构体(Page)

        for (i = 0; i < npage; i ++) {
            SetPageReserved(pages + i);   // 将所有的内存空间标记为占用
        }

        uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * npage);

        for (i = 0; i < memmap->nr_map; i ++) {
            uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
            if (memmap->map[i].type == E820_ARM) {
                if (begin < freemem) {
                    begin = freemem;
                }
                if (end > KMEMSIZE) {
                    end = KMEMSIZE;
                }
                if (begin < end) {
                    begin = ROUNDUP(begin, PGSIZE);
                    end = ROUNDDOWN(end, PGSIZE);
                    if (begin < end) {
                        init_memmap(pa2page(begin), (end - begin) / PGSIZE);  
                        // 将876MB内的空闲空间（扣除内核所占空间）添加到链表中，用来分配
                        // 并将空闲空间设置为空闲
                    }
                }
            }
        }
    }
    ```
  - 这里有一个值需要注意，为什么是896MB。
    - 简单来说，x86最大支持4G的寻址范围，其中分配了1G(1024MB)给内核使用，其地址范围是3G-4G。在上面我们也发现了，其通过页映射机制，将3G-4G映射到0-1G中了。
    - 但即使这样，内核也只能寻址到1G的空间，物理内存中的其他部分就访问不了了。那怎么办？于是就在1G的空间中分出了128MB，用来建立动态映射。假设需要访问到2G开始的1MB的内存空间，那么只要在这128MB中，找到1MB的地址范围，将其映射到2G~2G+1MB这一部分物理内存即可。在访问结束后，归还这部分空间。
    - 于是，内核的最大大小就是1G-128MB=896MB了
    - 具体参考：http://ilinuxkernel.com/?p=1013
    - 因此，在ucore中，为了简单起见，它只支持896MB的物理内存空间

### 页表映射

#### 练习1：通过设置页表和对应的页表项，可建立虚拟内存地址和物理内存地址的对应关系。其中的get_pte函数是设置页表项环节中的一个重要步骤。此函数找到一个虚地址对应的二级页表项的内核虚地址，如果此二级页表项不存在，则分配一个包含此项的二级页表。

实现get_pte函数：
```c
pte_t *
get_pte(pde_t *pgdir, uintptr_t la, bool create) {
    pde_t *page_t=&pgdir[PDX(la)];
    struct Page * newpage;
    uint32_t pa;
    if(!(*page_t & PTE_P)){ // 判断二级页表是不是存在
        if(create && (newpage=alloc_page())!=NULL){
            // 分配一页来作为二级页表  
            set_page_ref(newpage,1);
            pa=page2pa(newpage);
            memset(KADDR(pa),0,PGSIZE); // 清空新页
            *page_t=pa|PTE_P|PTE_W|PTE_U; // 将新的二级页表写入页目录表（一级页表）中
        }else{
            return NULL;
        }
    }
    return (pte_t *)KADDR(PDE_ADDR((*page_t)))+PTX(la);
}
```

#### 练习2：实现page_remove_pte

```c
static inline void
page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep) {
    if(*ptep & PTE_P){ // 判断pte是不是有效
        struct Page *page=pte2page(*ptep);
        page_ref_dec(page);  // 减少引用
        if(page->ref==0){   // 如果引用次数已经为0，则释放
           free_page(page);
        }
    }
    tlb_invalidate(pgdir,la);  // 因为对二级页表进行了改动，所以快表（TLB）需要重建，使原来的快表失效。
}
```

