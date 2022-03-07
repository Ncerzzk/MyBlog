# SpinalHDL学习
ctime:2020-06-13 22:08:06 +0900|1592053686

标签（空格分隔）： 技术 HDL

---

SpinalHDL是Scala的一个用于描述硬件的方言，与chisel类似，但听说设计会比chisel完备一点，
因此准备花一些时间来学习一下。

专门学习了一下scala的语法，走马观花看了一圈，挺复杂的，从很多语言中学习了很多特性。有关函数式编程的一些概念，之前接触得也不多，不太懂，其他面向对象的东西与ruby有很多地方十分相似。

开始学习SpainaHDL的时候，发现了挺多语法在原生的Scala中是没有的，因为Scala的自由性，所以自定义一些控制结构是完全可能的，偏偏我这个人好奇心又重，总想搞明白某些DSL的语法是怎么用Scala实现的，因此下面对于一些重要的SpinaHDL语法，除了搞明白用途以外，也会想想是怎么实现的。因为时间有限，大部分权作为猜测，等以后有时间好好学一下Scala的时候，再验证是不是吧。

## SpainaHDL 执行流程大致分析

- 在main中，调用SpinalVerilog,（传入顶层类的一个对象）（实际上传入的是一个方法gen，这个方法实例化顶层对象）
  
   ```scala
   object SpinalVerilog {
  def apply[T <: Component](config: SpinalConfig)(gen: => T): SpinalReport[T] = Spinal(config.copy(mode = Verilog))(gen)
  def apply[T <: Component](gen: => T): SpinalReport[T] = SpinalConfig(mode = Verilog).generate(gen)
    }
   ```
 
- 接下来会调用SpinalConfig的generate方法，并将gen传入,这是一个case Class,实例化不需要使用new，并指定mode为Verilog。
  - 这里的Verilog是单例对象，在文件开头有定义
  
    ```scala
    object VHDL    extends SpinalMode
    object Verilog extends SpinalMode
    object SystemVerilog extends SpinalMode
    ```

- generate方法：
  
  ```scala
    def generate       [T <: Component](gen: => T): SpinalReport[T] = Spinal(this)(gen)
  ```

- Spinal是一个单例对象(object),在applay方法中，判断语言类型（是VHDL还是verilog）
  
    ```scala
    val report = configPatched.mode match {
      case `VHDL`    => SpinalVhdlBoot(configPatched)(gen)
      case `Verilog` => SpinalVerilogBoot(configPatched)(gen)
      case `SystemVerilog` => SpinalVerilogBoot(configPatched)(gen)
    }
    ```
   
- SpinalVerilogBoot 继续是一个单例对象
  
    ```scala
        singleShot(config)(gen)
    ```
  ```scala
    def singleShot[T <: Component](config: SpinalConfig)(gen : => T): SpinalReport[T] ={

    val pc = new PhaseContext(config) // 这里创建了上下文，上下文主要是为了模块嵌套的时候，防止名称冲突
    pc.globalData.phaseContext = pc
    pc.globalData.anonymSignalPrefix = if(config.anonymSignalPrefix == null) "_zz" else config.anonymSignalPrefix

    ...

    SpinalProgress("Elaborate components")

    val phases = ArrayBuffer[Phase]()

    // 以下开始创建一堆任务
    phases += new PhaseCreateComponent(gen)(pc)
    phases += new PhaseDummy(SpinalProgress("Checks and transforms"))
    ...
    ...
    for(phase <- phases){
      if(config.verbose) SpinalProgress(s"${phase.getClass.getSimpleName}")
      pc.doPhase(phase)
    }
    ...
  }
  ```
  

## 一些基本的SpinaHDL例子

### 生成HDL

```scala
class MyAdder(width: BitCount) extends Component {
  val io = new Bundle{
    val a,b    = in UInt(width)
    val result = out UInt(width)
  }
  io.result := io.a + io.b
}

object Main{
  def main(args: Array[String]) {
    SpinalVhdl(new MyAdder(32 bits))
  }
}
```


### 模块定义，输入输出

```scala
class MyComponent extends Component {
 val io = new Bundle {
 val a = in Bool
 val b = in Bool
 val c = in Bool
 val result = out Bool
 }
 io.result := (io.a & io.b) | (!io.c)
}


```
- in和out是单例对象，继承了IODirection的特质
  ```scala
  trait IODirection extends BaseTypeFactory {
    ...
    override def Bool() = applyIt(super.Bool())
    ...
  }
  ```
- bool是IODirection的方法，因此`in bool`相当于定于了一个bool类型的对象，且这个对象方向是`in`（这个方向在综合或者什么地方会用到）
 

### 组合逻辑 选择器

```scala
class MyComponent extends Component {
    val io = new Bundle {
        val conds = inVec(Bool, 2) val result = out UInt(4 bits)

    }
    when(io.conds(0)) {
        io.result: =2 when(io.conds(1)) {
            io.result: =1

        }
    }
    otherwise {
        io.result: =0

    }
}
```
-  这里有个很有趣的语法`4 bits`
   -  bits是IntBuilder类的一个方法，作用是生成Bitcount对象
      ```scala
        class IntBuilder(val i: Int) extends AnyVal {
          ...
          def bits   = new BitCount(i)
          ...
        }
      ```
  - 上面的`4 bits`实际上省略了点号，可以写成`4.bits`，但是有一个问题，因为4是Int类的，为何可以调用IntBuilder类的方法呢？答案在于scala的隐式转换中。
    - 在同文件中，定义了
      ```scala
        implicit def IntToBuilder(value: Int): IntBuilder = new IntBuilder(value)
      ```
    - 有了这个隐式转换，scala会自动将Int类转为IntBuilder类（如果有需要的话）
  - 通过上面说的这些方式，实现了`4 bits`这个程序员看起来有点奇怪，但是可读性非常强的语法。scala真是强阿。
- when语法，实际上when是一个单例对象，是通过scala的语法自定义的控制结构。
  ```scala
  object when {

  def apply(cond: Bool)(block: => Unit): WhenContext = {

    val whenStatement = new WhenStatement(cond)
    val whenContext   = new WhenContext(whenStatement)

    cond.globalData.dslScope.head.append(whenStatement)

    whenStatement.whenTrue.push()
    block
    whenStatement.whenTrue.pop()

    whenContext
  }
  }
  ```
  - 在scala中，有两个参数分别用括号括起来，表示curry化。
  - 如果只有一个参数的话，可以使用大括号来代替小括号，从而更接近于一个原生的控制结构，如
    ```scala
    if(cond){
      ...
    }
    ```
  - when最后返回的`whenContext`是一个`WhenContext`类型，这个类型中还有一个方法叫做`otherwise`，很巧妙地构成了整个控制结构。

### 惰性赋值
```scala
val a, b, c = UInt(8 bits) // Define 3 combinatorial signals
c := a + b   // c will be set to 7
b := 2       // b will be set to 2
a := b + 3   // a will be set to 5
```

和

```scala
val a, b, c = UInt(8 bits) // Define 3 combinatorial signals
b := 2     // b will be set to 2
a := b + 3 // a will be set to 5
c := a + b // c will be set to 7
```

是等效的，因为比如`c := a+b` 并没有立刻计算出值，此时也算不出值，而只是将a+b这个函数赋值给c，等到之后再计算。
