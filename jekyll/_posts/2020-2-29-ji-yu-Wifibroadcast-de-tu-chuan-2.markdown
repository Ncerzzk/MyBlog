---
layout: post
title: 基于Wifibroadcast的图传2
date: 2020-02-29 17:48:26 +0800
categories: 技术 兴趣
issue_id: 83
---

今天又研究了一下，本来想从国内买两个树莓派寄过来的，在咸鱼上搜的时候突然发现已经有人做出来再买了，突然兴致不高。直接按照人家的教程做出来去卖有啥意思呢。

把今天研究的总结一下吧。

前面说的不支持monitor 模式和frame injection，主要是两个原因，一个是硬件上不支持，如手机上或者其他什么设备，为了低功耗，不支持用户自定义底层MAC相关的东西，这种芯片组称为：FullMac，与之相反的是softMAC。

参考地址：
- http://www.aircrack-ng.org/doku.php?id=install_drivers

另一个原因是驱动不支持。因为正常用户使用是不需要monitor模式和frame injection的，所以大部分厂商也就没写这部分的驱动。另外，特别说到windows不支持injection，并说这是固有限制。

Linux下需要可以通过打一些补丁patch来启用这些功能，也可以使用Kali Linux或者Pentoo 这些发行版，据说已经打好了补丁。查了一下Kali linux，主要是用来做安全、渗透测试的，所以打了这些补丁也不奇怪。

参考地址：
- http://www.aircrack-ng.org/doku.php?id=compatible_cards
- https://wireless.wiki.kernel.org/en/users/documentation
  

另外，虽说kali Linux已经打好了补丁，但是我搜到了一篇Raspberry zero W，使用kali linux的文章，里面它还得另外打一些补丁来启用板载wifi的这两个功能。那么可能上面说的一般的kali linux打的补丁是针对一般的网卡的，树莓派板载网卡可能比较小众。

参考地址：
- http://stuffjasondoes.com/2018/07/18/kali-linux-2017-3-on-a-raspberry-pi-zero-w/
  
树莓派网卡的补丁：（主要支持博通的wifi芯片）
- https://github.com/seemoo-lab/nexmon


关于网卡的一些工作模式：
- https://blog.csdn.net/weixin_30432579/article/details/99553172?depth_1-utm_source=distribute.pc_relevant.none-task&utm_source=distribute.pc_relevant.none-task
- 



