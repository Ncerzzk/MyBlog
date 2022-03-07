# VESC测量电感的方式分析
ctime:2021-01-04 14:40:21 +0800|1609742421

标签（空格分隔）： 技术 硬件

---

测量程序入口：

```c
bool mcpwm_foc_measure_res_ind(float *res, float *ind) {
	const float f_sw_old = m_conf->foc_f_sw;
	const float kp_old = m_conf->foc_current_kp;
	const float ki_old = m_conf->foc_current_ki;

	m_conf->foc_f_sw = 10000.0;
	m_conf->foc_current_kp = 0.001;
	m_conf->foc_current_ki = 1.0;

	uint32_t top = SYSTEM_CORE_CLOCKA / (int)m_conf->foc_f_sw;
	TIMER_UPDATE_SAMP_TOP(MCPWM_FOC_CURRENT_SAMP_OFFSET, top);

	float i_last = 0.0;
    // 测量出一个大致的期望电流
    // 这个期望电流大概是在1V的电压下，电机的电流（无反电动势）
	for (float i = 2.0;i < (m_conf->l_current_max / 2.0);i *= 1.5) {
		if (i > (1.0 / mcpwm_foc_measure_resistance(i, 20))) {
			i_last = i;
			break;
		}
	}

	if (i_last < 0.01) {
		i_last = (m_conf->l_current_max / 2.0);
	}

#ifdef HW_AXIOM_FORCE_HIGH_CURRENT_MEASUREMENTS
	i_last = (m_conf->l_current_max / 2.0);
#endif

    // 用刚刚测量出的期望电流去测量电阻和电感，第二个参数是采样次数
	*res = mcpwm_foc_measure_resistance(i_last, 200);
	*ind = mcpwm_foc_measure_inductance_current(i_last, 200, 0);

	m_conf->foc_f_sw = f_sw_old;
	m_conf->foc_current_kp = kp_old;
	m_conf->foc_current_ki = ki_old;

	top = SYSTEM_CORE_CLOCK / (int)m_conf->foc_f_sw;
	TIMER_UPDATE_SAMP_TOP(MCPWM_FOC_CURRENT_SAMP_OFFSET, top);

	return true;
}
```

接下来,跳进主要函数mcpwm_foc_measure_inductance_current里看看：

```c
float mcpwm_foc_measure_inductance_current(float curr_goal, int samples, float *curr) {
	const float f_sw_old = m_conf->foc_f_sw;
	m_conf->foc_f_sw = 3000.0;  // 注意这里FOC的频率变成了3k

	uint32_t top = SYSTEM_CORE_CLOCK / (int)m_conf->foc_f_sw;
	TIMER_UPDATE_SAMP_TOP(MCPWM_FOC_CURRENT_SAMP_OFFSET, top);

	float duty_last = 0.0;
    // 注意这里的i 并不是指代电流，而是指占空比
    // 这里占空比从2%开始递增，到50%结束，每次增大1.5倍
    // 如果电机电流大于上面给的期望电流，那么就跳出，保存此时的占空比作为期望占空比
	for (float i = 0.02;i < 0.5;i *= 1.5) { 
		float i_tmp;
		mcpwm_foc_measure_inductance(i, 10, &i_tmp);

		duty_last = i;
		if (i_tmp >= curr_goal) {
			break;
		}
	}

    // 使用刚刚测量好的期望占空比来实际测量电感
    // 再重复一下，在电机加上该占空比的电压，可以使电机电流大致等于期望电流
	float ind = mcpwm_foc_measure_inductance(duty_last, samples, curr);

	m_conf->foc_f_sw = f_sw_old;
	top = SYSTEM_CORE_CLOCK / (int)m_conf->foc_f_sw;
	TIMER_UPDATE_SAMP_TOP(MCPWM_FOC_CURRENT_SAMP_OFFSET, top);

	return ind;
}
```

可以看到，电感值是在mcpwm_foc_measure_inductance中计算的，继续跳入

