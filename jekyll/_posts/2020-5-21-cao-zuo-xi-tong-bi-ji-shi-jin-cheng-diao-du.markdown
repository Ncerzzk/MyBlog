---
layout: post
title: 操作系统笔记（十）进程调度
date: 2020-05-21 19:39:48 +0800
categories: 技术 操作系统
issue_id: 111
---

进程执行的任务大致可以分为CPU计算任务和IO任务。基本上所有进程都会有这两种任务，
由于执行IO任务的时候，比如像设备索要数据，此时CPU就处于待机状态。因此在待机期间，就可以切换到另一个进程进行执行。

## 调度时机

- 进程主动放弃CPU
  - 当前执行的进程转为阻塞状态
  - 当前执行的进程退出
- 中断（如定时中断）
  
## 调度算法

### 非抢占调度：进程一直运行，直到发生某个事件使进程进入阻塞状态（Block）

- 先来先服务：队列算法，这个就比较简单了。
- 短进程优先：按执行时间排序，执行时间短的进程放前面
  - 这里的执行时间短，指的是进程的某一段CPU计算任务时间短
  - 会出现饥饿现象：短进程不断出现，导致长进程无法执行
  - 需要估计程序的执行时间，通过过去的时间来拟合估计未来的时间
- 最高相应比优先：是短进程优先的改进，为了解决饥饿现象
  - 响应比计算：（等待时间+执行时间）/执行时间，这样的话，只要等的时间足够长，响应比一定足够高可以获得CPU调度

### 抢占调度
- 时间片轮转
- 多级反馈


## 优先级反置问题

约定：优先级越低的进程可被高优先级进程抢占。

考虑这么一种情况，进程1 优先级为1，此时正在执行。占用共有资源s。

进程3 优先级为3，也申请资源s。

这场情况下，应该是进程3等待进程1释放s，然后进程3转为就绪。

如果此时来了个进程2，优先级为2，2将进程1打断，于是进程1无法执行，也就无法释放资源。进程3只能一直等待，等到猴年马月进程1释放资源。

因此优先级反置就是指 高优先级进程 长时间等待低优先级进程占用资源的现象。

### 解决方式

优先级提升，一旦进程3也申请了资源s，那么此时占用这个资源的进程的优先级，就提升到进程3的优先级。这样可以保证他尽快释放。

### Stride 调度

主要属性：

- stride：距离
- pass：步长

每次调度从进程列表中找到stride值最小的进程，让其运行，每次运行stride增加一个步长的距离。

因此步长越少的进程可以获得更多次的调用，因此进程优先级越高，则步长越小。

数据结构可以采用队列，查找的时间复杂度为O(n)，增加和删除的复杂度都为O(1)
也可以采用堆，增加复杂度为O(logn)，查找和删除的复杂度为O(1)，因此用堆更好一点。




