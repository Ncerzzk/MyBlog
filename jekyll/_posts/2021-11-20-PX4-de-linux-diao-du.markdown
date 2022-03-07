---
layout: post
title: PX4的linux调度
date: 2021-11-20 17:01:42 +0800
categories:  飞控
issue_id: 151
---

作为顶顶大名的飞控，PX4实际上支持在linux下直接运行的，因此可以不必再外接pixhawk。

那么linux作为一个非实时的操作系统，PX4具体是如何在上面运行的呢？这篇文章就是为了探究这个问题。

首先在main.cpp中找到初始化函数：

```cpp
void init_once()
{
	_shell_task_id = pthread_self();

	work_queues_init();
	hrt_work_queue_init();

	px4_platform_init();
}
```

除了第一句以外，其他的看起来都跟调度可能有关，挨个去看看。

## Work Queues Init

```cpp
void work_queues_init(void)
{
	px4_sem_init(&_work_lock[HPWORK], 0, 1);
	px4_sem_init(&_work_lock[LPWORK], 0, 1);
#ifdef CONFIG_SCHED_USRWORK
	px4_sem_init(&_work_lock[USRWORK], 0, 1);
#endif

	// Create high priority worker thread
	g_work[HPWORK].pid = px4_task_spawn_cmd("hpwork",
						SCHED_DEFAULT,
						SCHED_PRIORITY_MAX - 1,
						2000,
						work_hpthread,
						(char *const *)NULL);

	// Create low priority worker thread
	g_work[LPWORK].pid = px4_task_spawn_cmd("lpwork",
						SCHED_DEFAULT,
						SCHED_PRIORITY_MIN,
						2000,
						work_lpthread,
						(char *const *)NULL);

}
```

其中，`px4_task_spawn_cmd`是用来新建一个可调度的task，SCHED_DEFAULT是一个宏定义，定义为：SCHED_FIFO，对linux比较熟悉的应该知道，这是一种实时调度策略，
高优先级线程可以抢占低优先级线程，并且如果高优先级线程不主动释放CPU，低优先级线程是无法执行的。
`px4_task_spawn_cmd`函数声明为:
```cpp
px4_task_t px4_task_spawn_cmd(const char *name, int scheduler, int priority, int stack_size, px4_main_t entry,
			      char *const argv[])
```
内部实现是调用操作系统的pthread。

好了，通过这里可以发现，这里新建了两个work queue，分别是高优先级的队列和低优先级的队列。

接下来进去看看这两个队列管理线程里干了些啥事

```cpp
int work_hpthread(int argc, char *argv[])
{
	/* Loop forever */

	for (;;) {
		/* First, perform garbage collection.  This cleans-up memory de-allocations
		 * that were queued because they could not be freed in that execution
		 * context (for example, if the memory was freed from an interrupt handler).
		 * NOTE: If the work thread is disabled, this clean-up is performed by
		 * the IDLE thread (at a very, very low priority).
		 */

#ifndef CONFIG_SCHED_LPWORK
		sched_garbagecollection();
#endif

		/* Then process queued work.  We need to keep interrupts disabled while
		 * we process items in the work list.
		 */

		work_process(&g_work[HPWORK], HPWORK);
	}

	return PX4_OK; /* To keep some compilers happy */
}
```

