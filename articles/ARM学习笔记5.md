# ARM学习笔记5——Flash、MMU

ctime:2020-04-18 18:50:32 +0900|1587203432

标签（空格分隔）： 技术 arm

---

## FLASH

### NOR Flash

- 可以随机读写（像内存一样，意味着可以执行代码）
- 有专门的地址线 数据线

### NAND Flash

- 没有专门的地址线 数据线，发送指令、数据、地址都使用总线
- 擦除、写入速度比NOR flash快
 
一般来说，由于NOR FLASH可以执行代码，因此常用来作为BIOS等用途。

在STM32中，内置FLSAH应该也是NOR FLASH。

因为其在启动文件中，有一段汇编代码是将bin中data段（也就是代码部分）复制到内存中执行，而
这段汇编代码显然是在FLASH中执行的。

```asm
  movs r1, #0
  b LoopCopyDataInit

CopyDataInit:
  ldr r3, =_sidata
  ldr r3, [r3, r1]
  str r3, [r0, r1]
  adds r1, r1, #4

LoopCopyDataInit:     /* 复制bin文件中data段的数据到内存 */
  ldr r0, =_sdata
  ldr r3, =_edata
  adds r2, r0, r1
  cmp r2, r3
  bcc CopyDataInit
  ldr r2, =_sbss
  b LoopFillZerobss
```

那么，如果不复制是否可以呢？

其实可以，但是在内存中的执行速度越高与NOR FLash 中，因此为什么不呢？


## MMU（内存管理单元）

对于32位的CPU而言，寻址空间为0-0xFFFF FFFF(4GB)。而实际的器件内存可能只有1GB。

通过MMU，可以将虚拟内存地址映射到物理内存地址，可能有多个虚拟内存地址映射到同一块物理内存，也可能有
虚拟内存地址并没有映射到物理内存上（等用到的时候再分配）

### MVA VA PA

VA:Virtual Address
MVA:Modified Virtual Address
PA:Physical Address

对于CPU而言，它发出的都是VA（当然了，得在MMU启动之后，在MMU启动之前，CPU操作的都是物理地址）
在VA转化为PA之前，它会先转化为MVA（硬件自动完成）（MMU只能看得见MVA）

在arm9中，VA转为MVA的算法为：

- 如果VA小于32M，则会 `VA|（PID<<25)`
- 如果VA大于32M，则`MVA=VA`
  
用这种方式，可以加快切换进程的速度，这样两个进程假设VA都是0，但由于进程PID不同则MVA也不同，映射的物理地址也不同。

这里有个问题，为什么是32M（2^25)，是因为这里取了PID的低7位来参与运算，如果只取PID的低4位，那么就是256M(2^28)了。

