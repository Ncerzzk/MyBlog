# 用scala写一个基本五级流水线CPU(九)超标量

标签（空格分隔）： 技术 硬件

---

准备开始着手进行双发射相关的修改。

根据《计算机体系结构：量化研究方法》中的描述，引入双发射相应地会引入一些问题：

- 某些未流水化的执行单元可能发生结构冒险（如除法）
- 因为指令的运行时间不同，一个周期写入寄存器的次数可能会大于1，发生写端口冲突（也是一种结构冒险）
- 指令乱序完成，存在WAW冒险（写后写，即两条指令对同一个寄存器或者同一个内存地址的写入顺序应该按照代码顺序，而不能按照完成顺序）
- 乱序完成导致的异常问题
  
因为写这个CPU的目的主要也是为了学习计算机组成原理，所以为了能把上面这些问题都在双发射中暴露出来，CPU的另一条流水线暂定为除法器。如果另一条流水线还是普通的ALU，那么上述的问题，如第一个就不会发生。

打算实现 顺序双发射、乱序执行、顺序写回。

因此，先实现个整数32位除法器吧。

## 除法器的实现

```scala
class Divider(bitNum:Int) extends Component{
  val io = new Bundle{
    val dividend = in UInt(bitNum bits)
    val divisor = in UInt(bitNum bits)
    val en = in Bool

    val quotient = out UInt(bitNum bits)
    val remainder = out UInt (bitNum bits)
    val ok = out Bool
    val busy = out Bool
  }

  io.ok:=False
  io.quotient := U(0)
  io.remainder := U(0)
  io.busy := False

  val remQuoReg = Reg(UInt(bitNum*2 bits)).init(0)

  val fsm = new StateMachine{
    val idle:State = new State with EntryPoint{
      whenIsActive{
        when(io.en){
          goto(caculting)
        }
      }
    }
    val caculting:StateDelay = new StateDelay(bitNum+1){
      onEntry{
        remQuoReg := io.dividend.resized
      }
      whenCompleted{
        io.quotient := remQuoReg.asBits.take(bitNum).asUInt
        io.remainder := remQuoReg.asBits.takeHigh(bitNum).asUInt
        io.ok := True
        goto(idle)
      }
      onExit{
        remQuoReg := U(0)
      }
    }
    caculting.whenIsActive{
      val a = remQuoReg |<<1
      val high = a.asBits.takeHigh(bitNum).asUInt
      val subResult=high - io.divisor
      io.busy := True
      when(subResult.msb===False){
        remQuoReg := (subResult.asBits ## (a.asBits.take(bitNum) | B(1,bitNum bits))).asUInt
      }otherwise{
        remQuoReg := a
      }
    }

  }
}
```

该除法器一共有两种状态，分别是idle和caculating状态。idle状态下用来接收输入保存到寄存器中。caculating负责运算（需要n+1周期）。因此完成一次运算，需要n+2周期（多出的一周期是用于idle下保存输入）

实现原理来自于：

[img:divider.jpg]

测试：输入（150/3)

[img:divider_test.jpg]

## 单发射超标量

一口吃不成一个胖子，因为拓展双发射需要对取指、译码、（发射，目前还没有），做较大修改。因此在实现双发射之前。我们先将除法器加入，实现成单发射的超标量处理器。

这个超标量处理器与之前的处理器的区别就是，之前的处理器如果执行除法运算，则后面的指令都需要阻塞（当然了，之前的处理器没有实现除法，这里是假设有除法的情况）。而这个超标量处理器可以在执行除法运算的同时，执行其他ALU运算（如果没有冒险）

要解决的几个问题：

- 除法器在运行的情况下，其他指令什么时候能正常发射，什么时候不行？
  - 除了会发生RAW冒险的（后面的指令读取除法结果），其他都正常发射
  
- 除法器与ALU都要写入寄存器，怎么办？
  - 方法1：再给寄存器组增加一个写端口，这样保证可以同时写入两个寄存器
  - 方法2：将写入寄存器作为结构冒险来检测
    - 方法a：使用移位寄存器来跟踪写端口的使用，如果待发射指令与正在执行的指令会在同意周期写入寄存器，那么暂停发射一周期
    - 方法b：在MEM中检测，如果有两个写入的请求，则暂停其中一个（一般来说，暂停执行时间短的指令）
- 除法器要写入的寄存器与ALU中的指令要写入的寄存器一样，怎么办？（输出相关、WAW冒险）
  - 因为目前只有除法器这个新增的执行单元，因此可以简单的考虑这个问题：
    - 当除法器要写入寄存器了，另一条指令在代码上肯定是位于除法指令的后方，因此可以说除法指令的结果作废了，直接将另一条指令的结果写入寄存器即可
    - 为什么可以说除法的结果作废呢？因为可以预见，在除法指令之后，肯定没有指令读取除法指令的结果，否则如果有的话，会被作为RAW冒险而阻塞在ID级
  - 另一种方法是使用寄存器重命名来解决WAW冒险，有点复杂，这里暂时不考虑




