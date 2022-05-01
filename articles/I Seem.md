I seem to find how the ring apear.
ctime:2022-04-14 19:57:51 +0800|1649937471

Here is a way to produce the ring.

Assume that PX4 is running `ScheduledWorkItem`  named **ITEM_A**.

 in hrt_call_invoke():
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
**please pay attention to the action**:`call->deadline=0`
and in the **CALL_A**, we do something sensor FIFO read action, then call `ScheduleOnInterval`, which would call `hrt_call_internal(entry, calltime, 0, callout, arg);`  instead. In the start part of `hrt_call_internal`,  there is a remove action:

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