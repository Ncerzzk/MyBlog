# verilog中if和case优先级的问题
ctime:2020-07-02 19:38:16 +0900|1593686296

标签（空格分隔）： 技术 硬件

---

看以下两段代码，实现的功能应该是一样的：

### IF(noelse)
（为什么不写else呢，因为很多时候，下面这种代码是用for循环生成出来的，不好写else）
```c
module top_module( input a,input b,input [1:0] sel, output out );
    always @ (*) begin
        out<=1'b00;
        if(sel==2'b00)
            out <= a&b;
        if(sel==2'b01)
            out<= a|b;
        if(sel==2'b10)
            out<= a^b;
        if(sel==2'b11)
            out<= ~a&b;
    end
endmodule
```
生成的RTL图：

![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/ifnoelse.jpg

### IF（带else)
注意，此处最后是else if ，而不是else。注意比较和下面的差别
```c
module top_module( input a,input b,input [1:0] sel, output out );
    always @ (*) begin
        out<=1'b00;
        if(sel==2'b00)
            out <= a&b;
        else if(sel==2'b01)
            out<= a|b;
        else if(sel==2'b10)
            out<= a^b;
        else if(sel==2'b11)
            out<= ~a&b;
    end
endmodule
```
![此处输入图片的描述][2]

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/ifcase.jpg

### IF（带else)2

```c
module top_module( input a,input b,input [1:0] sel, output out );
    always @ (*) begin
        out<=1'b00;
        if(sel==2'b00)
            out <= a&b;
        else if(sel==2'b01)
            out<= a|b;
        else if(sel==2'b10)
            out<= a^b;
        else
            out<= ~a&b;
    end
endmodule
```
![此处输入图片的描述][4]

[4]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/case2.jpg

### case

```c
module top_module( input a,input b,input [1:0] sel, output out );
    always @ (*) begin
        out<=1'b00;
		case(sel)
		2'b00:out<=a&b;
		2'b01:out<=a|b;
		2'b10:out<=a^b;
		2'b11:out<=~a|b;
        endcase

    end
endmodule
```

![此处输入图片的描述][3]

[3]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/case.jpg

可以看到IF 和CASE生成的RTL有较大差别，IF明显是串行电路，那么就会有比较大的延迟。

然而在网上又看到了一些讨论，说：虽然RTL图有较大区别，但由于FPGA是用LUT实现的，最后综合的结果反而会是一样的。
因为目前我手头也没FPGA的软件，就不验证了。总之，不管最后综合器会不会帮我们优化，尽量写成case还是比较重要的。



