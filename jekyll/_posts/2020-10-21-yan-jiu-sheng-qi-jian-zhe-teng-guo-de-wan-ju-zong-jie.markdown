---
layout: post
title: 研究生期间折腾过的玩具总结
date: 2020-10-21 15:02:47 +0800
categories: 技术 硬件
issue_id: 141
---


北邮做硬件的人实在太少了，平时基本上也只是自己在玩，一直想找找有没有对DIY飞行器阿这些奇怪东西感兴趣的组织，但没有找到。马上就要毕业了，
在这里总结一下这几年玩过的一些项目吧，大部分都没有做完，如果有学弟学妹想做一些这方面的大创，或许可以找到一些灵感。

## 纸飞机

一个带动力的纸飞机，由空心杯电机驱动，由两个微型舵机控制舵面。
![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/zhifeiji.jpg
![此处输入图片的描述][2]

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/zhifeiji2.jpg

这个算是完成度最高的一个项目了吧，飞机已经基本能飞了，某年春节的时候带回家了，想抽空调调，结果被亲戚家的小朋友把电源插反了。后面一直没时间修，就逐渐坑了。
基本没啥用的项目，唯一一个用处就是好玩。飞翼布局飞机的控制算法还挺有意思的。

衍生项目：
- MiniFlyControl:https://github.com/Ncerzzk/Mini_FlyControl
- 遥控器：https://github.com/Ncerzzk/RemoteControl
 

## 三轴/两轴云台

本来想装在飞机上的，想着DJI能做到，自己DIY应该也能做到，至多就是体积没办法做到那么小罢了。网上开源的云台如SimpleBGC等，一般都不带编码器，导致电机效率不高，发热量较高。找同学设计了结构，为了方便调试，现在已经拆得只剩下一个电机了。

![此处输入图片的描述][3]

[3]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/yuntai.jpg

衍生项目：
- FOC无刷电机驱动器：https://github.com/Ncerzzk/Brushless_Driver_Nosensor
- 如何使用无刷电机播放音乐：https://www.bilibili.com/video/BV1x7411x7gB

## 双旋翼无人机

灵感来自于DJI原大佬YY硕的一篇文章：https://zhuanlan.zhihu.com/p/35862380，采用两个舵机，直接旋转两个桨盘来改变升力的大小。YY硕文章中忽略了Y轴俯仰力矩，想用其他工程方式来解决该结构无法提供俯仰力矩的问题，在评论中及其他论文论证了，只要飞机的重心低于舵机的旋转中心，还是可以以此获取一个可靠的俯仰力矩的。因此选用这个题目来作为我的毕设，可惜后来由于种种原因改成其他题目了（在延毕的边缘疯狂试探），也就没有继续往下做了。

![此处输入图片的描述][4]

[4]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/shuangxuanyi.jpg
![此处输入图片的描述][5]

[5]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/shuangxuanyi1.jpg

衍生项目：

- 无人机力学仿真：https://github.com/Ncerzzk/UAV_Sim（恰逢哈工大被禁用matlab的消息传出，想试试不用matlab，纯手撸能不能做点仿真工作）

## 某奇怪的直升机

一直以来都想玩玩直升机，但是由于直升机的倾斜器结构太复杂了，已经超出我掌握的幼儿园机械知识了。后来从油管上一些视频得到了灵感，设计了这么一个倾斜器。

![此处输入图片的描述][6]

[6]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/zhishengji.jpg

直接使用两个舵机拉动连杆，使整个电机发生倾斜，从而使整个螺旋桨的桨盘整体发生改变，从而改变升力的方向。至于电机反扭距，在尾巴再装个小电机就行了。

![此处输入图片的描述][7]

[7]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/zhishengji.gif

在围攻里测试过，机构还是达到目的的。
由于后面忙着某个项目的答辩，最终也坑了，也懒得再重新捡起来。感觉应该是能飞的。

## 图传

航模界用的图传很多都是模拟图传，主要是比较便宜，延迟低。数字图传一般来说都很贵（除非那种玩具用的WIFI图传）。因此有一段时间一直想给我的飞机折腾个图传（虽然各种飞机都没怎么飞起来呢），后来找到了一个开源项目：Wifibroadcast。

一般便宜的WIFI图传都是直接运行在AP模式，连上之后直接用TCP或者UDP协议来传数据。缺点在于这种方式需要接收机和发送机之间保持WIFI连接，断开重连延迟贼高，体验不好。

这个项目让网卡运行在Inject模式和monitor模式，二者无需建立连接，因此延迟可以达到一个较低的水平。(100ms左右)作者的演讲可以在这里找到:https://media.ccc.de/v/36c3-10630-wifibroadcast
但由于这个项目支持的最小硬件为树莓派Zero，对于一个微型的无人机来说，还是大了一点。因此想自己将其移植自己画的一个小板子上，去掉多余的接口。芯片采用全志的V3s，自带编解码，只需要画上摄像头接口和网卡接口就行了。

不过由于对linux网络编程和Linux下的驱动编写不熟，因此这个项目也是一直停留在有生之年计划中。