```c
float mcpwm_foc_measure_inductance(float duty, int samples, float *curr) {
	m_samples.avg_current_tot = 0.0;
	m_samples.avg_voltage_tot = 0.0;
	m_samples.sample_num = 0;
	m_samples.measure_inductance_duty = duty;

	// Disable timeout
	systime_t tout = timeout_get_timeout_msec();
	float tout_c = timeout_get_brake_current();
	timeout_reset();
	timeout_configure(60000, 0.0);

	mc_interface_lock();

	CURRENT_FILTER_OFF();

	int to_cnt = 0;
	for (int i = 0;i < samples;i++) {
		m_samples.measure_inductance_now = true;   // 这里只是设置了一下标志位，采样的地方不在这里

		do {
			chThdSleepMicroseconds(100);  // 100us
			to_cnt++;
			if (to_cnt > 50000) { // 100us * 50000 = 5s
				break;
			}
		} while (m_samples.measure_inductance_now);  // 总采样时间如果超过5s，跳出

		if (to_cnt > 50000) {  
			break;
		}
	}

	CURRENT_FILTER_ON();

	// Enable timeout
	timeout_configure(tout, tout_c);

	mc_interface_unlock();

	float avg_current = m_samples.avg_current_tot / (float)m_samples.sample_num;
	float avg_voltage = m_samples.avg_voltage_tot / (float)m_samples.sample_num;
	float t = (float)TIM1->ARR * m_samples.measure_inductance_duty / (float)SYSTEM_CORE_CLOCK -
			(float)(MCPWM_FOC_INDUCTANCE_SAMPLE_CNT_OFFSET + MCPWM_FOC_INDUCTANCE_SAMPLE_RISE_COMP) / (float)SYSTEM_CORE_CLOCK;
	// ARR / CLOCK = T(周期，频率的倒数)
    // 这里他减去了两个补偿时间，分别是MCPWM_FOC_INDUCTANCE_SAMPLE_CNT_OFFSET = 10
    // MCPWM_FOC_INDUCTANCE_SAMPLE_RISE_COMP = 50
    // 具体这两个时间是指什么下面再仔细讲

	if (curr) {
		*curr = avg_current;
	}

	return ((avg_voltage * t) / avg_current) * 1e6 * (2.0 /  3.0);
}
```

找到真实采样的地方，就是ADC的采样中断那里(mcpwm_foc_adc_int_handler)：

整个函数太长了，截取重要的部分：

```c
	if (!m_samples.measure_inductance_now) {  // 在非电感采样模式下
#ifdef HW_HAS_PHASE_SHUNTS
		if (!m_conf->foc_sample_v0_v7 && is_v7) {
			return;
		}
#else
		if (is_v7) {   // 判断当前是上溢中断还是下溢中断，正常情况应该在上管关闭（下管导通）的时候采样
			return;   // 因此这里is_v7代表的情况是，上管导通,这里的v7的意思是指七步SVPWM中的第七状态
		}
#endif
	}
```

这一部分就在整个函数的入口处，主要就是判断一下当前是不是V7时间段，众所周知，一般情况下电流采样应该在V0时间段采样。而由于本杰明中配置定时器的中央对齐模式时，并没有配置重复计数器，因此每一个周期会有两次中断，分别是上溢中断和下溢中断。这个代码就是判断当前到底是处于哪个中断的，如果在非电感采样模式下，且处于V7（上溢中断），则直接返回。

