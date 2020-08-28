---
layout: post
title: 用scala写一个基本五级流水线CPU(五)加入分支指令(B)
date: 2020-06-29 23:16:01 +0800
categories: 技术 硬件
issue_id: 124
---

本次代码参考：
https://github.com/Ncerzzk/SimpleCPU/tree/2075fef553cef83082811827659f8dedb8153eeb

增加了分支指令（如B,BEQ,BNE等）

分支指令实际上与J指令相似，因为分支延迟槽的关系，将其提前到ID阶段执行，因此相关的枚举类型就和之前写的算数运算、逻辑运算不太一样了。

首先在指令操作码的枚举中增加分支指令（因为分支指令的OP码并不是0）：

```scala
object InstOPEnum extends SpinalEnum{  // 指令操作码枚举
  val ORI,ANDI,XORI,ADDI,ADDIU,SLTI,SLTIU= newElement()
  val BEQ,BGTZ,BLEZ,BNE = newElement()
  defaultEncoding = SpinalEnumEncoding("static")(
    ORI -> 0xD ,// 001101
    ANDI -> 0xC,
    XORI ->0xE,
    ADDI ->0x8,
    ADDIU->0x9,
    SLTI -> 0xA,
    SLTIU->0xB,

    // 以下为分支语句
    BEQ->0x4,
    BGTZ->0x7,
    BLEZ->0x6,
    BNE->0x5
  )
}
```
增加分支指令及其对应的操作：
```scala
object IDS {
  ...
  def isRInst(inst:Bits):Bool={
    val op = OPof(inst)
    val l = List(InstOPEnum.BEQ,InstOPEnum.BLEZ,InstOPEnum.BGTZ,InstOPEnum.BNE)
    var result :Bool = False
    val newL= for(i <- l) yield i.asBits.resize(op.getWidth) === op
    for(i <-newL){
      result = result|i
    }
    result
  }
  ...

  val reg0=()=>B(0,6 bits).clone()
  val instsB = List(
  // 指令OP，操作数1来源，操作数2来源，转移分支的条件
    (InstOPEnum.BEQ, (inst:Bits)=>RSof(inst),(inst:Bits)=>RTof(inst), (a:Bits,b:Bits)=> a === b),
    (InstOPEnum.BGTZ,(inst:Bits)=>RSof(inst),(inst:Bits)=>reg0(),     (a:Bits,b:Bits)=> a.asSInt > b.asSInt),
    (InstOPEnum.BLEZ,(inst:Bits)=>RSof(inst),(inst:Bits)=>reg0(),     (a:Bits,b:Bits)=> a.asSInt <= b.asSInt),
    (InstOPEnum.BNE,(inst:Bits)=>RSof(inst),(inst:Bits)=>RTof(inst),  (a:Bits,b:Bits)=> a =/= b)
  )
 
}
```

 目前采用这种数据结构，目的是简化译码阶段的判断，这是我目前想到的最简洁的写法了。

 ```scala
 when(IDS.isIRInst(lastStage.inst)) {
    val targetReg = lastStage.inst(16 to 20)
    val sourceReg = lastStage.inst(21 to 25)
    val instOp = IDS.OPof(lastStage.inst)

    when(IDS.isRInst(lastStage.inst)){
      val offset = lastStage.inst.take(16)
      for(i <- IDS.instsB){
        when(instOp === i._1.asBits.resize(instOp.getWidth)){  // 确定了指令
          val rs = i._2(lastStage.inst)
          val rt = i._3(lastStage.inst)
          regHeap.readAddrs(0) := rs.resized
          regHeap.readAddrs(1) := rt.resized
          when(i._4(idOut.opRnd1,idOut.opRnd2)){
            val newPC = offset.asSInt.resize(GlobalConfig.dataBitsWidth)+lastStage.pc.asSInt+1
            pcPort.writeEN := True
            pcPort.writeData := newPC.asBits
          }
        }
      }
      //idOut.writeRegAddr := targetReg
      idOut.writeReg := False
      regHeap.readEns(0) := True
      regHeap.readEns(1) := True
    }otherwise{
       ... I型指令处理
    }

  }elsewhen(IDS.isJInst(lastStage.inst)){
    ... J型指令处理

  }otherwise{
    ... R型指令处理
  }
  }

```

测试：
```c
	nop
	addiu $1, $0, 0x1100
	beq  $1,$0,20
	addiu $2, $0, 0x0111
	and   $3, $1 ,$2
	or    $4, $1, $2
```
可以看到因为条件不满足，所以没有跳转，正常执行了。
![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/cpu5.jpg

下一次打算对目前的代码进行一下重构，但是又担心重构完，想要新增功能的话，一下子重构完的结构可能又得修改以满足新功能。

或者考虑开始实现乘法等操作。