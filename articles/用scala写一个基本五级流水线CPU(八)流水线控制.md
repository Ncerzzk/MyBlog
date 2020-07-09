# 用scala写一个基本五级流水线CPU(八)流水线控制
ctime:2020-07-09 19:29:45 +0900|1594290585

标签（空格分隔）： 技术 硬件

---

总有一种问题越写越多的感觉呢。

## 遗留的冒险问题

之前遗留的冒险问题还有：

- load的数据相关
  
    ```c
    load $1,0($0)
    addiu $2,$1,100
    ```

    类似于这样的问题，addiu需要在执行级的时候确定操作数（来自于ID或者来自于旁路），但是此时$1的值还没准备好，因为load的指令要在mem的后期才能取得值。

    简单来说，以目前实现(改版后）的流水线而言，如果两个数据相关的指令相邻，那么上一条指令必须在EX结束前就得到计算结果，下一条指令才可以直接通过旁路获取到。

    - 解决方式：在第二条指令的译码阶段增加相关性判断，如果与上一条一句有相关性，那么就插入一条空指令，并将前级的流水线暂停1个周期，这样就可以将相邻的指令，变成了1 gap 指令，就可以正常取得值了
  
- 分支指令实现问题
  - 之前分支指令如beq等，为了不在流水线中加入空泡（nops），将分支的跳转提前到了ID中来实现（参考《自己动手写CPU》），但是由于旁路的修改的，在ID阶段已经不能获取到旁路了，也就无法进行分支判断。
    - 解决方法：修改beq等指令的实现：将其跳转判断放到EX中，同时一旦预测失败，将IF/ID中取得指令清除（变成空泡）。

## 实现

从上面的分析可以知道，我们需要一个流水线控制器来控制流水线（暂存级）的运行、暂停、或者清除。流水线控制器还在什么地方用到呢，比如除法这种多周期指令（目前还没实现）执行的时候，需要将前级暂停下来，等他表演完。还比如用在缓存未命中的时候（目前还没使用缓存，或者说目前的缓存百分百命中，一个周期就可以读出数据），需要通过总线控制器（目前还没用到总线）向内存读取，此时就要将流水线暂停起来，

先定义一组流水线的运行状态枚举:(有三种状态，分别为清除、暂停、和正常启用)

```scala
object StageStateEnum extends SpinalEnum(binaryOneHot){
  val FLUSH,STALL,ENABLE = newElement()
}
```

再定义一组流水线控制请求的枚举： （这些定义不会马上全部用到，但先定义着，可能以后也会再修改）

```scala
object StageCTRLReqEnum extends SpinalEnum{
  val NORMAL = newElement()
  val IFSTALL,IDSTALL,EXSTALL,MEMSTALL=newElement()
  val IFFLUSH,IDFLUSH,EXFLUSH=newElement()
}
```

再定义两种端口,分别是控制请求发起的端口（放在ID模块、EX模块中）、暂存级的控制端口（放在流水线的暂存级中以及PC寄存器，如if2id这些）

```scala
class StageCTRLReqBundle extends Bundle with IMasterSlave{
  val req = StageCTRLReqEnum()

  override def asMaster(): Unit = {
    out (req)
  }
}

class StageCTRLBundle extends Bundle with IMasterSlave{
  val stateOut = StageStateEnum()

  override def asMaster(): Unit = {
    out(stateOut)
  }
}
```

流水线控制器的实现：

```scala

class StageCTRL extends Component{
  val slaves = Vec(master(new StageCTRLBundle()),4)
  val reqFromID= slave(new StageCTRLReqBundle())
  val reqFromEX= slave(new StageCTRLReqBundle())

  def <>(a:List[StageCTRLBundle]):Unit={
    // 顺序应该是 PC，IF2ID,ID2EX,EX2MEM
    // 不能放错误顺序
    for(i <- a.indices){
      a(i) <> slaves(i)
    }
  }

  def <>(ex:EX)=reqFromEX <> ex.reqCTRL
  def <>(id:ID)=reqFromID <> id.reqCTRL

  slaves.foreach(s=>s.stateOut:=StageStateEnum.ENABLE)
  val req = (reqFromEX.req === StageCTRLReqEnum.NORMAL) ?reqFromID.req | reqFromEX.req 
  when(req === StageCTRLReqEnum.IFFLUSH){
    slaves(1).stateOut := StageStateEnum.FLUSH
  }elsewhen(req === StageCTRLReqEnum.IDSTALL){
    slaves(0).stateOut := StageStateEnum.STALL
    slaves(1).stateOut := StageStateEnum.STALL
    slaves(2).stateOut := StageStateEnum.FLUSH
  }
}
```

目前还仅实现了几种情况，等需要的时候再继续加吧。在PC、Stage（各个流水线暂存级）中增加流水线控制接口，在ID、EX中增加流水线控制请求接口就省略了，还挺累的。


### 解决LOAD的相关性问题

在ID中检测本条指令与上条指令的一些信息来判断是否相关。上条指令的信息来自于EX模块。一旦发现是LOAD，且有相关性，就暂停到ID的流水线（PC、IF2ID暂停，ID2EX清空（注意这里必须是清空，如果只是暂停，就会导致上一条LOAD指令永远执行））

```scala
  when(lastInstInfo.op===OpEnum.LOAD.asBits.resized){
    when(lastInstInfo.writeAddr === regHeap.readAddrs(0) || lastInstInfo.writeAddr===regHeap.readAddrs(1)){
      reqCTRL.req := StageCTRLReqEnum.IDSTALL
    }
  }
```

### 将分支语句挪到EX级

```scala
if(i._1 == OpEnum.BRANCH) {
              when(func(oprnd1,oprnd2).asInstanceOf[Bool]){
                val target= (inst.immI.asSInt.resize(GlobalConfig.dataBitsWidth)+lastStage.pc.asSInt+1).asBits
                pcPort.JMP(target)
                reqCTRL.req := StageCTRLReqEnum.IFFLUSH
}
```

## 测试

修改完后对之前提到的两个问题挨个进行测试。

### load数据相关问题
```c
	LBU $1,01($0)
	addiu $2,$1,100
```

![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/loadproblem.jpg

可以看到在第一条指令后插入了NOPS。

最后的结果是355(十进制)（内存默认填充了0xFFFF）


### beq在ID无法获取操作数问题

```c
    addiu $1, $0, 0x1100
    b 2
    addiu $2, $0, 0x0111
    and   $3, $1 ,$2
    or    $4, $1, $2
```

![此处输入图片的描述][2]

[2]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/beq.jpg

可以看到结果与以前一样，and指令被跳过，所以$3没有值。可以观察跳转指令的延迟槽之后有个空泡（Nops）。
