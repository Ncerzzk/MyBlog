---
layout: post
title: STM32使用DMA来接收不定长的串口信息
date: 2018-03-23 20:13:16 +0800
categories: 技术 硬件
issue_id: 29
---
使用HAL库。

首先是串口DMA初始化：(实际上，如果使用QubeMX来生成代码的话，串口DMA会自动帮你配置好的）

```c
    DMA_HandleTypeDef hdma_usart6_rx;
    hdma_usart6_rx.Instance = DMA2_Stream1;
    hdma_usart6_rx.Init.Channel = DMA_CHANNEL_5;
    hdma_usart6_rx.Init.Direction = DMA_PERIPH_TO_MEMORY;
    hdma_usart6_rx.Init.PeriphInc = DMA_PINC_DISABLE;
    hdma_usart6_rx.Init.MemInc = DMA_MINC_ENABLE;
    hdma_usart6_rx.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
    hdma_usart6_rx.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
    hdma_usart6_rx.Init.Mode = DMA_NORMAL;
    hdma_usart6_rx.Init.Priority = DMA_PRIORITY_MEDIUM;
    hdma_usart6_rx.Init.FIFOMode = DMA_FIFOMODE_DISABLE;
    
    if (HAL_DMA_Init(&hdma_usart6_rx) != HAL_OK)
    {
      _Error_Handler(__FILE__, __LINE__);
    }

    __HAL_LINKDMA(uartHandle,hdmarx,hdma_usart6_rx);
    
```
在串口初始化中，应该增加使能**空闲**(IDLE）中断，当串口接收到一个空闲帧（全是1），会触发此中断。
```c
    __HAL_UART_ENABLE_IT(&huart6,UART_IT_IDLE);
```

串口初始化完毕后，开启DMA接受串口中断：
```c
HAL_UART_Receive_DMA(&huart6, (uint8_t *)buffer_rx, 30);
```
应该注意的是，这句话能放在串口初始化函数的过程中，必须等串口的State为Ready之后，才能执行这句话，否则当串口状态为Busy时，是无法启动DMA的。


在中断中，新增：
```c
/**
* @brief This function handles DMA2 stream1 global interrupt.
*/
void DMA2_Stream1_IRQHandler(void)
{
  /* USER CODE BEGIN DMA2_Stream1_IRQn 0 */

  /* USER CODE END DMA2_Stream1_IRQn 0 */
  HAL_DMA_IRQHandler(&hdma_usart6_rx);
  /* USER CODE BEGIN DMA2_Stream1_IRQn 1 */

  /* USER CODE END DMA2_Stream1_IRQn 1 */
}
```
这是DMA接收完成后会触发的中断，因为接收的是不定长的信息，如果超过预定的buffer长度后，会调用这个函数来进行结束DMA传输。正常情况下不会调用到这个函数，因为DMA还没传到设定的buffer长度就被终止了。(由串口的**空闲**与否，判断本次信息是否传递完毕）

在串口中断中，判断是否为IDLE中断：
```c
void USART6_IRQHandler(void)
{
  /* USER CODE BEGIN USART6_IRQn 0 */

  /* USER CODE END USART6_IRQn 0 */
  if(__HAL_UART_GET_FLAG(&huart6, UART_FLAG_IDLE) != RESET){
    HAL_UART_IDLECallback(&huart6);
    return ;
  }
}
```
其中``` HAL_UART_IDLECallback(&huart6);```是自定义的一个串口空闲中断的回调函数，可以不定义这个函数，直接把处理细节写在这里。但为了程序的美观，另外写个函数处理。

```c
void HAL_UART_IDLECallback(UART_HandleTypeDef *huart){
  uint8_t temp;
  __HAL_UART_CLEAR_IDLEFLAG(huart);   //清除函数空闲标志
  if(huart->Instance==USART6){
    HAL_UART_DMAStop(&huart6);      //停止本次DMA
    analize(buffer_rx);             //处理接受到的信息
    
    temp= huart->Instance->SR;
    temp= huart->Instance->DR;//读出串口的数据，防止在关闭DMA期间有数据进来，造成ORE错误
    huart->hdmarx->XferCpltCallback(huart->hdmarx); 调用DMA接受完毕后的回调函数，最主要的目的是要将串口的状态设置为Ready，否则无法开启下一次DMA
    HAL_UART_Receive_DMA(&huart6,(uint8_t *) buffer_rx, 30);
  }
  
}
```


