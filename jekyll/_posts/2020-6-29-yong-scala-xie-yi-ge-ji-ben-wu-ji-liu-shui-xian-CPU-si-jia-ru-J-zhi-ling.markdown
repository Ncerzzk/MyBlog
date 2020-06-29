---
layout: post
title: 用scala写一个基本五级流水线CPU(四)加入J指令
date: 2020-06-29 16:08:10 +0900
categories: 技术 硬件
issue_id: 123
---

本次代码更新：
https://github.com/Ncerzzk/SimpleCPU/tree/ddd04698a83587a1937520bddf76900dd411b4d7

R、I型指令其实还有不少没实现，但是因为已经实现了一两句，其他大部分都是重复劳动，先写点J型指令换个脑子。

J型指令只有两条，J和JR，都是高6位为OP码，分别是000010和000011，因此不打算再写成枚举类型了，直接译码那里加个分支即可。为了实现分支延迟槽，把写入PC寄存器的操作挪到ID级实现，这样的话，当跳转语句（J）在译码的时候，下一条语句在取指阶段，刚好可以作为延迟槽运行。

当然了，吐槽一下延迟槽，感觉这是给写编译器的人增加工作量阿，毕竟延迟槽填充什么语句是很有讲究的，是在太懒可以填充NOP。

```scala
  when(IDS.isIInst(lastStage.inst)) {
      // I 型指令处理过程
      ...
  }elsewhen(IDS.isJInst(lastStage.inst)){
    val targetAddress = lastStage.inst.take(26)
    val newPC =  (lastStage.pc.asUInt+1).asBits.takeHigh(6) ## targetAddress
    pcPort.writeEN := True
    pcPort.writeData := newPC
    // 注意，这里只写了J指令，JR指令要写寄存器，还未实现

  }otherwise{
      // R 型指令处理过程
      ...
  }
```

当然，要写入PC寄存器，还需要对PC寄存器进行一些修改，因为之前PC寄存器是没有写入接口的：

```scala
class PC extends Component{
  val io= new Bundle{
    val pc = out Bits(GlobalConfig.dataBitsWidth)
  }
  val writePort: PCPort = slave(new PCPort)

  val pc_reg = Reg(UInt(GlobalConfig.dataBitsWidth)).init(U("32'h0"))
  io.pc := pc_reg.asBits
  when(writePort.writeEN){
    pc_reg := writePort.writeData.asUInt
  }otherwise {
    pc_reg := pc_reg + 1 // 每次取一条指令，一条指令4字节，因为Rom的地址以字为单位，因此这里+1而不是+4
  }
}
```

ID中也增加相应的PC写入接口：
```scala
class ID extends Component{
    ...
  val pcPort = master(new PCPort)
    ...
}
```

## 测试代码

```c
0	nop
4	addiu $1, $0, 0x1100
8	j 20
12	addiu $2, $0, 0x0111
16	and   $3, $1 ,$2
20	or    $4, $1, $2
```

### BUG1 跳转地址不对

具体问题：本意是想让程序跳到20的位置，跳过16那条语句（由于延迟槽，12的语句也会被执行），但是发现程序跳到了16（也就是跟没跳是一样的，即向PC寄存器写入的值实际上就是人家自增的值）

经检查，发现是ROM模块中读取使用 同步读取，造成第一条指令会在取值阶段占用两个cycle，相当于会使代码中所有代码的地址+4（因此代码中本来想跳20，结果跳到了16）

修改方式也很简单，改成异步读取就行了：

```scala
class InstRom extends Component {
  ...
  //mem.init(List.fill(16)(B("32'h34011100")))
  when(io.en){
    io.inst := mem.readAsync(io.addr.asUInt)
  }otherwise{
    io.inst := 0
  }
  ...
}
```

### BUG2 运行结果不对

具体描述：正确结果应该是：$1=0x1100,$2=0x111,$3=0,$4=0x1111,但是执行结果却是：$1=0x1100,$2=0x116,$3=0，$4=0x1116。

$3没有值，证明代码正常跳转了。但是值不正确，应该是其他指令的问题。而且J指令执行前的$2是对的，因此很可能是J指令影响了后面的指令。

经过波形图检查，发现是由于之前实现的ex,mem,wb对id的写回通道中，ID没有判断该指令是否最终会写入寄存器，而是只判断写入寄存器的地址是否与读取的相同。

```scala
  var i = 0;
  for( rnd <- List(idOut.opRnd1,idOut.opRnd2)){
    // 需要考虑，会有一些指令最后并没有写入寄存器，因此如果有这种情况，并不能使用这些指令的结果
    // 还要考虑，如果指令往$0写数据，那么这个数据也是不能用的
    when(regHeap.readEns(i)){
      rnd := regHeap.readDatas(i)
      when(exBack.writeReg && exBack.writeRegAddr===regHeap.readAddrs(i)){
        rnd := exBack.writeData
      }
      when(memBack.writeReg && memBack.writeRegAddr===regHeap.readAddrs(i)){
        rnd := memBack.writeData
      }
      when(wbBack.writeEn && wbBack.writeAddr===regHeap.readAddrs(i)){
        rnd := wbBack.writeData
      }
    }otherwise{
      rnd := imm
    }
    i+=1
  }

}
```

问题都解决之后，结果正常：

![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/cpu4.jpg
