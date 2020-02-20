---
layout: post
title: STM32同步定时器并触发ADC_DMA多路采样
date: 2019-05-05 17:53:06 +0900
categories: 技术 硬件
issue_id: 0
---
需求是这样的：

做电机驱动，需要采集电压和电流的时候，由于H桥驱动管以16K的频率再开关，如果随意进行ADC采样的话，会采到MOS关断时候的电压值和电流值，对整个电压和电流的估计造成影响。最好的情况就是在PWM为高电平，也就是MOS导通的时候，采集相应的电压和电流。

那么实现方式就是用定时器来触发ADC进行采样，而这个定时器又必须与发出PWM波的定时器计数是同步的，假设驱动电机的定时器为TIM2，那么用TIM4作为从定时器，TIM4另外发出一路PWM波来触发ADC采样。

假设此时驱动电机的占空比为50%，那么TIM4发出的PWM波占空比应该是25%（在高电平的中间采样），同时由于ADC是上升沿触发，因此需要将TIM4的PWM波极性反一下，直接设置为PWM_MODE_2即可。

思路就是这样，接下来开始配置：

### ADC配置：
```
void MX_ADC1_Init(void)
{
  ADC_ChannelConfTypeDef sConfig;

    /**Configure the global features of the ADC (Clock, Resolution, Data Alignment and number of conversion) 
    */
  hadc1.Instance = ADC1;
  hadc1.Init.ClockPrescaler = ADC_CLOCK_SYNC_PCLK_DIV4;
  hadc1.Init.Resolution = ADC_RESOLUTION_12B;
  hadc1.Init.ScanConvMode = ENABLE;           //有多路需要采集的话，这里要enable
  hadc1.Init.ContinuousConvMode = DISABLE;    //必须设置为disable，否则只有第一次是TIM4 触发，接下来都是自动触发
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConvEdge = ADC_EXTERNALTRIGCONVEDGE_RISING;      // 上升沿采集
  hadc1.Init.ExternalTrigConv = ADC_EXTERNALTRIGCONV_T4_CC4;              // 设置为TIM4-CH4触发
  hadc1.Init.DataAlign = ADC_DATAALIGN_RIGHT;
  hadc1.Init.NbrOfConversion = 2;
  hadc1.Init.DMAContinuousRequests = ENABLE;
  hadc1.Init.EOCSelection = ADC_EOC_SEQ_CONV;
  if (HAL_ADC_Init(&hadc1) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

    /**Configure for the selected ADC regular channel its corresponding rank in the sequencer and its sample time. 
    */
  sConfig.Channel = ADC_CHANNEL_11;
  sConfig.Rank = 1;
  sConfig.SamplingTime = ADC_SAMPLETIME_15CYCLES;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }
      /**Configure for the selected ADC regular channel its corresponding rank in the sequencer and its sample time. 
    */
  sConfig.Channel = ADC_CHANNEL_5;
  sConfig.Rank = 2;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }
}
```
  
