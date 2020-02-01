---
layout: post
title: 不带__weak 标志的函数（Strong函数）无法代替weak函数的问题
date: 2019-12-08 12:24:17 +0900
categories: 技术 编程
---

在C编程中，有时候需要写一些weak函数，用来给用户进行覆盖。

之前写NRF的函数的时候，写了一个__weak void NRF_Receive_Callback(uint8_t * data,int len);

用来给用户重载接收回调函数。然后我在main中，重新写了一个NRF_Receive_Callback，在IAR中编译、工作正常，NRF接收到
数据之后，会调用main中的callback。然而我用arm gcc编译之后，却发现不行，调用的还是原来的weak函数。在网上搜了半天，
有一篇文章说到：

> 多次试验和搜索，应该就是静态库的函数只有在要被用到的时候，才会被link，但weak symbol相对比较特殊，会先link到weak的function，然后再去找strong的function。因此strong的function实现在静态库里面，并且对应.o里函数也没被其他.o call 到，整个静态库都不会被link进去，因此最后只会选weak function。
> 
>应对的方式
>
>A：利用—whole-archive和—no-whole-archive强制静态库被link进去，这样strong函数一定会被收到。缺点是如果lib之间有同名function会打出build error
>
>B：和A类似，利用link选项-u强制某个function被link，但lib和function较多时不好用
>
>作者：612F
>
>链接：https://www.jianshu.com/p/be55f46b0e5e
>
>来源：简书
>
>著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

想了一下确实是，main中的函数都没被其他文件调用，都是他调用别人。

因为对makefile不太熟，我没去修改makefile的编译 链接选项了，直接把回调写到其他文件中，如control.c，测试正常，果然是这个问题。



