# 无中生有制作img文件
ctime:2022-04-13 21:44:27 +0800|1649857467

标签（空格分隔）： 技术 硬件

---

制作嵌入式linux的镜像文件，有一种办法是直接在SD卡上操作，另一种是直接采用文件的方式，通过loop设备模拟，进行挂载。
实际上区别不是很大，用loop模拟主要是多了几步，这里介绍用loop模拟的方式。

### 制作img文件

`dd if=/dev/zero of=test.img bs=1M count=512`

### 挂载到loop设备

`losetup /dev/loop0 test.img` 

需要使用空闲的`/dev/loop` 设备，可以使用`losetup -f` 来找

### 分区

`fdisk /dev/loopN`

fdisk 里面提示挺完善的，直接按照提示做就行了。一般需要两个分区，一个作为boot，一个放rootfs。
保存退出后，使用`partprobe /dev/loopN` 来使分区生效。

生效后应该会产生`/dev/loopNp1` 和 `/dev/loopNp2` 

### 格式化

`mkfs.fat -F 16 /dev/loopNp1`

`mkfs.ext4 /dev/loopNp2`

格式化之后，就可以挂载到文件系统上，然后把内核什么复制进去了。

### 制作rootfs

`mount /dev/loopNp1 boot`

`mount /dev/loopNp2 rootfs`


