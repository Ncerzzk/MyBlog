---
layout: post
title: 使用TI官方元件库方法
date: 2018-04-07 18:58:11 +0800
categories: 技术 经验
issue_id: 30
---

不算什么难事，整理备忘。

步骤如下：
1. 在TI官网下载器件的封装库文件，一般是.bxl
2. 安装Ultra Librarian，打开该文件
3. 选择要导出到什么平台，因为我用的是AD，选择altium designer和3D step Model（3D模型）
4. 点击Export to Selected Tools
5. 默认会在Ultra Librarian安装目录的Librarys\Export中，用AD打开.prjscr文件，是两个脚本。运行UL_Form.pas，他会让你选择文件。选择同目录下的一个.txt文件，AD就会自动产生一个原理图库和封装库

自己动手，丰衣足食。



