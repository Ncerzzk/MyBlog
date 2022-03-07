# 用scala写一个基本五级流水线CPU
ctime:2020-06-26 20:09:48 +0900|1593169788

标签（空格分隔）： 技术 硬件

---

最近学SpinaHDL，一直想写个什么东西练练手。刚好以前一直想写个CPU，之前也在重新学计算机组成原理，刚好就用来作为练习。
其实想写CPU的想法已经很久了，基本上每一次重新学FPGA或者verilog的时候，都会有这么一个想法，但是每次都是因为各种原因不了了之。

有一些是个人兴趣原因，比如又发现了其他更好玩的东西，也有时候是因为被verilog的繁琐劝退。这次用scala来写，后者的问题应该不会发生了。当然，
之前还有一些时候放弃是因为迷失在CPU纷繁复杂的结构中不能自拔，因为每次定下各种模块的定义都不能很好地满足需求，每次增加一点功能都要来回修改，最终
连一个流水线都没连通，就放弃了。

这次设计的CPU，打算先写一个指令 ori ，先将流水线跑起来，再逐步增加新指令。这个思路来自于《自己动手写CPU》，流水线的各种结构都会大致与
书中描述的一样，只是实现方式由verilog，改成scala而已。

因为scala学得也还不深，因此可能代码主要还是用OOP的思路来写，有一些地方可以继续优化。但是代码中也保持DRY原则（Don't repeat yourself），同一个接口不定义两次（比如很多模块要相互连接，那么需要定义互相连接的接口）等等。

目前实现的指令是ORI，将某个寄存器值与立即数或操作，写入另一个寄存器中

## 一些基本定义
- 五级流水线
- 数据总线宽度 32bit
- 寄存器数量 32个

