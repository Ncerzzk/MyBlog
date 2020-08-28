---
layout: post
title: Python元编程 
date: 2020-03-19 22:47:37 +0800
categories: 技术
issue_id: 90
---

元编程其实Ruby比较出名，因为Ruby的语法糖实在太多了，而且Ruby的对象模型比Python纯净，因此经常来说用Ruby来作为元编程的介绍。

之前用Python写无人机的仿真，为了写得舒服一点，在里面也实现了一些元编程的东西，这里记录一下。

- 调用父类的某函数：`super().__init__()`调用父类的初始化函数。
- 运算符重载
  - Python的运算符重载比较麻烦，按照定义为特定的函数名，如+的运算符函数为`__add__(self,other)`,还有`__radd__(self,other)`,与add的区别是，本函数中,other是作为+的第二个操作数的。当调用+函数的时候，Python会先调用第一个函数的`__add__()`,如果找不到，就调用第二个操作数的`__radd__()`。关于加法，还有一个`__iadd__(self,other)`,该函数重载的是+=。需要注意的是，本函数定义的时候要仔细考虑一下要返回一个新对象还是在源对象基础上做更改。
- 其他运算的操作也跟+差不多，就不一一列举了。

- `__getattr__(self,name)` 和 `__setattr__(self,name,value)`,这两个函数用于定义给对象的属性赋值的情况。需要注意的是，`__getattr__`会在对象找不到某个方法或者属性是调用，可以用来实现元编程中的Missing Method。 `__setattr__`则在每次对属性赋值的时候调用，需要注意，即使在__init__对属性赋值，也是会调用__setattr__的。

- 实现像Ruby那样，方法即属性。如在Ruby中写`Obj.x`，是不需要知道x到底是一个方法还是一个属性的。Python也可以实现，可以在类中定义一个`def x(self)`函数。默认情况下，如果要调用这个函数，需要使用`Obj.x()`才能调用。那么可以在函数定义上面，加上`@property`,则可以直接使用`Obj.x`来调用。

- 重定义某属性的赋值函数。在Ruby中的写法是` def x=(value) `,在Python中是定义一个`def x(self,value)`，同时在上面加上`@x.setter`

- Python的类初始化顺序，首先是调用`__new__`函数，调用完之后，会生成一个对象，但此时类的属性都还没初始化。在__new__函数中，会再调用`__init__(self)`函数，其中self这个参数传进去的就是刚生成的对象。
  - 例子：在仿真中，写了一个Vector3，是三维的矢量类，为了不自己实现矩阵的运算，让它继承了numpy.ndarray。正常来说作为子类，是调用父类的__init__来初始化，但是numpy.ndarray的初始化直接在__new__完成了，它并没有写__init__函数（可以在其手册找到关于这个的说明），因此我们也只要重写__new__就行，至于__init__，就用Object类的就行，我们不用管。
    ```
      def __new__(cls, *args, **kwargs):
        buffer=np.array(args[0],dtype=np.float)
        return super().__new__(cls,(3,),buffer=buffer)

    def __eq__(self, other):
        return super(object).__eq__(other)
    ```
    - 附带实现了一个__eq__函数，因为numpy中判断矩阵是否相等，是没有用==函数的，必须用.all或者.any，来判断到底使矩阵完全一样，还是只要有一个元素一样。但我只想判断是否是同一个对象，因此直接调用Object的__eq__就行了。


适当使用元编程的思想，还是可以让Python写起来很快乐的。

例子可以看看：https://github.com/Ncerzzk/UAV_Sim/blob/master/physics.py

