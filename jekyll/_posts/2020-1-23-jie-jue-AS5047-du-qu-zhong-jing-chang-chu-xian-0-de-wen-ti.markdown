---
layout: post
title: 解决AS5047读取中经常出现0的问题
date: 2020-01-23 11:32:30 +0800
categories: 技术
issue_id: 70
---
这个问题去年衣容颉调马的时候有发现，当时我也跟他看了半天，没发现哪里有问题，最后是在程序里处理了一下，
一旦发现读到0，就不要那个值。

最近在调无刷电机，这个问题又出现了，一开始以为是磁铁离得太远导致的，对着磁铁一顿敲，但情况似乎没有改变。

于是将读取的寄存器从0x3FFFF（位置）改成了0x3FFFC（某个参数寄存器），这个参数寄存器和磁铁就没关系了，
不管有没有磁铁，参数应该是固定的。但读取的时候发现，这个参数也会出现读到0的情况。

怀疑是因为使用SPI轮询读取，设置超时时间是100ms，但我每次读取的时间是2ms。会不会是因为中间读取的某次
超时了？但设置了一个变量来接收每次SPI操作的返回值，如果说是超时的话，应该会返回OUTTIME的错误码的，但每次
返回的都是0(HAL_OK)。

接下来怀疑是SPI读取的问题，SPI的配置的话，2EDGE，16位读取，都没什么问题，应该不是配置的问题。

仔细看了下原来的读取时序：
- 发送读取错误寄存器(0x01)的命令（每次读取位置前要先读一下这个，以清空错误标志，如果不清空，读取位置会一直报错）
- 发送读取位置寄存器(0x3FFF)的命令，同时接收错误寄存器的值
- 接收位置寄存器的值
  
```c
uint16_t Read_Reg(uint16_t reg){
  uint16_t command=0;
  uint16_t result=0;

  static uint8_t OK=0;

  //uint8_t result[2]={0};
  //uint8_t command[2]={0x7F,0xFE};
  
  command=Command(0x01,1);
  Set_CSN(0);
  OK=HAL_SPI_Transmit(&SPI_USE,(uint8_t *)&command,1,100);
  Set_CSN(1);
  
  command=Command(reg,1);
  Set_CSN(0);
  OK=HAL_SPI_TransmitReceive(&SPI_USE,(uint8_t *)&command,(uint8_t *)&AS_5047_Err,1,100);
  Set_CSN(1);
  
  Set_CSN(0);
  OK=HAL_SPI_Receive(&SPI_USE,(uint8_t *)&result,1,100);
  Set_CSN(1);
  if(OK!=HAL_OK){
      return 0;
  }
  return result;
}
```
乍一看好像没啥问题，去年和衣容颉调的时候，我也没觉得有啥问题。今天突然发现最后一步（接收位置寄存器的值）可能有问题。

也就是
```c
OK=HAL_SPI_Receive(&SPI_USE,(uint8_t *)&result,1,100);
```
SPI协议的工作原理就是一入一出，你要从机吐出点什么，你也要给他点什么。（因为有MISO与MOSI两条线，从机不仅在MISO上输出，他也检测MOSI线上的输入）。
所以正常使用SPI应该是HAL_SPI_TransmitReceive，发送并接收。

但有时候因为接收的东西不重要，我就会调用HAL_SPI_Transmit，单纯用来发送。

发送的东西不重要，就调用HAL_SPI_Receive，单纯用来接收。那么HAL_SPI_Receive里，到底发送了什么呢？看了一下实现代码，发现他是把接收的变量发出去了。有点抽象，举例来说。

```c
HAL_SPI_Receive(&SPI_USE,(uint8_t *)&result,1,100);
```
内部实际上调用的是：
```c
HAL_SPI_TransmitReceive(&SPI_USE,(uint8_t *)&result,(uint8_t *)&result,1,100);
```
也就是说，发送和接收的指针都指向result。

那么result在还没接收到数据的时候，值为0，如果将0发送到AS5047的话，按照它的协议，这个命令是指对寄存器0x0000，写入。

但查了AS5047的手册，它并没有说明对寄存器0x0000写入会发生什么，（只说了对0x0000读取则相当于NOP操作），因此可能是一个未定义操作。

问题很可能在这了，根据这个推测，修改最后一步的代码：
```c
  command=Command(0x00,1);
  Set_CSN(0);
  OK=HAL_SPI_TransmitReceive(&SPI_USE,(uint8_t *)&command,(uint8_t *)&result,1,100);
  //OK=HAL_SPI_Receive(&SPI_USE,(uint8_t *)&result,1,100);
  Set_CSN(1);
```
直接指定要发送的数据为Command(0x00,1)(即读取0x0000寄存器的值，手册中说此操作即为NOP)。

经过测试，发现确实有效，数据0不再出现。What a fuck.

再多分析几步，如果对0x0000是个可写寄存器的话，那么按照as5047的时序，先发送写命令，接下来要发送写的数据。那么写的数据是谁呢？就是下一次要发送的   读取错误寄存器(0x01)的命令(command(0x01,1))。

也即这样的话，下一次就没有读取到错误寄存器，那么再下一步
"发送读取位置寄存器(0x3FFF)的命令，同时接收错误寄存器的值"
会发生什么呢，发送肯定是正常发送，但是接收会接收到往0x0000寄存器写入的值，也即command(0x01,1)。下一步又开始读取位置寄存器的值（并偷偷发送写0x0000寄存器的命令），似乎也没什么大问题，只要错误寄存器的没出错的话，应该是一直能接收到位置的才对。或者说，即使出问题，频率也应该是固定的，即每隔几次必有一次读到0。但我从波形中看到，出现读为0的值的频率是不固定的。

所以目前只能猜测了，0x0000并不是一个可写寄存器，对其发送写入命令的话，会引发不可知的问题。

同时，HAL_SPI_Receive我在NRF中似乎也用了，改天再去看看是否也会因此出现问题。无线手柄之前一直有出现读到0的情况，说不定真的于此有关。