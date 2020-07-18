# 用scala写一个基本五级流水线CPU(九) CP0协处理器

标签（空格分隔）： 技术 硬件

---

MIPS中需要实现一个CP0协处理器，以实现异常等相关操作。

## 精确异常

精确异常，指被异常打断的指令（异常受害者）之前的指令都要正常执行完成，而之后的指令（在流水线中的），要全部取消。

```c
    lw $2,3
    KKA $1,$2
```

第二条指令是我随便写的，没有这种指令。这两条指令，第一条由于地址未对齐，会在MEM阶段发生异常。然而，第二条指令早就在译码阶段就会发生无效指令异常，也就是说第二条指令会更早发生异常，这就和精确异常的要求不符合了。

因为按照精确异常的要求，LW发生异常后，他之后的指令都要取消，也就是不能发生无效指令异常了。

为了不发生这样的问题，在MIPS实现中，经常是在流水线的阶段中，一旦发生异常，并不马上处理，而是仅做好标志，然后到流水线的特定阶段统一处理。这样，当LW进入异常处理的时候，它之后的指令再发生异常就不再处理了。通过这样可以实现按“指令顺序”处理异常，而不是按“发生顺序”处理异常。

## CP0的实现

### 寄存器读写

一般来说，异常处理阶段放在MEM阶段，因为在这里，大多数指令如果要发生异常已经都发生了（有在WB阶段发生异常的指令吗，暂时不知道，就当作没有吧）。CP0作为一个协处理器，肯定也有一堆寄存器。CPU可以通过两条指令(mtc0,mfc0)来读、和写CP0的寄存器。这里就有一个问题了，CP0的读写应该放在什么位置？

考虑一段代码：

```c
    mtc0 CONFIG,0x11
    mfc0 $1,CONFIG
    addiu $2,$1,100
```

这段代码中，先往CP0的CONFIG寄存器写入一个值，然后立马读出来，接着马上进行计算。当然了，如果我们拥有一个机智的编译器，这段代码是可以优化的，但是现在我们假设我们的编译器是个智障， 只能依靠CPU自己来处理可能的冒险了。

由于CP0是放在MEM阶段，那么先从读写也放在MEM阶段考虑。

- MEM阶段将写入内容放在数据线上，实际写入已经在WB阶段了（此时下一条指令已经在MEM，可以正常取值）
- MEM阶段读入CONFIG数据，然后准备写入$1（与LOAD指令一样）
  - 需要在第二条指令之后插入Nops

可以发现，如果读写都在MEM阶段，则三条指令要插入1个空泡，效率只有75%

如果放其他地方呢？先考虑读，如果把读移到EX阶段，中间无需插入空泡下一条指令就可以直接使用。

### 异常处理

#### 异常类型枚举

```scala
object ExceptionEnum extends SpinalEnum{
  val INT,MOD,TLBL,TLBS,ADEL,ADES,IBS,DBE = newElement()
  val SYS,BP,RI,CPU,OV,TR=newElement()
  val WATCH,MCHECK=newElement()

  def getHandleAddress(a : SpinalEnumCraft[ExceptionEnum.type])={
    var result = Bits(GlobalConfig.dataBitsWidth)
    switch(a){
      for(i<- elements){
        is(i){result := 2*i.position + GlobalConfig.vectorStartAddress}
      }
    }
    result
  }
}
```

在译码阶段和执行阶段都添加异常信息的信号，分别是：是否发生异常、异常类型，一旦发生异常，将异常信息一级一级往下传，等到MEM阶段统一处理。

处理逻辑参考《自己动手写CPU》

[img:exception.jpg]

```scala
  val jmpAddress= ExceptionEnum.getHandleAddress(io.exception)
  when(io.except){
    when(EXL){ // 已经处于异常处理之中
      when(io.exception =/= ExceptionEnum.INT){  // 如果是中断，不处理
        pcPort.JMP(jmpAddress) // 跳转到新的异常的处理地址中
        reqCTRL.req := StageCTRLReqEnum.EXFLUSH
        ExcCode := io.exception.asBits.resized
      }
    }otherwise{
      // 目前并不在异常处理中
      EXL :=True
      ExcCode := io.exception.asBits.resized
      BD := io.isDelaySlot
      when(io.isDelaySlot){
        EPC := (io.pc.asUInt -1).asBits
      }otherwise{
        EPC := io.pc
      }
      pcPort.JMP(jmpAddress) // 跳转到新的异常的处理地址中
      reqCTRL.req := StageCTRLReqEnum.EXFLUSH
    }
  }
```

通过向PC写入来跳转到异常处理地址，并发起流水线清除请求。由于PC的写入端口只有一个，目前被EX流水段用了，因此需要添加一个PC的写入选择器。考虑将选择器实现在流水线控制器中。

```scala
  val pcWriteFromEX = slave(new PCPort)
  val pcWriteFromMEM = slave(new PCPort)
  val pcWritePort = master(new PCPort)
  
  pcWritePort.writeEN := pcWriteFromMEM.writeEN || pcWriteFromEX.writeEN
  when(pcWriteFromMEM.writeEN){
    pcWritePort.writeData := pcWriteFromMEM.writeData
  }elsewhen (pcWriteFromEX.writeEN){
    pcWritePort.writeData := pcWriteFromEX.writeData
  }otherwise{
    pcWritePort.writeData := 0
  }
```


