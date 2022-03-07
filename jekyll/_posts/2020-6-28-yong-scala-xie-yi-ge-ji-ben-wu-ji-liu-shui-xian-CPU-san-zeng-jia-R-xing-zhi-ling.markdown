---
layout: post
title: 用scala写一个基本五级流水线CPU(三)增加R型指令
date: 2020-06-28 12:01:45 +0800
categories: 技术 硬件
issue_id: 122
---
本次更新的代码可参考：

https://github.com/Ncerzzk/SimpleCPU/tree/deeb0217751f32bda5adf748b60cf528296466a6


前面的文章中已经添加了一条最基本的ORI指令（I型指令），然而指令系统目前还很不完善，如果要增加指令的话，还需要改动大量代码。

因此，本文开始着手进行指令系统的优化修改，着重思考几个问题：

- 增加指令所需修改的地方尽量少
- 有一些指令如and 和 andi ，一个是R型指令，一个I型指令，在译码阶段是不同的，但是到了执行阶段，这两个应用的是同一个操作，如何优化？

## EX优化

针对第二个问题，在之前指令枚举的基础上，增加一些新的指令枚举：指令类型枚举、指令功能码FUNC枚举（针对R型指令）、指令操作码OP枚举（针对I型指令），指令运算类型枚举，除了原本的LOGIC以外，还增加了ALU（算数运算）。


```scala
object InstTypeEnum extends SpinalEnum{
  val R,I,J = newElement()
  // R型指令的高6位为0(有例外），靠低6位区分功能
  // I型指令直接靠高6位区分功能
}

object InstFUNCEnum extends SpinalEnum{ // 指令功能码枚举
  val AND,OR,XOR,NOR= newElement()
  val SLL,SRL,SRA,SLLV,SRLV,SRAV = newElement()
  defaultEncoding = SpinalEnumEncoding("static")(
    AND -> 0x24 ,
    OR -> 0x25,
    XOR ->0x26,
    NOR ->0x27,

    SLL->0x0,
    SRL->0x2,
    SRA->0x3,
    SLLV->0x4,
    SRLV->0x6,
    SRAV->0x7
  )
}

object InstOPEnum extends SpinalEnum{  // 指令操作码枚举
  val ORI,ANDI,XORI,ADDI,ADDIU,SLTI,SLTIU= newElement()

  defaultEncoding = SpinalEnumEncoding("static")(
    ORI -> 0xD ,// 001101
    ANDI -> 0xC,
    XORI ->0xE,
    ADDI ->0x8,
    ADDIU->0x9,
    SLTI -> 0xA,
    SLTIU->0xB
  )
}

object OpEnum extends SpinalEnum{
  val LOGIC,ALU = newElement()
  val funcs = List(
    (LOGIC,OPLogic.caculate _),
    (ALU,OPArith.caculate _)
  )

  def caculate(op:Bits,opsel:Bits,oprnd1:Bits,oprnd2:Bits,left:Bits): Unit ={
    for (i<- funcs){
      when(op===i._1.asBits.resized){
        i._2(opsel,oprnd1,oprnd2,left)
      }
    }
  }
}
```
---

针对指令运算类型，如LOGIC和ALU，都增加了一个caculate方法，用于将运算类型和对应的操作绑定起来，这样在EX阶段就不需要再针对每个指令、或者每个运算类型，来写相应的操作了，因为操作已经在枚举中绑定了。

```scala
trait OPWithFunc{
  val funcs:List[(SpinalEnumElement[_],(Bits,Bits)=>Bits)]

  def caculate(opsel:Bits,oprnd1:Bits,oprnd2:Bits,left:Bits)={
    for(i <- funcs){
      when(opsel === i._1.asBits.resized){
        left := i._2(oprnd1,oprnd2)
      }
    }
  }

}

object OPArith extends SpinalEnum with OPWithFunc{
  val ADDU,SUBU = newElement()
  val SLTI,SLTIU = newElement()

  val funcs = List(
    (ADDU,(a:Bits,b:Bits)=> (a.asUInt + b.asUInt).asBits),
    (SUBU,(a:Bits,b:Bits)=> (a.asUInt - b.asUInt).asBits),
    // SLTI => Source Less than Immediate
    (SLTIU,(a:Bits,b:Bits)=> (a.asUInt < b.asUInt)?B(1,32 bits)|B(0)),
    (SLTI,(a:Bits,b:Bits) => (a.asSInt < b.asSInt)?B(1,32 bits)|B(0))
  )
}

object OPLogic extends SpinalEnum with OPWithFunc {
  val OR,AND,XOR = newElement()
  val funcs = List(
    (OR,(a:Bits,b:Bits)=> a | b),
    (AND,(a:Bits,b:Bits)=>a & b),
    (XOR,(a:Bits,b:Bits)=>a ^ b)
  )
}

```
---

这样一来，EX模块就可以进一步优化，因为操作都已经写在枚举中了，EX模块仅需调用即可：