注释里写得很清楚，首先是垃圾回收（一些上下文下无法及时释放的内存会在这里释放，但是sched_garbagecollection似乎没实际使用，因为CONFIG_SCHED_LPWORK这个宏是有定义的，而且在work_lpthread中，将sched_garbagecollection注释了，且我也没找到这个函数的定义或者声明，这里先不管他），然后开始实际的work_progress,再进去看看：（出于方便，我会直接将标注用中文注释的方式写在下方代码中）
```cpp
static void work_process(struct wqueue_s *wqueue, int lock_id)
{
	volatile struct work_s *work;
	worker_t  worker;
	void *arg;
	uint64_t elapsed;
	uint32_t remaining;
	uint32_t next;

	/* Then process queued work.  We need to keep interrupts disabled while
	 * we process items in the work list.
	 */

	next  = CONFIG_SCHED_WORKPERIOD;

	work_lock(lock_id);

	work  = (struct work_s *)wqueue->q.head;

	while (work) {
		/* Is this work ready?  It is ready if there is no delay or if
		 * the delay has elapsed. qtime is the time that the work was added
		 * to the work queue.  It will always be greater than or equal to
		 * zero.  Therefore a delay of zero will always execute immediately.
		 */

		elapsed = USEC2TICK(clock_systimer() - work->qtime);
        // 检测该work上次执行到现在所过的时间

		//printf("work_process: in ticks elapsed=%lu delay=%u\n", elapsed, work->delay);
		if (elapsed >= work->delay) {
			/* Remove the ready-to-execute work from the list */

			(void)dq_rem((struct dq_entry_s *)work, &wqueue->q);

			/* Extract the work description from the entry (in case the work
			 * instance by the re-used after it has been de-queued).
			 */

			worker = work->worker;
			arg    = work->arg;

			/* Mark the work as no longer being queued */
            // 取出worker 和 参数，并将标记为NULL(表示已经执行过）
			work->worker = NULL;

			/* Do the work.  Re-enable interrupts while the work is being
			 * performed... we don't have any idea how long that will take!
			 */

             // 这里他说重新使能中断了，但实际上之类只是设置了一下信号量，因此可以推测中断也用了这个信号量来进行同步
			work_unlock(lock_id);

			if (!worker) {
				PX4_WARN("MESSED UP: worker = 0\n");

			} else {
				worker(arg);
                // 实际运行这个work
			}

			/* Now, unfortunately, since we re-enabled interrupts we don't
			 * know the state of the work list and we will have to start
			 * back at the head of the list.
			 */
            // 如上所言，由于实际执行了一项work，此时应该从头开始遍历一下这个工作队列，（可能在队列头部有一些work已经就绪了，这时候应该去执行队列头部的work）

			work_lock(lock_id);
			work  = (struct work_s *)wqueue->q.head;

		} else {

            // 整个else逻辑就是：
            // 这个work还未就绪，那么计算一下它离就绪还有多久，如果比next还少，那么就将next赋值为这个下次就绪时间
            // 遍历一遍后，next就是最快将要就绪的work的等待时间，然后再usleep 这个时间即可。

			/* This one is not ready.. will it be ready before the next
			 * scheduled wakeup interval?
			 */

			/* Here: elapsed < work->delay */
			remaining = USEC_PER_TICK * (work->delay - elapsed);

			if (remaining < next) {
				/* Yes.. Then schedule to wake up when the work is ready */

				next = remaining;
			}

			/* Then try the next in the list. */

			work = (struct work_s *)work->dq.flink;
		}
	}

	/* Wait awhile to check the work list.  We will wait here until either
	 * the time elapses or until we are awakened by a signal.
	 */
	work_unlock(lock_id);

	px4_usleep(next);
}
```

到这里，调度的逻辑已经比较清晰了，即通过两个work_queue，这两个work_queue自身通过linux得SCHED_FIFO来调度，在它们内部，会自己进行调度。
刚刚分析的主要是`work_hpthread`,但实际上`work_lpthread`、`work_hrtthread`的流程也几乎是一样的，这里就不再分析了。


总结一下这一部分，基本就是三种work queue的初始化，分别是hpthread（高优先级） lphread（低优先级）和hrtthread(依赖高分辨率定时器的workqueue)

## Platform Init
接下来是平台级的一些初始化，
```cpp
int px4_platform_init(void)
{
	hrt_init();

	param_init();

	px4::WorkQueueManagerStart();

	uorb_start();

	px4_log_initialize();

	return PX4_OK;
}
```

我们主要关注一下WorkQueueManagerStart，该函数

```cpp
static int
WorkQueueManagerRun(int, char **)
{
	_wq_manager_wqs_list = new BlockingList<WorkQueue *>();
	_wq_manager_create_queue = new BlockingQueue<const wq_config_t *, 1>();

	while (!_wq_manager_should_exit.load()) {
		// create new work queues as needed
		const wq_config_t *wq = _wq_manager_create_queue->pop();

		if (wq != nullptr) {
			// create new work queue
            // 如果有work queue 待创建，那么下面据开始创建流程。
            // 一开始_wq_manager_create_queue是空的，只有当运行到其他模块时，才会往这里添加元素

			pthread_attr_t attr;
			int ret_attr_init = pthread_attr_init(&attr);

            // .. 省略 attr 和 优先级的设置

			// create thread
			pthread_t thread;
			int ret_create = pthread_create(&thread, &attr, WorkQueueRunner, (void *)wq);

            // ...
			// destroy thread attributes
			int ret_destroy = pthread_attr_destroy(&attr);

			if (ret_destroy != 0) {
				PX4_ERR("failed to destroy thread attributes for %s (%i)", wq->name, ret_create);
			}
		}
	}

	return 0;
}
```

