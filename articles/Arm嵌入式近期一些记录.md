# Arm嵌入式近期一些记录
ctime:2019-03-07 21:57:09 +0800|1551967029

标签（空格分隔）： 日记 技术 硬件 arm

---

这几天在看ARM相关的东西，实际上上学期已经看了一些了，但是只看了arm架构原理部分，现在已经差不多都忘了，幸好当时做了笔记，拿起来还能回忆一些。

最近看的是关于内核、U-boot、bootload、根文件系统，这些东西早有耳闻，但一直不知道相互之间的关系是什么，看了几天总算有点明白了。

### 根文件系统
根文件系统实际上是linux下，/ /ext /var这些东西，同时还包含一些软件，如有的根文件系统（debian系）的，会有apt-get，以及一些工具链，如GCC灯。构建根文件系统实际上就是建立这些/ext的目录，然后将软件如gcc等拷贝过去。

### 内核
linux内核，这个就不用多说了。

### uboot、bootload
uboot实际上是一种bootload，类似于PC上的BIOS，用于引导系统。uboot由于其强大的通用性（支持各种架构，包括arm mips 甚至x86啥的），已经成为arm bootload的事实标准。

uboot启动过程包括关中断、设置时钟，设置外设（如串口、LCD）等等，然后从文件系统中把内核读出来，加载到内存，并跳到内核的起点开始执行。

在使用荔枝派测试烧写uboot的时候，一开始烧完总是没反应，后来才发现应该从SD卡的8k位置开始烧写。因为全志的启动卡分区表采用的是MBR分区表。（http://linux-sunxi.org/Bootable_SD_card）（https://blog.csdn.net/rikeyone/article/details/52044225）

start size usage

- 0 8KB Unused, available for partition table etc. 
- 8 24KB Initial SPL loader 
- 32 512KB U-Boot 
- 544 128KB environment 
- 672 352KB reserved 
- 1024 - Free for partitions

在CSDN的文中，他8k位置烧写的是spl，然后再32k位置烧写的uboot。我按照荔枝派的教程，uboot编译完后，直接烧到8k。我猜测按照荔枝派教程的编译完后，实际上包括spl和uboot了，从文件名也可以看出一二：u-boot-sunxi-with-spl.bin ，不过不确定，待之后确认。