```scala
class EX extends Component{
  val lastStage= new IDOut().flip()
  val exOut = new EXOut

  exOut.writeReg := lastStage.writeReg
  exOut.writeRegAddr := lastStage.writeRegAddr
  exOut.writeData :=0

  OpEnum.caculate(lastStage.op,lastStage.opSel,lastStage.opRnd1,lastStage.opRnd2,exOut.writeData)

}
```

与之前想必，EX模块精简了不少，以后增加新指令时，EX模块也不需要改动，仅需在上面的枚举中增加相应功能及操作即可。

## ID优化

针对译码模块，也要进行相应优化。增加了R型指令后，新的译码逻辑为：

- 判断指令类型是R型还是I型
  - 针对指令类型，做出不同的操作
    - 设置是否读取寄存器（如I型，只读取一个寄存器。R型，要读取两个寄存器）
    - 设置读取的寄存器的地址
    - 设置写入寄存器地址（I型写入的寄存器地址是rt，R型写入寄存器的地址是rd）
    - 根据指令的功能码（R型）或者操作码（I型），译出给后级（EX）的操作码(OP)和子操作码（OPSel)

主要修改：

```scala
  when(IDS.getInstType(lastStage.inst)===InstTypeEnum.I){
    val targetReg= lastStage.inst(16 to 20)
    val sourceReg = lastStage.inst(21 to 25)
    val instOp = IDS.OPof(lastStage.inst)

    for (i<- IDS.instsI){
      when(i.instOP.asBits.resize(instOp.getWidth)===instOp){
        idOut.op := i.decodeOP.asBits.resized
        idOut.opSel := i.decodeOPSel.asBits.resized
      }
    }

    idOut.writeRegAddr := targetReg
    idOut.writeReg := True
    regHeap.readEns(0) := True
    regHeap.readEns(1) := False
    regHeap.readAddrs(0) :=sourceReg
  }elsewhen(IDS.getInstType(lastStage.inst)===InstTypeEnum.R){
    val targetReg= lastStage.inst(16 to 20)  //rt
    val sourceReg= lastStage.inst(21 to 25)  //rs
    val destinationReg = lastStage.inst(11 to 15)  //rd

    val FUNC = IDS.FUNCof(lastStage.inst)
    for(i<- IDS.instsR){
      when(FUNC === i.instFUNC.resized){
        idOut.op := i.decodeOP.resized
        idOut.opSel := i.deCodeOpSel.resized
      }
    }
    idOut.writeRegAddr := destinationReg
    idOut.writeReg := True
    regHeap.readEns(0) := True
    regHeap.readEns(1) := True
    regHeap.readAddrs(0) :=sourceReg
    regHeap.readAddrs(1) :=targetReg
  }
  ```

  为了实现以上的目的，还添加了相应的数据结构：

  ```scala
  object IDS {
  def OPof(inst:Bits)= inst.takeHigh(6)
  def FUNCof(inst:Bits) = inst.take(6)

  def getInstType(inst:Bits): SpinalEnumCraft[InstTypeEnum.type] = {
    (OPof(inst)===B(0,6 bits) || (OPof(inst)===B("6'b011100")))?
      InstTypeEnum.R | InstTypeEnum.I
  }

  val instsI = List(
    new InstI(InstOPEnum.ORI,OpEnum.LOGIC,OPLogic.OR),
    new InstI(InstOPEnum.ANDI,OpEnum.LOGIC,OPLogic.AND),
    new InstI(InstOPEnum.XORI,OpEnum.LOGIC,OPLogic.XOR),
    new InstI(InstOPEnum.ADDIU,OpEnum.ALU,OPArith.ADDU),
    new InstI(InstOPEnum.SLTI,OpEnum.ALU,OPArith.SLTI),
    new InstI(InstOPEnum.SLTIU,OpEnum.ALU,OPArith.SLTIU)
  )

  val instsR = List(
    new InstR(InstFUNCEnum.AND,OpEnum.LOGIC,OPLogic.AND),
    new InstR(InstFUNCEnum.OR,OpEnum.LOGIC,OPLogic.OR)
  )

}

class InstI(s:SpinalEnumElement[_]*){  // I型指令类
  val arr= s.toList
  assert(arr.length==3)
  var instOP = arr(0).asBits   // 指令的指令码，与MIPS指令集相关
  val decodeOP = arr(1).asBits  // 译码后的指令，与CPU实现相关，即OpEnum中的值
  val decodeOPSel = arr(2).asBits // 译码后的指令子功能码，与CPU实现相关
}

class InstR(s:SpinalEnumElement[_]*){  // R型指令类
  val arr=s.toList
  assert(arr.length==3)
  val instFUNC = arr(0).asBits
  val decodeOP = arr(1).asBits
  val deCodeOpSel = arr(2).asBits
}
```

## 测试

测试代码：
```c
    addiu $1, $0, 0x1100
    addiu $2, $0, 0x0111
    and   $3, $1 ,$2
    or    $4, $1, $2
```

波形图：
![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/cpu3.jpg