那么什么时候会往`_wq_manager_create_queue`添加元素呢？首先是`WorkQueueFindOrCreate`，该函数会往`_wq_manager_create_queue` push 一个新元素。

```cpp
WorkQueue *
WorkQueueFindOrCreate(const wq_config_t &new_wq)
{
	if (_wq_manager_create_queue == nullptr) {
		PX4_ERR("not running");
		return nullptr;
	}

	// search list for existing work queue
	WorkQueue *wq = FindWorkQueueByName(new_wq.name);

	// create work queue if it doesn't already exist
	if (wq == nullptr) {
		// add WQ config to list
		//  main thread wakes up, creates the thread
		_wq_manager_create_queue->push(&new_wq);

		// we wait until new wq is created, then return
		uint64_t t = 0;

		while (wq == nullptr && t < 10_s) {
			// Wait up to 10 seconds, checking every 1 ms
			t += 1_ms;
			px4_usleep(1_ms);

			wq = FindWorkQueueByName(new_wq.name);
		}

		if (wq == nullptr) {
			PX4_ERR("failed to create %s", new_wq.name);
		}
	}

	return wq;
}
```

而`WorkQueueFindOrCreate` 又在`WorkItem::Init`中被调用

```cpp
bool WorkItem::Init(const wq_config_t &config)
{
	// clear any existing first
	Deinit();

	px4::WorkQueue *wq = WorkQueueFindOrCreate(config);

	if ((wq != nullptr) && wq->Attach(this)) {
		_wq = wq;
		_time_first_run = 0;
		return true;
	}

	PX4_ERR("%s not available", config.name);
	return false;
}
```

什么是`WorkItem`？随手举个例子，如固定翼的控制模块：

```cpp
FixedwingPositionControl::FixedwingPositionControl(bool vtol) :
	ModuleParams(nullptr),
	WorkItem(MODULE_NAME, px4::wq_configurations::nav_and_controllers),
	_attitude_sp_pub(vtol ? ORB_ID(fw_virtual_attitude_setpoint) : ORB_ID(vehicle_attitude_setpoint)),
	_loop_perf(perf_alloc(PC_ELAPSED, MODULE_NAME": cycle")),
	_launchDetector(this),
	_runway_takeoff(this)
```

也就是说，在PX4的一些组件模块初始化的时候，会创建一个WorkItem，然后将与该WorkItem关联的workqueue加到待初始化的work queue列表中，由WorkQueueManager来实际地创建线程。

不过，需要注意的是，这里创建的都是*线程*，也就是和一开始讨论的hpthread lpthread等线程都是同级的关系。有哪些操作是通过线程直接调度的，可以查看`wq_configurations`。可以看到，里面大部分都是一些接口，如I2C、SPI（另外高度、速度控制也作为一个work queue）。可以推测，每种接口都是一个work queue，如一个I2C总线下挂多个设备，那么每个设备的操作就是该work queue的一项work。每项work的调度就是最开始hpthread那样地调度了。


## 总结

总结一下，PX4在linux上（或者说在posix上），主要是通过线程调度+work queue内部调度来完成的。

依据所要完成的操作种类，会有多个work queue，每个workqueue都由一个线程管理，也即每个workque 自身是由linux通过线程来调度的。不同的workqueue有不同的优先级，该优先级也是与linux FIFO调度的优先级对应的。

一个workqueue下会有多个work，workqueue也是通过FIFO的方式来调度，但是与linux的SCHED_FIFO不同，这里的FIFO不会发生抢占（因为这里面的每项work已经没有优先级的区分了）。

那么，这种方式有缺点吗？我想应该是有的，每个线程（或者说workqueue）都要仔细考虑其优先级，如果高优先级的workqueue中有太多的work，那么显然它是不会将CPU释放给低优先级的workqueue的，因此如果处理器性能不够，高优先级的线程实时性能够得到保证，但是低优先级的线程实时性可能就无法保证了。（但是，低优先级线程的实时性重要吗？如果重要，怎么不设置为高优先级呢？）另外，其他rtos的实现不也是如此吗，如果有一个高优先级的线程在执行，其他低优先级的线程同样无法抢占（在抢占式调度下），因此这样说来，实际上这种方式并不比rtos在调度上逊色太多。当然，由于linux的内核比较重，因此与RTOS相比，还有内核调度上的一些开销。


