
ctime:2022-05-01 19:21:55 +0800|1651404115
# SpinalHDL_I2C实现分析

标签（空格分隔）： 技术

---

最近想通过FPGA实现一个PWM设备，通过I2C控制。本来想着自己实现I2C Slave接口，但是写了一下发现很别扭，
I2C的时序已经算简单的了，但是真的写起来，才发现问题很多。

找了一下发现Spinalhdl本来就实现了一个I2C的接口，包含从机功能，但写得比较复杂，粗看完全看不懂，因此打算最近沉下心好好分析一下人家到底是怎么实现的。

[toc]

首先先来看一下Slave 主模块的实现

## IO部分

首先是IO部分
```scala
  val io = I2cSlaveIo(g)
```

### I2cSlaveIo 

使用I2CSlaveIO类将IO部分封装了起来，去看看这个类：

```scala
case class I2cSlaveIo(g: I2cSlaveGenerics) extends Bundle {

  val i2c    = master(I2c())
  val config = in(I2cSlaveConfig(g))
  val bus    = master(I2cSlaveBus())

  val internals = out(new Bundle {
    val inFrame = Bool()
    val sdaRead, sclRead = Bool()
  })

  def driveFrom(busCtrl: BusSlaveFactory, baseAddress: BigInt)(generics: I2cSlaveMemoryMappedGenerics) = {
    I2cCtrl.driveI2cSlaveIo(this, busCtrl, baseAddress)(generics)
  }
}
```

#### I2c

```scala
case class I2c() extends Bundle with IMasterSlave {

  val sda   = ReadableOpenDrain(Bool)
  val scl   = ReadableOpenDrain(Bool)

  override def asMaster(): Unit = {
    master(scl)
    master(sda)
  }

  override def asSlave(): Unit = {
    slave(scl)
    slave(sda)
  }
}
```

这个类就不继续往下看了，ReadableOpenDrain是spinalhdl中用来封装inout的一个工具，在顶层可以使用`InOutWrapper`将其转换为inout类型。

#### I2cSlaveConfig
这个类是个运行时配置接口，配置的几个参数如下
```scala
case class I2cSlaveConfig(g: I2cSlaveGenerics) extends Bundle {

  val samplingClockDivider = UInt(g.samplingClockDividerWidth)
  val timeout              = UInt(g.timeoutWidth)
  val tsuData              = UInt(g.tsuDataWidth)


  def setFrequencySampling(frequencySampling: HertzNumber, clkFrequency: HertzNumber = ClockDomain.current.frequency.getValue): Unit = {
    samplingClockDivider := (clkFrequency / frequencySampling).toInt
  }

  def setTimeoutPeriod(period: TimeNumber, clkFrequency: HertzNumber = ClockDomain.current.frequency.getValue): Unit = {
    timeout := (period*clkFrequency).toInt
  }
}
```

其中两个功能函数可以在顶层（至少比I2Cslave更顶层）的地方调用，直接根据调用位置的时钟来配置采样频率和超时周期。

#### I2cSlaveBus

这个似乎是I2cSlave 与 内部模块连接的接口，比如外部I2C master要读数据，那么数据从哪儿来？应该就是从这个接口，
通过rsp 传输给 I2CSlave。

```scala
case class I2cSlaveBus() extends Bundle with IMasterSlave {
  val cmd = I2cSlaveCmd()
  val rsp = I2cSlaveRsp()

  override def asMaster(): Unit = {
    out(cmd)
    in(rsp)
  }
}
```

##### I2cSlaveCmd

```scala
object I2cSlaveCmdMode extends SpinalEnum {
  val NONE, START, RESTART, STOP, DROP, DRIVE, READ = newElement()
}


case class I2cSlaveCmd() extends Bundle {
  val kind = I2cSlaveCmdMode()
  val data = Bool()
}
```

##### I2cSlaveRsp

```scala
case class I2cSlaveRsp() extends Bundle {
  val valid  = Bool()
  val enable = Bool()
  val data   = Bool()
}
```

### driveFrom

这个`driveFrom` 方法是I2C的核心，详细看一下其内部实现。


目前模型遥控器（RC Controller)主要还是使用MCU，MCU上的资源限制了遥控器中的功能