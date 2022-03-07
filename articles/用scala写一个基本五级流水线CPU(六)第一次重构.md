# 用scala写一个基本五级流水线CPU(六)第一次重构
ctime:2020-06-30 19:18:49 +0900|1593512329

标签（空格分隔）： 技术 硬件

---

CPU写到这里，流水线已经基本可以跑起来了，但是目前在写的过程中也渐渐感觉到一些问题，具体是：

- 流水线缓冲级的写法过于繁琐，虽然之前稍微了修改了一下，使显式连接没那么多，但问题还在
- 增加指令较为麻烦，如果说是增加普通的I、R型指令，因此之前已经写好模式，直接增加即可。但在增加一些指令，比如MULT,MULTU,就发现了问题。因为这两个指令并不是向寄存器组的寄存器中写入，而是向寄存器HI,LO写入。那怎么办呢，修改前面的范式，让他除了能像寄存器组的寄存器写入，还能写入HI,LO吗？可想而知，最后那个范式会越来越复杂。
  

重构计划：

- 目前流水线是由Component的形式组装起来的，但实际上，在spinalHDL，它建议不必要的时候，采用Area而不是另外建立Component，因为建立Component就意味着要重复定义输入输出端口。之前我虽然采用将端口抽象成类的方式，但仍有些累赘。
  - 为什么一开始要采用Component呢，因为这是用Verilog写CPU的正常方法。以Verilog的表现力，如果将所有的东西挤在一个Module中，可想而知最后只能变成一坨屎山。但是
  - 因此，现在考虑使用Area来重构流水线
  
- 指令系统参考了VexRiscv的方法，打算用另外一个思路来写。
  - 以前的思路是按照流水线为主的思路，在流水线的每一级，针对不同的指令做不同的操作。
  - VexRiscv的思路是以指令为主，每个指令在每个阶段做什么事，直接Plug到该阶段。当然了，VexRiscv的实现比较复杂，我的scala功底还不够能完全理解他的实现方式，只能说先借鉴一下思想。

2020年7月5日 update:

## 重构计划1：使用Area来重构流水线     失败

- 丢弃的分支在此：https://github.com/Ncerzzk/SimpleCPU/tree/AreaInsteadOfModule
- 具体原因挺多的
  - 使用Area来写整个流水线的话，生成的Verilog非常难以阅读。如果是用Component 来写的话，至少各个模块还能分开，但如果是用Area来写的话，整个CPU所有的东西都挤在一起，如果想通过verilog来看某些语句的效果的话，简直是噩梦。
  - 流水线之间只能通过一些中间信号的来连接，VexRiscv中使用了一些自建的数据结构来维护，如input(signal) output(signal) insert(signal)，等等。我也照猫画虎自己实现了一套，但是由于scala水平不够，写得略显臃肿，完全没有VexRiscv中那种轻便的感觉。越写越恶心
  - 为了更高程度的抽象，经常迷失在scala的语法中。虽然随着重构指令系统中，scala的水平又长进了一些，但即使这样，还是不太能驾驭高程度的抽象写法。

## 重构计划2：重构指令系统

本来想按照VexRiscv，直接将指令的行为plug到流水线中。但由于Area的重构搁浅，因此这方面没有实现。

目前的重构完的指令系统，使用SpinalHDL内置的MaskedLiteral来进行指令的匹配。

### 指令定义

```scala
  def ADD     = M"000000--_--------_--------_--100000"
  def ADDU    = M"000000--_--------_--------_--100001"
  def ADDI    = M"001000--_--------_--------_--------"
  def ADDIU   = M"001001--_--------_--------_--------"

  def AND     = M"000000--_--------_--------_--100100"
  def ANDI    = M"001000--_--------_--------_--------"

  def DIV     = M"000000--_--------_--------_--011010"
  def DIVU    = M"000000--_--------_--------_--011011"
  def MULT    = M"000000--_--------_--------_--011000"
  def MULTU   = M"000000--_--------_--------_--011001"

  def NOR     = M"000000--_--------_--------_--100111"
  def OR      = M"000000--_--------_--------_--100101"
  def ORI     = M"001101--_--------_--------_--------"
  ...
```

MaskedLiteral可直接调用===与Bits类型进行匹配。

### 指令译码行为的抽象

将指令译码的行为抽象出来，译码阶段的行为其实不多，抽象完变成这些：

```scala
object READ_REG0 extends Actions //  注意，如果READ_REGX为FALSE,则会默认使用Imm来替代(代码在ID的最后一部分）
object READ_REG1 extends Actions
object WRITE_REG extends Actions
object WRITE_REG_ADDR extends Actions
object READ_REG0_ADDR extends Actions
object READ_REG1_ADDR extends Actions
object INST_OP  extends Actions
object INST_OPSEL extends Actions
object BRANCH_CONDITION extends Actions
object BRANCH_OPRND2 extends Actions // 只需要设置2，因为OPRN1默认都是寄存器的值
object WRITE_PC extends Actions
object BRANCH_TARGET extends Actions
```

