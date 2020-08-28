---
layout: post
title: SpinalHDL中一个匪夷所思的报错(Object中信号的定义)
date: 2020-07-05 13:16:09 +0800
categories: 技术 硬件
issue_id: 127
---

这几天在重构CPU，免不了要对之前写的代码动刀。

今天尝试修改了一些东西后，发现编译能过，但是生成verilog一直失败，报错报的是：Hierarchy violation

如：
```scala
HIERARCHY VIOLATION : (toplevel/io_a : in UInt[??? bits]) is drived by XXX , but isn't accessible in the XXX component.
```

依照之前的经验，报这个错应该是因为把两个层级不一致的信号给连接起来了， 如a := b ，但由于b可能定义在更低的层级里，导致赋值失败。

然而我去看一下报错相关的信号，我今天重构的东西跟他并没有半毛钱关系阿？到底为何这样。

我先把今天增加的东西都删掉（早知道昨天晚上提交一下git了），重新编译运行，还是报错。奇怪。又把代码改回昨天重构的第一个版本，还是失败。
奇怪，重构的第一个版本肯定是对的的，不然我怎么会继续往下重构呢。于是我接着把重构的代码都删了，改回没重构的样子。编译运行，虽然还是报错，
但是这次它提示我，是某个静态枚举中，有两个值重复了……

如:
```scala
object InstOPEnum extends SpinalEnum{  // 指令操作码枚举
  val a,b =newElement()
  defaultEncoding = SpinalEnumEncoding("static")(
      a->0x01,
      b->0x01
  )
}
```

我突然想起来，是因为昨天晚上想把J指令全加上，但是J指令有两个是用OP区别（J JAL)，有两个是用FUNC区别（JALR JR），这对于我现在的指令系统来说，
需要改动一些东西，于是今天早上就开始重构，准备改变译码方式，但是昨天晚上写上的错误枚举没有删掉，导致这个静态枚举生成失败。

于是我把静态枚举改正，再加上今天和昨天晚上的重构内容，编译运行，正常了。What a fuck! 但是，为什么一个静态枚举生成失败，反而会影响到其他代码？导致它报别的地方的错误呢？

经过仔细分析，发现原因如下：

最主要的原因是我在一个object中，定义了某些信号，类似于`val xx = True`或者定义`val xxx=B(0)`这样的语句。而我在译码模块中，会用到这个object。
如果说object的第一次调用是在ID模块中，那么正常情况下这样写是没问题的。在scala中，object在第一次使用的时候被创建，也就是说这个object被创建的时候，把那些信号也都定义了，此时那些信号的层级就在ID模块下。

但是，但是来了。但是由于我在object中用到了上面那个错误的枚举。而那个静态枚举生成失败，导致这个object没有在ID中被创建，具体在哪里被创建我就没有仔细去看了，于是上面定义的信号显然就不在ID模块的层级下。

而我在ID模块中，就是使用这些信号来驱动ID模块的某些端口，在这种情况，当然会报出Hierarchy violation的错误，这不冤。

那么如何修改这样的问题呢？现在把那个错误枚举修复了，可以正常生成了，但这就解决问题了么？显然没有，下次可能某个地方写错了，或者在不小心在其他地方用到这个object，也会导致相同的问题。那

是否在spinalHDL中不应该使用object？显然不是，SpinalHDL官方的VexRiscv中，也大量使用了object。当然了，把所有的object都改成普通类，然后在用的地方实例化，是可以解决这样的问题，但显得过于累赘，增加代码的丑陋度。

最好的解决办法是：不要在object中用`val`直接定义信号，而应使用`def`来定义信号。这样，这个信号的定义的地方，就取决于这个信号使用的地方，而不是object创建的地方了（毕竟有很多因素会影响object在什么时候创建）**（当然了，这只是针对SpinalHDL中的"HardType"，如Bits,Bool这些，如果只是定义普通的Int之类的，无所谓）**

在SpinalHDL的Core中关于True和Flase的定义中：
```scala
  /**
    * True / False definition
    */
  def True  = Bool(true) //Should be def, not val, else it will create cross hierarchy usage of the same instance
  def False = Bool(false)
```

有这样一句注释，我第一次看的时候不懂什么意思，现在懂了。