此外，linux上要运行PX4，要打开内核抢占（实现软实时），打实时性补丁（实现硬实时）的，虽然PX4官方没提到，但是其提供的在树莓派上运行的一个OS，实际上是已经打过补丁的了。

## 函数声明、变量类型备查

```cpp
static BlockingQueue<const wq_config_t *, 1> *_wq_manager_create_queue{nullptr};
static BlockingList<WorkQueue *> *_wq_manager_wqs_list{nullptr};    //当前正在的执行的work queues，如果某个workqueue不再需要执行，会被移出这个队列
static void work_process(struct wqueue_s *wqueue, int lock_id);  // 实际的workqueue 处理函数
struct wqueue_s g_work[NWORKERS];
px4_sem_t _work_lock[NWORKERS];
struct wqueue_s g_hrt_work;
struct wq_config_t {
	const char *name;
	uint16_t stacksize;
	int8_t relative_priority; // relative to max
};
namespace wq_configurations
{
static constexpr wq_config_t rate_ctrl{"wq:rate_ctrl", 1952, 0}; // PX4 inner loop highest priority
static constexpr wq_config_t ctrl_alloc{"wq:ctrl_alloc", 9500, 0}; // PX4 control allocation, same priority as rate_ctrl

static constexpr wq_config_t SPI0{"wq:SPI0", 2336, -1};
static constexpr wq_config_t SPI1{"wq:SPI1", 2336, -2};
static constexpr wq_config_t SPI2{"wq:SPI2", 2336, -3};
static constexpr wq_config_t SPI3{"wq:SPI3", 2336, -4};
static constexpr wq_config_t SPI4{"wq:SPI4", 2336, -5};
static constexpr wq_config_t SPI5{"wq:SPI5", 2336, -6};
static constexpr wq_config_t SPI6{"wq:SPI6", 2336, -7};

static constexpr wq_config_t I2C0{"wq:I2C0", 2336, -8};
static constexpr wq_config_t I2C1{"wq:I2C1", 2336, -9};
static constexpr wq_config_t I2C2{"wq:I2C2", 2336, -10};
static constexpr wq_config_t I2C3{"wq:I2C3", 2336, -11};
static constexpr wq_config_t I2C4{"wq:I2C4", 2336, -12};

// PX4 att/pos controllers, highest priority after sensors.
static constexpr wq_config_t nav_and_controllers{"wq:nav_and_controllers", 2240, -13};

static constexpr wq_config_t INS0{"wq:INS0", 6000, -14};
static constexpr wq_config_t INS1{"wq:INS1", 6000, -15};
static constexpr wq_config_t INS2{"wq:INS2", 6000, -16};
static constexpr wq_config_t INS3{"wq:INS3", 6000, -17};

static constexpr wq_config_t hp_default{"wq:hp_default", 1900, -18};

static constexpr wq_config_t uavcan{"wq:uavcan", 3624, -19};

static constexpr wq_config_t UART0{"wq:UART0", 1632, -21};
static constexpr wq_config_t UART1{"wq:UART1", 1632, -22};
static constexpr wq_config_t UART2{"wq:UART2", 1632, -23};
static constexpr wq_config_t UART3{"wq:UART3", 1632, -24};
static constexpr wq_config_t UART4{"wq:UART4", 1632, -25};
static constexpr wq_config_t UART5{"wq:UART5", 1632, -26};
static constexpr wq_config_t UART6{"wq:UART6", 1632, -27};
static constexpr wq_config_t UART7{"wq:UART7", 1632, -28};
static constexpr wq_config_t UART8{"wq:UART8", 1632, -29};
static constexpr wq_config_t UART_UNKNOWN{"wq:UART_UNKNOWN", 1632, -30};

static constexpr wq_config_t lp_default{"wq:lp_default", 1920, -50};

static constexpr wq_config_t test1{"wq:test1", 2000, 0};
static constexpr wq_config_t test2{"wq:test2", 2000, 0};

} // namespace wq_configurations

int pthread_create(
                 pthread_t *restrict tidp,   //新创建的线程ID指向的内存单元。
                 const pthread_attr_t *restrict attr,  //线程属性，默认为NULL
                 void *(*start_rtn)(void *), //新创建的线程从start_rtn函数的地址开始运行
                 void *restrict arg //默认为NULL。若上述函数需要参数，将参数放入结构中并将地址作为arg传入。
                  );
```