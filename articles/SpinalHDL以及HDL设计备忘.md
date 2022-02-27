# SpinalHDL及HDL设计备忘
ctime:2022-01-23 20:17:34 +0800|1642940254

标签（空格分隔）： 技术 硬件

---

最近在用FPGA折腾一个I2C控制的PWM模块，顺便吧SpinalHDL捡起来复习了一下，两三年前学的基本忘得差不多了，重新学还花了不少时间。也踩了不少的坑，有的是因为对SpinalHDL中的一些语句认识不足造成的，有一些是由于自己逻辑没想清楚。

- `when` 中定义的信号，如果没有赋值，会被省略掉
  
```scala
class Test extends Component{
    val active =False
    val c = False

    def test=new Area{
         val reg=RegInit(False)
        reg:=True
    }
    when(active){
        test
    }
}
```

上面这段代码中，会将test这个area整个省略掉。

如果增加使用test中的信号的语句，则可以正常生成：

```scala
class Test extends Component{
    val active =False
    val c = False

    def test=new Area{
         val reg=RegInit(False)
        reg:=True
    }
    when(active){
        c:=test.reg
    }
}
```

- 接上条，被省略的信号，强行使用setName可以使其生成，但逻辑多半不会正常，具体是为什么得看SpinalHDL中作用域分析的部分了，先按下不表。

- i2c 中的读时序应该是：
  - Master 传 地址|W ,salve ACK
  - Master 传 寄存器地址 , Slave ack
  - Master Restart
  - Master 传 地址|R, Slave ack
  - Master 开始读
  
- 之前我一直记错了，一直以为是:
  - master 传 地址 | R ,slave Ack
  - master 传寄存器地址, Slave ack
  - master 开始读

- 对于I2c Probe(detect), 应该用Master 传地址|W，否则如果使用 地址|R，则此时总线的控制权已经给从机了，正常来说探测应该发完地址就发送Stop来结束的，但是由于控制权在从机那边，主机无法停止，就会导致总线卡死。
- 

  