## 总体框图
![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/simplecpu1.jpg

## 流水线两级中间的缓冲实现

每两级流水线之间，会有一组缓冲寄存器。在书《自己动手写CPU》中，是对所有的缓冲寄存器一个一个实现，受限于verilog贫瘠的表达能力。

但我们现在使用的scala，怎么可能再这样做呢。

```scala
class Stage[T <: Bundle](gen: => T) extends Component{
  val left:T= gen.flip()
  val right = createOutPort(left)
  def createOutPort(inBundle:Bundle)= {
    new Bundle {
      for(i <- inBundle.elements){
        val a =out (Reg(i._2.clone()))
        a match{
          case s:Bits => s.init(0)
          case b:Bool => b.init(False)
        }
        valCallbackRec(a,i._1)
        a := i._2
      }
    }
  }
}
```
调用方式是：
```scala
  val if2id = new Stage(new IFOut())
  val id2ex = new Stage(new IDOut())
```
只要传入缓冲寄存器模块的输入接口（实际上也就是上一级流水线的输出），他会自动创建一个right接口，right接口中的端口与left同名，只是方向是out，且是Reg型（毕竟是要做缓冲）

这里手动调用了`valCallbackRec(a,i._1)`来给Bundle中增加元素，也算是一个小小的hack，不知道是否有更优雅的方式。之前尝试直接定义val不行

## 取指IF

取值由一个存放指令的ROM和PC寄存器组成，ROM根据PC传来的地址，将指令读出，传给取值与译码这两级中间的缓冲寄存器。

### InstRom实现

instRomCellNum是ROM可以存放的指令条数，目前只定义为16条

```scala
class InstRom extends Component {
  val io = new Bundle{
    val en = in Bool
    val addr = in Bits(log2Up(GlobalConfig.instRomCellNum) bits)
    val inst = out Bits(GlobalConfig.dataBitsWidth)
  }
  protected val mem=Mem(Bits(GlobalConfig.dataBitsWidth),GlobalConfig.instRomCellNum)

  mem.init(List.fill(16)(B("32'h34011100")))
  io.inst := mem.readSync(io.addr.asUInt,io.en)

  def init(a:Seq[Bits]) = mem.init(a)
}
```

### PC寄存器实现

```scala
// 每一个cycle，PC寄存器会+1（表示加一个字）
class PC extends Component{
  val io= new Bundle{
    val pc = out Bits(GlobalConfig.dataBitsWidth)
  }

  val pc_reg = Reg(UInt(GlobalConfig.dataBitsWidth)).init(0)
  io.pc := pc_reg.asBits
  pc_reg := pc_reg + 1  // 每次取一条指令，一条指令4字节，因为Rom的地址以字为单位，因此这里+1而不是+4
}
```

## 译码ID
译码阶段由译码模块和寄存器组组成

### 寄存器组实现

这里将RegHeap的接口分成一个读接口和一个写接口也是出于DRY的考虑，因为寄存器的读在译码阶段，写在写回阶段，如果将读写定义成一个接口，势必到时候在译码和写回阶段需要重新定义接口（或者空置接口）。

```scala
class RegHeapReadPort(regNum:Int=32) extends Bundle with IMasterSlave {
  val readAddrs = Vec(Bits(log2Up(regNum) bits),2)
  val readDatas =  Vec(Bits(GlobalConfig.dataBitsWidth),2)
  val readEns = Vec(Bool,2)

  override def asMaster(): Unit = {
    in(readDatas)
    out(readAddrs,readEns)
  }
}

class RegHeapWritePort(regNum:Int=32) extends Bundle with IMasterSlave {
  val writeEn = Bool
  val writeAddr =Bits(log2Up(regNum) bits)
  val writeData = Bits(GlobalConfig.dataBitsWidth)

  override def asMaster(): Unit = {
    out(writeEn,writeAddr,writeData)
  }
}

class RegHeap(regNum: Int = 32) extends  Component {
  val readPort= slave(new RegHeapReadPort)
  val writePort = slave(new RegHeapWritePort)

  val heap = Vec(Reg(Bits(GlobalConfig.dataBitsWidth)).init(0),regNum)

  readPort.readDatas(0) := 0
  readPort.readDatas(1) := 0

  when(writePort.writeEn){
    heap(writePort.writeAddr.asUInt) := writePort.writeData
  }otherwise{

    for(i <- 0 until 2){
      when(readPort.readEns(i)) {
        readPort.readDatas(i) := heap(readPort.readAddrs(i).asUInt)
      }
    }
  }
}
```

### 译码模块实现

译码模块几个模块中最复杂的，光写一个指令就这么多代码了，之后要考虑将指令与对应操作抽象出来。

```scala
class ID extends Component{
  val regHeap = master(new RegHeapReadPort)

  def <>(regs: RegHeap)={
    regHeap <> regs.readPort
  }

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

  when(regHeap.readEns(0)){
    idOut.opRnd1 := regHeap.readDatas(0)
  }otherwise{
    idOut.opRnd1 := imm
  }
  when(regHeap.readEns(1)){
    idOut.opRnd2 := regHeap.readDatas(1)
  }otherwise{
    idOut.opRnd2 := imm
  }


}
```
## 执行EX

执行级比较简单，因为目前就一条指令。指令的定义使用枚举来区分。

```scala
class EX extends Component{
  val lastStage= new IDOut().flip()
  val exOut = new EXOut

  exOut.writeReg := lastStage.writeReg
  exOut.writeRegAddr := lastStage.writeRegAddr
  exOut.writeData :=0

  switch(lastStage.opSel){
    is(OpLogic.OR.asBits.resize(lastStage.opSel.getWidth)){
      exOut.writeData := lastStage.opRnd1 | lastStage.opRnd2
    }
  }
}
```

指令相关的枚举：InstEnum因为是要与Rom的指令相关的，因此定义为MIPS的指令，至于OpEnum和OpLogic，仅仅只在CPU内部使用，因此是什么值无所谓。
```scala
object InstEnum extends SpinalEnum{  // 指令枚举
  val EXEORI = newElement()
  defaultEncoding = SpinalEnumEncoding("static"){
    EXEORI-> 0xD // 001101
  }
}

object OpEnum extends SpinalEnum{
  val LOGIC = newElement()
}

object OpLogic extends SpinalEnum{
  val OR = newElement()
}
```

## 访存MEM

由于当前实现的指令ORI不需要访问内存，因此访存模块啥也没干，直接将输入输出连接起来。

```scala
class MEM extends Component{
  val lastStage = new EXOut().flip()

  val memOut = new MEMOut

  for(i <- 0 until memOut.elements.length){
    memOut.elements(i)._2<>lastStage.elements(i)._2
  }
  //memOut <> lastStage
}
```

## 写回WB

写回也没干什么事，只是将要写入的寄存器地址和数据准备好，传给寄存器组接口

```scala
class WB extends Component{
  val lastStage= new MEMOut().flip()

  val wbOut= master(new RegHeapWritePort)

  wbOut.writeAddr := lastStage.writeRegAddr
  wbOut.writeData := lastStage.writeData
  wbOut.writeEn := lastStage.writeReg

  def <>(regHeap: RegHeap)={
    wbOut <> regHeap.writePort
  }
}
```

## CPU整体连接

目前看起来还稍显凌乱，之后再继续优化，两个模块之间的连接，尽量不要手动连接两个信号。

```scala
class CPU extends Component  with BusMasterContain {
  val io = new Bundle{
    val inst = in Bits(GlobalConfig.dataBitsWidth)
    val romEn = out Bool
    val romAddr = out Bits( log2Up(GlobalConfig.instRomCellNum) bits)
  }
  val regs= new RegHeap(GlobalConfig.regNum)
  
  val pc_reg =new PC()
  io.romAddr := pc_reg.io.pc.resize(io.romAddr.getWidth)
  io.romEn := True


  val if2id = new Stage(new IFOut())
  val id = new ID()
  id <> regs
  if2id.left.pc := pc_reg.io.pc
  if2id.left.inst := io.inst
  if2id.right <> id.lastStage

  val id2ex = new Stage(new IDOut())
  val ex = new EX()
  id2ex.left <> id.idOut
  id2ex.right <> ex.lastStage

  val ex2mem = new Stage(new EXOut())
  val mem = new MEM()
  ex2mem.left<>ex.exOut
  ex2mem.right<>mem.lastStage

  val mem2wb = new Stage(new MEMOut())
  val wb = new WB()
  mem2wb.left <> mem.memOut
  mem2wb.right<>wb.lastStage

  wb<>regs

}
```

## 顶层文件

最后是顶层文件，除了CPU，还有个ROM

```scala
class SOC extends Component {

  val cpu = new CPU
  val rom = new InstRom

  rom.init(List.fill(16)(B("32'h34011100")))
  rom.io.inst<> cpu.io.inst
  rom.io.en <> cpu.io.romEn
  rom.io.addr<> cpu.io.romAddr
}
```

## 测试

测试指令为 h34011100

手动译码：将寄存器0 的值 与 1100 或 ，写入 寄存器1

![此处输入图片的描述][2]

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/simplecpu.jpg

可以看到，经过5个cycle之后，寄存器1的值变为1100了，证明流水线确实跑起来了。