有些行为的参数直接使用Bool类型的True或者False，有些行为的参数是特定的：

```scala
object RS extends Arguments
object RT extends Arguments
object RD extends Arguments

object IMMJ_ABSOLUTE extends Arguments
object IMMI_RELATIVE extends Arguments
object REG  extends Arguments
case class RAW_BITS(b:Bits) extends Arguments
```

然后将某一类的指令的共有行为抽出来，作为一个普通的Actions列表，如I型指令的共有行为：

```scala
  def IActions=HashMap(
    WRITE_REG       ->  True,
    WRITE_REG_ADDR  ->  RT,
    READ_REG0       ->  True,
    READ_REG0_ADDR  ->  RS,
    READ_REG1       ->  False
  )
```

当然了，每个指令还有一些独特的东西，比如OP码，和OPsel码，这些每个指令再单独添加：

```scala
  def IInsts= List(
    ORI ->(IActions++ HashMap(INST_OP-> OpEnum.LOGIC,INST_OPSEL->OPLogic.OR)),
    ANDI ->(IActions++ HashMap(INST_OP-> OpEnum.LOGIC,INST_OPSEL->OPLogic.AND)),
    XORI ->(IActions++ HashMap(INST_OP-> OpEnum.LOGIC,INST_OPSEL->OPLogic.XOR)),
    ADDIU ->(IActions++ HashMap(INST_OP-> OpEnum.ALU,INST_OPSEL->OPArith.ADDU)),
    ADDI ->(IActions++ HashMap(INST_OP-> OpEnum.ALU,INST_OPSEL->OPArith.ADD)),
    SLTI ->(IActions++ HashMap(INST_OP-> OpEnum.ALU,INST_OPSEL->OPArith.SLT)),
    SLTIU ->(IActions++ HashMap(INST_OP-> OpEnum.ALU,INST_OPSEL->OPArith.SLTU))
  )
```

J型指令由于行为差别都比较大，对每个指令添加的东西比较多：

```scala
  def JInsts= List(
      J->JActions,
      JAL->(JActions ++ HashMap(
        WRITE_REG->True,
        WRITE_REG_ADDR->RAW_BITS(B("32'd31"))
      )),
      JR->(JActions ++ HashMap(
        BRANCH_TARGET->REG,
        READ_REG0 -> True,
        READ_REG0_ADDR -> RS
      )),
      JALR->(JActions ++ HashMap(
        BRANCH_TARGET->REG,
        READ_REG0 -> True,
        READ_REG0_ADDR -> RS,
        WRITE_REG->True,
        WRITE_REG_ADDR->RAW_BITS(B("32'd31"))
      ))
  )
```

然后在ID模块中，遍历匹配指令，匹配到之后，根据指令的行为列表，操作具体端口:

```scala
  def doDecode(instsList:immutable.Seq[(MaskedLiteral, Map[Actions, _])]) ={
    for (i <- instsList){
      when(inst.raw === i._1){
        for((action,argument) <- i._2){
          if(action == READ_REG0){
            regHeap.readEns(0) := argument.asInstanceOf[Bool]
          }else if(action == READ_REG1){
            regHeap.readEns(1) := argument.asInstanceOf[Bool]
          }else if(action == WRITE_REG){
            idOut.writeReg := argument.asInstanceOf[Bool]
          ...
      }
    }
  }
```

这样一来，译码模块就显得清爽很多了：

```scala
  val inst = INST(lastStage.inst)
  //决定立即数的符号位拓展
  val imm:Bits = (idOut.op === OpEnum.LOGIC.asBits.resize(idOut.op.getWidth))?
    inst.immI.resize(GlobalConfig.dataBitsWidth)|
    inst.immI.asSInt.resize(GlobalConfig.dataBitsWidth).asBits

  doDecode(Insts.AllInsts)
  
  var i = 0;
  for( rnd <- List(idOut.opRnd1,idOut.opRnd2)){
    when(regHeap.readEns(i)){
      rnd := regHeap.readDatas(i)
      when(exBack.writeReg && exBack.writeRegAddr===regHeap.readAddrs(i)){
        rnd := exBack.writeData
      }elsewhen(memBack.writeReg && memBack.writeRegAddr===regHeap.readAddrs(i)) {
        rnd := memBack.writeData
      }elsewhen(wbBack.writeEn && wbBack.writeAddr===regHeap.readAddrs(i)){
        rnd := wbBack.writeData
      }
    }otherwise{
      rnd := imm
    }
    i+=1
  }
```