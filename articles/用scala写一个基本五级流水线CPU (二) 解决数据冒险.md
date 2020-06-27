# 用scala写一个基本五级流水线CPU (二) 解决数据冒险
ctime:2020-06-27 10:17:34 +0900|1593220654

标签（空格分隔）： 技术 硬件

---

所谓数据冒险，即后面的指令依赖于前面指令执行的结果。
举例：
```c
初始状态  $0=0

ORI $1 = $0 | 1100
ORI $2 = $1 | 0011
```

按照程序员的想法，显然最后$2应该等于1111才对，但如果按照之前实现的流水线，由于写回寄存器是在流水线的最后一级，而读流水线是在译码级，因此当第二条指令到译码阶段时，第一条指令才刚到执行级，还没将结果写回。这样执行的结果是：$2=0011

同理，会出现数据冒险的还有其他情况：

为了便于描述，称对$1赋值的指令为指令1，对$2赋值的为指令2.

```c
ORI $1 = $0 | 1100
NOP
ORI $2 = $1 | 0011
```

这种情况，当指令2在译码时，指令1才刚到访存，也还没写入寄存器。



和

```c
ORI $1 = $0 | 1100
NOP
NOP
ORI $2 = $1 | 0011
```

这种情况，当指令2在译码时，指令1才刚到写回，此时写回阶段已经将写入地址和写入值放在了数据线上，但是要等下一个时钟寄存器组才会将值写入。

为了解决这个问题，常用的办法是数据前推。依据在于：实际上上一条语句的结果在EX阶段就有了，因此我们可以将EX MEM WB中，将要写入的寄存器值、寄存器地址等信号接入译码模块，如果译码模块发现要读取的寄存器地址与后面阶段要写入的寄存器地址是一样的，那么就直接使用后面阶段的值。

好了，接下来就是具体在代码上实现了：

```scala
class ID extends Component{
  val regHeap = master(new RegHeapReadPort)

  // 增加三个back接口，用来接收后面阶段的值
  val exBack = new EXOut().flip()  
  val memBack = new MEMOut().flip()
  val wbBack = slave(new RegHeapWritePort)

  def <>(regs: RegHeap)=regHeap <> regs.readPort
  
  // 增加与后面阶段的连线函数
  def <>(ex:EX): Unit =exBack <> ex.exOut
  def <>(mem:MEM) = memBack <> mem.memOut
  def <>(wb:WB) = wbBack <> wb.wbOut


  val lastStage = new IFOut().flip()

  val idOut= new IDOut

  val op =lastStage.inst.takeHigh(6)
  val op2 = lastStage.inst(6 to 10)
  val op3 = lastStage.inst.take(6)
  val op4 = lastStage.inst(16 to 20)

  val imm = B(0,16 bits) ## lastStage.inst.take(16)    // 立即数


  val reg1Addr = lastStage.inst(21 to 25)
  val reg2Addr = lastStage.inst(16 to 20)


  for(i <- idOut.elements){
    if(i._1 == "writeReg"){
      i._2 := False
    }
    else {
      i._2 := B(0)
    }
  }

  regHeap.readAddrs(0) :=reg1Addr
  regHeap.readAddrs(1) :=reg2Addr
  regHeap.readEns(0) := False
  regHeap.readEns(1) := False
  switch(op){
    is(InstEnum.EXEORI.asBits.resize(op.getWidth bits)){
      val targetRegAddr = lastStage.inst(16 to 20)
      idOut.writeReg := True
      idOut.op := OpEnum.LOGIC.asBits.resize(3 bits)
      idOut.opSel := OpLogic.OR.asBits.resize(8 bits)
      idOut.writeRegAddr := targetRegAddr
      regHeap.readEns(0) := True
      regHeap.readEns(1) := False
    }
  }

  // 判断当前要读取的寄存器地址，分别是否与ex mem wb阶段要写入的值一致。注意，这里是有优先级的，ex的优先级最高，因为这代表的是上一条语句。
  var i = 0;
  for( rnd <- List(idOut.opRnd1,idOut.opRnd2)){
    when(regHeap.readEns(i)){
      rnd := regHeap.readAddrs(i).mux(
        exBack.writeRegAddr -> exBack.writeData,
        memBack.writeRegAddr -> memBack.writeData,
        wbBack.writeAddr -> wbBack.writeData,
        default ->regHeap.readDatas(i)
      )
    }otherwise{
      rnd := imm
    }
    i+=1
  }
}
```

最后测试：

![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/cpu2.jpg

可以发现，最后寄存器2的值是1111，证明没有产生数据冒险。

测试的指令是：
```
ORI $1 = $0 | 1100
NOP
NOP
ORI $2 = $1 | 0011
```
