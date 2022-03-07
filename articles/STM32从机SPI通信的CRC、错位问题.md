# STM32从机SPI通信的CRC、错位问题 
ctime:2021-01-20 22:11:44 +0800|1611151904

标签（空格分隔）： 技术 硬件

---

最近在调飞机，飞控需要发送电机转速命令给驱动板，使用SPI协议。之前在学校的时候我已经写好一个SPI_Slave的协议，用于STM32 主从通信。

基于该协议，可以实现主机读取、写入从机的某些变量（相当于某些SPI协议芯片的的寄存器），从而修改驱动板中关于速度等等变量，通过直接修改串口的Rx_buffer等变量，还可以实现SPI转串口，从而通过飞控直接发送串口命令给驱动板。

但回来实际使用的时候发现，稍微提高一下转速，电机就会卡住、或者疯转，总之再也无法收到SPI命令。但是如果低速或者不变速运行，不会发生错误。

于是这两天都在调试这个问题。

一开始我以为是我的协议过于臃肿了，毕竟为了实现读取某个变量，需要主机先发送要读|写的变量Index，然后发送要写入的指或者接收从机发来的数据。而主控发送一个封包，需要修改占空比、相位、加减速占空比三个变量，每修改一个变量之间还需要一定的延时。
又或者是CSN拉低之后，等待的时间太少就直接发起通信了，从机还没反应过来。

基于这些猜测，我重新写了个SPI_Slave_Fast，直接使用固定长度的13字节封包来进行通信。从机也就是驱动板使用SPI的DMA来发送和接收，主机直接使用轮询发送接收。但是测试后发现问题依旧，只是SPI出错后，不会疯转了，电机直接停止（也不是卡住）。

由于想要保证驱动板接收的命令或者数据的正确性，我开启了CRC校验，出现这个问题后，以为是CRC校验错了，导致什么不可恢复。于是先将CRC去掉了，问题依旧。猜测是否是发生了溢出（OVR），因为调试的时候发现进入SPI中断的时候，溢出标志位都为1，据手册讲，如果发生了溢出，在清除溢出标志位之前，DR寄存器的值不会更新。尽管在HAL库的SPI中断已经清除了标志位，还是开始在各种地方疯狂清除溢出标志位，收效甚微。后面分析应该不是发生了OVR，调试的时候发生OVR是因为单步调试使DR寄存器来不及读出，从而导致溢出。全速跑的时候在SPI中断打了log也支持这一推理。

排除溢出后，突然想到之前在STM32 SPI DMA CRC等关键词时，有人提到错位的问题。仔细思考了一下，发现极有可能是这个问题。在无CRC的情况下，多接收或者少接收了几个SCLK。假设一共要收13个字节，从机多收了几个SCLK，那么在13个字节还没收完的时候，它就觉得自己收完了，开始触发DMA完成中断。而我在DMA完成中断中又开启DMA的下一轮接收，因此周而复始，会永远多收了几个SCLK，导致数据不对。

开始搜索相关问题，发现有相同问题的人不少，但是鲜有人提出解决方法。

ST中文社区的一个哥们给了我不少启发，原帖地址：
https://www.stmcu.org.cn/module/forum/thread-611901-1-1.html

根据之前的分析，不能直接在DMA完成的时候直接又把DMA开了，因为此时可能已经多收或者漏收了几个SCLK。需要在发现数据错误的时候进行恢复，恢复完再重开DMA。如果不开CRC的话，是无法方便发现数据错误的，可能只能在机毁人亡的时候才发现。而开启CRC的话，数据不对会触发SPI错误中断。因此在错误中断回调中稍微立了个标志位：

```c
static uint8_t SPI_Slave_Err=0;
void HAL_SPI_ErrorCallback(SPI_HandleTypeDef *hspi){
  if(hspi->Instance==SPI1){
      uprintf("CRC!\r\n");
      __HAL_SPI_CLEAR_CRCERRFLAG(hspi);
      __HAL_SPI_CLEAR_OVRFLAG(hspi);   // 在HAL的SPI中断中实际上已经处理过了，但是有可能清空OVR后关闭中断前，又来SPI数据，导致又溢出了，因此这里需要再清一下
      SPI_Slave_Err=1;   // 主要是立个标志，让我们知道数据错了
      return ;
  }
}
```

在CSN的中断中处理错误
```c
void SPI_Slave_Fast_CSN_Handler(uint8_t flag){
    //flag 代表是上升沿中断(1)还是下降沿中断(0)
    if(flag){
        if(SPI_Slave_Err){
            while(__HAL_SPI_GET_FLAG(&hspi1,SPI_FLAG_BSY)!=RESET);  // 必须在SPI没在通信的过程中处理，否则下次还是错误
            HAL_SPI_DeInit(&hspi1);
            HAL_SPI_Init(&hspi1);
            __HAL_SPI_CLEAR_OVRFLAG(&hspi1);
            HAL_SPI_TransmitReceive_DMA(SPI_Use,Tx_Buffer,Rx_Buffer,13);
            SPI_Slave_Err=0;
            return ;
        }
        FOC_Flag = Rx_Buffer[0];
        memcpy(&Base_Duty,Rx_Buffer+1,4);
        memcpy(&Duty_Amp,Rx_Buffer+1+4,4);
        memcpy(&Phi,Rx_Buffer+1+4+4,4);
        TX_Data_Install();
        HAL_SPI_TransmitReceive_DMA(SPI_Use,Tx_Buffer,Rx_Buffer,13);
        //uprintf("n");
        //uprintf("%d %f %f %f \r\n",FOC_Flag,Base_Duty,Duty_Amp,Phi);
    }
}
```

这样修改之后，就能从SPI错位错误中恢复过来了。

再分析之前用SPI_SLAVE协议为什么是疯转，而SPI_SLAVE_FAST协议是直接停止。主要原因是SPI_SLAVE_FAST中，第一个字节来标志电机的启动，为1就启动，为0就停止。如果为0，那么后面发的什么东西都无所谓了。而发生错位错误的话，基本上就是把1给移位移到后面去了，导致第一个字节收的都是0，于是电机就停了。

而SPI_SLAVE协议中，电机启动和停止只在某个地方启动停止一次，之后就单纯修改占空比等等了，因此收到错误数据疯转很正常。

留念一下当时的分析草稿，当时万念俱灰，都没心思好好写字了。

![此处输入图片的描述][1]

[1]: https://raw.githubusercontent.com/Ncerzzk/MyBlog/master/img/stm32crc.jpg




