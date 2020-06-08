---
layout: post
title: HDL在线综合查看RTL的一个工具
date: 2020-06-08 10:29:24 +0900
categories: 技术
issue_id: 115
---

最近在复习verilog,刷[HDLBits](https://hdlbits.01xz.net)的题，

有时候想知道两种写法综合出来的电路是不是一样的，以前都是用ISE,综合完可以直接看RTL，但是ISE太大，网上找了一圈，发现了个yosys的开源综合器，还可以生成.dot的图，于是写了个在线综合的工具，提交HDL代码，可以直接生成RTL的图

如代码：

```verilog
module top_module(clk, rst, en, count);

   input clk, rst, en;
   output reg [3:0] count;
   
   always @(posedge clk)
      if (rst)
         count <= 4'd0;
      else if (en)
         count <= count + 4'd1;

endmodule
```
可以生成


![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/rtl1.jpg
根据综合级别不同，可以生成不同的RTL图：Gate级综合

![此处输入图片的描述][2]

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/rtl2.jpg
Gate级还可以通过最后的输出，来看用了多少个门：

![此处输入图片的描述][3]

[3]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/rtl_result.jpg
目前就写了两个综合等级，实际上是通过修改yosys的.ys，修改一些综合条件来实现的


工具地址：
[hdl.huangzzk.info](http://hdl.huangzzk.info)
--
