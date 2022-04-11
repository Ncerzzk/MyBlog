# 从头写一个linux飞控 
ctime:2022-04-10 21:24:25 +0800|1649597065

标签（空格分隔）：技术  飞控

---

学习PX4有一段时间了，打算（开始挖坑）用rust写一个在linux上运行的飞控，作为PX4学习的一个总结，顺便练习rust，在这里来记录一下一些想法和进度。

### 需要具备的基本组件
- param
- logger
- 进程间通信（采用uorb）
- 基本的设备驱动
  - IMU
  - CRSF
  - PWM
- EKF（使用ardupilot 或者 PX4的EKF模块，编译成.a?)
- 调度器
  - FIFO调度
- mavlink

### 基本目标
- 在空心杯四旋翼上能起飞
- 具备一定的拓展能力(mavlink)
- 仿真？
- 上位机通信

I seem to find how the ring apear.

Here is a way to produce the ring.

Assume that PX4 is running `ScheduledWorkItem`  named **ITEM_A**. And the `ITEM_A` would call `ScheduleDelayed` or other schedule funcs in its `RUN` implement.
These schedule funcs would call `hrt_call_internal(struct hrt_call *entry, hrt_abstime deadline, hrt_abstime interval, hrt_callout callout, void *arg)` indeed.
the argument `callout` is `void ScheduledWorkItem::schedule_trampoline(void *arg)` which aims to add the workitem into the process list of workqueue.

And in hrt_call_invoke():
```cpp
static void
hrt_call_invoke()
{
	struct hrt_call	*call;
	hrt_abstime deadline;

	hrt_lock();

	while (true) {
                  ...
		/* zero the deadline, as the call has occurred */
		call->deadline = 0;

		/* invoke the callout (if there is one) */
		if (call->callout) {
			// Unlock so we don't deadlock in callback
			hrt_unlock();
			//PX4_INFO("call %p: %p(%p)", call, call->callout, call->arg);
			call->callout(call->arg);
			hrt_lock();
		}

		/* if the callout has a non-zero period, it has to be re-entered */
		if (call->period != 0) {
			// re-check call->deadline to allow for
			// callouts to re-schedule themselves
			// using hrt_call_delay()
			if (call->deadline <= now) {
				call->deadline = deadline + call->period;
				//PX4_INFO("call deadline set to %lu now=%lu", call->deadline,  now);
			}

			hrt_call_enter(call);
		}
	}
	hrt_unlock();
}
```
**please pay attention to the action**:`call->deadline=0` we have set deadline to 0, before we call `schedule_trampoline`.

In the start part of `hrt_call_internal`,  there is a remove action:

```cpp
	if (entry->deadline != 0) {
		sq_rem(&entry->link, &callout_queue);
	}
```
While because we have set the deadline to 0 before, the remove action doesn't work. So until now, the CALL_A is still in the **callout_queue**.

Then `hrt_call_internal` would call `hrt_call_enter`:
```cpp
static void
hrt_call_enter(struct hrt_call *entry)
{
	struct hrt_call	*call, *next;

	call = (struct hrt_call *)sq_peek(&callout_queue);

	if ((call == nullptr) || (entry->deadline < call->deadline)) {
		sq_addfirst(&entry->link, &callout_queue);
		//if (call != nullptr) PX4_INFO("call enter at head, reschedule (%lu %lu)", entry->deadline, call->deadline);
		/* we changed the next deadline, reschedule the timer event */
		hrt_call_reschedule();

	} else {
		do {
			next = (struct hrt_call *)sq_next(&call->link);

			if ((next == nullptr) || (entry->deadline < next->deadline)) {
				//lldbg("call enter after head\n");
				sq_addafter(&call->link, &entry->link, &callout_queue);
				break;
			}
		} while ((call = next) != nullptr);
	}
}
```
So **if there are no other calls in the callout_queue or CALL_A is the head of callout_queue**, the ring would apear:
`CALL_A.flink==&CALL_A`.




---

I seem to find how the ring apear. please read the comment below. 

In `hrt_call_invoke` (I have removed all the old comment)
```cpp
static void
hrt_call_invoke()
{
    ...
	hrt_lock();

	while (true) {
		hrt_abstime now = hrt_absolute_time();

		call = (struct hrt_call *)sq_peek(&callout_queue);

		if (call == nullptr) {
			break;
		}

		if (call->deadline > now) {
			break;
		}

		sq_rem(&call->link, &callout_queue);

		deadline = call->deadline;

		call->deadline = 0;

		if (call->callout) {
			hrt_unlock();  
// here, we unlock hrt, and call the callout function, 
// and the callout func may be void ScheduledWorkItem::schedule_trampoline(void *arg), which would call dev->ScheduleNow
// the dev->ScheduleNow would Add the workitem into workqueue process list
// while in the Add func, it would request the work_lock, 
// if we cannot get the work_lock now(because the workitem may be still processing), the hrt_thread would release the cpu
// and then the workitem finished, it may call SchedOnIntervals(or some other sched func) at the end, which would call hrt_call_enter finnally to add its hrt_call to the callout_queue.
// And now, as workitem finished, it would release the work_lock, so we can walk pass here, and then we will add the repeated hrt_call in the hrt_call_enter(call) below.
			call->callout(call->arg);
			hrt_lock();
		}

		if (call->period != 0) {
			if (call->deadline <= now) {
				call->deadline = deadline + call->period;
			}

			hrt_call_enter(call);
		}
	}

	hrt_unlock();
}
```



---

I seem to find how the ring apear. please read the comment below. 

In `hrt_call_invoke` (I have removed all the old comment)
```cpp
static void
hrt_call_invoke()
{
    ...
	hrt_lock();

	while (true) {
		hrt_abstime now = hrt_absolute_time();

		call = (struct hrt_call *)sq_peek(&callout_queue);

		if (call == nullptr) {
			break;
		}

		if (call->deadline > now) {
			break;
		}

		sq_rem(&call->link, &callout_queue);

		deadline = call->deadline;

		call->deadline = 0;

		if (call->callout) {
			hrt_unlock();  
// here, we unlock hrt, and call the callout function, 
// and the callout func may be void ScheduledWorkItem::schedule_trampoline(void *arg), which would call dev->ScheduleNow
// the dev->ScheduleNow would Add the workitem into workqueue process list
// while in the Add func, it would request the work_lock, 
// if we cannot get the work_lock now(because the workitem may be still processing), the hrt_thread would release the cpu
// and then the workitem finished, it may call SchedOnIntervals(or some other sched func) at the end, which would call hrt_call_enter finnally to add its hrt_call to the callout_queue.
// And now, as workitem finished, it would release the work_lock, so we can walk pass here, and then we will add the repeated hrt_call in the hrt_call_enter(call) below.
			call->callout(call->arg);
			hrt_lock();
		}

		if (call->period != 0) {
			if (call->deadline <= now) {
				call->deadline = deadline + call->period;
			}

			hrt_call_enter(call);
		}
	}

	hrt_unlock();
}
```

Is this explain make sense? @dagar 