```c
	if (m_samples.measure_inductance_now) {
		if (!is_v7) {   // is_v7 代表上管导通
			return;
		}

		static int inductance_state = 0;
		const uint32_t duty_cnt = (uint32_t)((float)TIM1->ARR * m_samples.measure_inductance_duty); 
		const uint32_t samp_time = duty_cnt - MCPWM_FOC_INDUCTANCE_SAMPLE_CNT_OFFSET; 
        // 注意这里更新了电流的采样点，将其往前挪了MCPWM_FOC_INDUCTANCE_SAMPLE_CNT_OFFSET个定时器的CLK

		if (inductance_state == 0) {
			TIMER_UPDATE_DUTY_SAMP(0, 0, 0, samp_time);
			start_pwm_hw();
		} else if (inductance_state == 2) {
			TIMER_UPDATE_DUTY(duty_cnt,	0, duty_cnt); // 打开AC上桥，B下桥，导通时间duty_cnt
		} else if (inductance_state == 3) {
			m_samples.avg_current_tot += -((float)curr1 * FAC_CURRENT); // 测量A的电流
			m_samples.avg_voltage_tot += GET_INPUT_VOLTAGE(); // 测量电源电压
			m_samples.sample_num++;
			TIMER_UPDATE_DUTY(0, 0, 0);
		} else if (inductance_state == 5) {
			TIMER_UPDATE_DUTY(0, duty_cnt, duty_cnt); // 打开BC上桥，A下桥,导通时间duty_cnt
		} else if (inductance_state == 6) {
			m_samples.avg_current_tot += -((float)curr0 * FAC_CURRENT); // 测量C电流
			m_samples.avg_voltage_tot += GET_INPUT_VOLTAGE();
			m_samples.sample_num++;
			TIMER_UPDATE_DUTY(0, 0, 0);
		} else if (inductance_state == 8) {
#ifdef HW_HAS_3_SHUNTS
			TIMER_UPDATE_DUTY(duty_cnt, duty_cnt, 0);
#else
			TIMER_UPDATE_DUTY(0, 0, duty_cnt);  // 打开C上桥，AB下桥
#endif
		} else if (inductance_state == 9) {
#ifdef HW_HAS_3_SHUNTS
			m_samples.avg_current_tot += -((float)curr2 * FAC_CURRENT);
#else
			m_samples.avg_current_tot += -((float)curr0 * FAC_CURRENT + (float)curr1 * FAC_CURRENT);  // 测量B电流
#endif
			m_samples.avg_voltage_tot += GET_INPUT_VOLTAGE();
			m_samples.sample_num++;
			stop_pwm_hw();
			TIMER_UPDATE_SAMP(MCPWM_FOC_CURRENT_SAMP_OFFSET);
		} else if (inductance_state == 10) {
			inductance_state = 0;
			m_samples.measure_inductance_now = false;  // 一次循环结束，采样了三次
			return;
		}

		inductance_state++;
		return;
	}
```

现在可以知道，VESC中测量电感的方式了：

利用公式：U=L*(di/dt) ，利用短脉冲电压，测量该电压下，电感的电流。需要注意的是，实际上电机线圈还有电阻，因此完整的公式应该是：

U=L*(di/dt) + I*R，电阻一般是mR级，再加上电流较小，因此本杰明直接忽略掉电阻的影响可能误差也不是很大。

再来讨论一下上面说的减去的补偿时间：
MCPWM_FOC_INDUCTANCE_SAMPLE_CNT_OFFSET(10) 和  MCPWM_FOC_INDUCTANCE_SAMPLE_RISE_COMP(50)

前者在设置电流采样点的时候和计算最终dt的时候都用到了，设置采样点的时候将其往前挪，我自己的推测是：

本杰明的电流采样通道优先级低于反电动势的采样通道，因此在采样电流前，需要先采样反电动势，这样会导致等电流开始采样的时候，已经过了一段时间，导致电流已经开始变小，从而影响电流的精度。
但这个推测的问题在于，如果要补偿的话，也应该补偿：(15+12)个ADCCLK，15是设置的ADC采样周期个数，12是ADC转换的周期个数，再加上本杰明设置的ADCCLK为42MHZ，而定时器频率为168MHZ,因此显然应该补偿(15+12)*4左右才对。

另一个补偿时间是MCPWM_FOC_INDUCTANCE_SAMPLE_RISE_COMP,因为其中带了个Rise，我猜测这是为了补偿MOS的打开延迟，包括STM32引脚拉高到DRV8302输出高，到MOS实际导通之间的延迟。这个时间可能是本杰明测出来的。