### DMA配置
```
    hdma_adc1.Instance = DMA2_Stream0;
    hdma_adc1.Init.Channel = DMA_CHANNEL_0;
    hdma_adc1.Init.Direction = DMA_PERIPH_TO_MEMORY;
    hdma_adc1.Init.PeriphInc = DMA_PINC_DISABLE;
    hdma_adc1.Init.MemInc = DMA_MINC_ENABLE;
    hdma_adc1.Init.PeriphDataAlignment = DMA_PDATAALIGN_HALFWORD;
    hdma_adc1.Init.MemDataAlignment = DMA_MDATAALIGN_HALFWORD;
    hdma_adc1.Init.Mode = DMA_CIRCULAR;     // 这里设置为DMA_CIRCULAR，就不必在一次采样完成后再开DMA了
    hdma_adc1.Init.Priority = DMA_PRIORITY_HIGH;
    hdma_adc1.Init.FIFOMode = DMA_FIFOMODE_DISABLE;
    if (HAL_DMA_Init(&hdma_adc1) != HAL_OK)
    {
      _Error_Handler(__FILE__, __LINE__);
    }

    __HAL_LINKDMA(adcHandle,DMA_Handle,hdma_adc1);
    
```
    
    **另外，如果设置DMA_CIRCULAR，建议在dma.c中，将ADC的DMA中断关闭，否则的话，采样完成后会不断进入中断，这里是用PWM触发，频率是16K，也不是很快，影响不大，但之前我是软件触发，一旦触发DMA就一直在循环地采样，然后进入中断，整个程序大部分时间会都浪费在进入中断上。毕竟ADC采样一次才1us(最快）**
    
    配置结束后，开启DMA：
```
void ADC_Start(){
  HAL_ADC_Start_DMA(&hadc1,(uint32_t *)ADC_Values_Raw[0],ADC_NUM);
  HAL_ADC_Start_DMA(&hadc2,(uint32_t *)ADC_Values_Raw[1],ADC_NUM);
  HAL_ADC_Start_DMA(&hadc3,(uint32_t *)ADC_Values_Raw[2],ADC_NUM);
}
/*
    以上函数执行后不会马上开始ADC采样，会等TIM4——CH4的信号。
*/
```

### 定时器配置
#### TIM2 (电机驱动的定时器）
```
/* TIM2 init function */
void MX_TIM2_Init(void)
{
  TIM_MasterConfigTypeDef sMasterConfig;
  TIM_OC_InitTypeDef sConfigOC;
  TIM_ClockConfigTypeDef sClockSourceConfig;
  
  htim2.Instance = TIM2;
  htim2.Init.Prescaler = 0;
  htim2.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim2.Init.Period = 5187;
  htim2.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  if (HAL_TIM_PWM_Init(&htim2) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  sMasterConfig.MasterOutputTrigger = TIM_TRGO_ENABLE;      // 开启使能触发模式（使用使能信号触发从定时器）
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_ENABLE;   // 作为主定时器
  if (HAL_TIMEx_MasterConfigSynchronization(&htim2, &sMasterConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }
  
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim2, &sClockSourceConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }
  
  sConfigOC.OCMode = TIM_OCMODE_PWM1;
  sConfigOC.Pulse = 0;
  sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
  sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_1) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_2) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_3) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  HAL_TIM_MspPostInit(&htim2);
  //HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_1);   //注意，这里先别开启PWM，因为一开PWM就把计数器打开了。必须等两个定时器都初始化完毕之后，再开
  //HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_2);
  //HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_3);
}
```

#### TIM4（触发ADC的从定时器）
```
/* TIM4 init function */
void MX_TIM4_Init(void)
{
  TIM_ClockConfigTypeDef sClockSourceConfig;
  TIM_SlaveConfigTypeDef sSlaveConfig;
  TIM_MasterConfigTypeDef sMasterConfig;
  TIM_OC_InitTypeDef sConfigOC;

  htim4.Instance = TIM4;
  htim4.Init.Prescaler = 0;
  htim4.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim4.Init.Period = 5187;
  htim4.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  if (HAL_TIM_Base_Init(&htim4) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim4, &sClockSourceConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  if (HAL_TIM_PWM_Init(&htim4) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  sSlaveConfig.SlaveMode = TIM_SLAVEMODE_GATED;   //设置为门控模式，也可以是触发模式，不过门控模式的话是 开始和停止都由主定时器控制
  sSlaveConfig.InputTrigger = TIM_TS_ITR1;  // 具体选择哪个ITR得根据参考手册
 
  if (HAL_TIM_SlaveConfigSynchronization(&htim4, &sSlaveConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim4, &sMasterConfig) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  sConfigOC.OCMode = TIM_OCMODE_PWM2;      // 设置为PWM2，用于反置PWM极性
  sConfigOC.Pulse = TIM4->ARR*0.15;        // 设置为15%占空比，因为我测试电机用的是30%占空比
  sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
  sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
  if (HAL_TIM_PWM_ConfigChannel(&htim4, &sConfigOC, TIM_CHANNEL_4) != HAL_OK)
  {
    _Error_Handler(__FILE__, __LINE__);
  }

  HAL_TIM_MspPostInit(&htim4);
  //HAL_TIM_PWM_Start(&htim4,TIM_CHANNEL_4);   // 同样，这里也不能开始PWM
}
```

#### 开启同步
```
  TIM4->CR1|=TIM_CR1_CEN;    // 使用门控模式之前，必须手动把CEN置1，触发模式不用
  
  HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_1);    // 在这里开启计数器，此时两个定时器会同步开始计数
  HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_2);
  HAL_TIM_PWM_Start(&htim2,TIM_CHANNEL_3);
  
  HAL_TIM_PWM_Start(&htim4,TIM_CHANNEL_4);
```

### 注意
如果要测试是否同步的话，可以用
```
TIM2->CR1&=~TIM_CR1_CEN;
```
将定时器2停止，然后此时用IDE调试到这一句，观察两个定时器CNT寄存器的值。
**不可以直接暂停来看CNT，因为这样看怎么都是不一样的。**


